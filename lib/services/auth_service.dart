import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'crypto_service.dart';
import 'notification_service.dart';

/// Servicio de autenticación con cifrado híbrido RSA-2048 + AES-256-CBC
/// Implementación basada en Stallings - Cryptography and Network Security
/// El cifrado añade una capa adicional de seguridad para credenciales

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Validador estricto de dominio UCEVA
  static final RegExp _ucevaEmailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@uceva\.edu\.co$',
  );

  // UU-42 B-09: clave AES-256 compartida leída desde --dart-define en tiempo
  // de compilación. NUNCA hardcodear este valor en el repositorio.
  //
  // CONTEXTO DE USO (leer antes de usar esta clave):
  // Esta es una clave COMPARTIDA entre todos los dispositivos y builds.
  // A diferencia del cifrado RSA+AES del studentCode (que usa claves por
  // dispositivo), esta clave es la misma para todos, lo que permite que
  // distintos usuarios puedan descifrar campos protegidos con ella
  // (ej: número de teléfono visible entre conductor y pasajero).
  //
  // COMPATIBILIDAD: El valor actual ('UniConnectPhone2024SecureKey3256') es
  // el mismo que estaba hardcodeado. NO cambiarlo si ya hay datos cifrados
  // con él en Firestore, o los registros existentes quedarán ilegibles.
  //
  // Para correr en debug:
  //   flutter run --dart-define=SHARED_PHONE_KEY=UniConnectPhone2024SecureKey3256
  // Para build release:
  //   flutter build apk --release --dart-define=SHARED_PHONE_KEY=UniConnectPhone2024SecureKey3256
  static const String _sharedPhoneKey = String.fromEnvironment(
    'SHARED_PHONE_KEY',
    defaultValue: '',
  );

  FirebaseAuth? _authOverride;
  FirebaseFirestore? _dbOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Servicio de cifrado híbrido RSA + AES-256
  /// ref: Stallings - Cap 10.2 Hybrid Cryptography
  CryptoService _cryptoService = CryptoService();

  /// Almacenamiento seguro para credenciales cifradas
  FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ignore: use_setters_to_change_properties
  /// Este método existe exclusivamente para inyección de dependencias en pruebas unitarias.
  /// Nunca debe ser invocado desde código de producción.
  void setDependencies({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    CryptoService? cryptoService,
    FlutterSecureStorage? secureStorage,
  }) {
    if (auth != null) _authOverride = auth;
    if (db != null) _dbOverride = db;
    if (cryptoService != null) _cryptoService = cryptoService;
    if (secureStorage != null) _secureStorage = secureStorage;
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String> _encryptFieldAsync(String plaintext) async {
    try {
      final encrypted = await _cryptoService.encryptData(plaintext);
      return jsonEncode(encrypted);
    } catch (e) {
      return plaintext;
    }
  }

  Future<String> _decryptFieldAsync(dynamic value) async {
    try {
      if (value == null) return '';
      final str = value.toString();
      if (!str.contains('encryptedData') && !str.contains('ciphertext'))
        return str;
      if (!str.startsWith('{')) return str;
      final map = jsonDecode(str) as Map<String, dynamic>;
      final result = await _cryptoService.decryptData({
        'encryptedData': map['encryptedData'] ?? map['ciphertext'] ?? '',
        'iv': map['iv'] ?? '',
        'encryptedKey': map['encryptedKey'] ?? '',
      });
      return result.isEmpty ? '' : result;
    } catch (e) {
      return '';
    }
  }

  String _hashPhone(String normalizedPhone) {
    final bytes = utf8.encode(normalizedPhone);
    return sha256.convert(bytes).toString();
  }

  String _hashStudentCode(String studentCode) {
    final bytes = utf8.encode(studentCode);
    return sha256.convert(bytes).toString();
  }

  Future<bool> _isPhoneTaken(
    String normalizedDigits, {
    String? excludeUid,
  }) async {
    final hashed = _hashPhone(normalizedDigits);
    final snap = await _db
        .collection('users')
        .where('hashedPhone', isEqualTo: hashed)
        .limit(1)
        .get();
    if (excludeUid != null) {
      return snap.docs.any((doc) => doc.id != excludeUid);
    }
    return snap.docs.isNotEmpty;
  }

  Future<bool> _isStudentCodeTaken(
    String studentCode, {
    String? excludeUid,
  }) async {
    final hashed = _hashStudentCode(studentCode);
    final snap = await _db
        .collection('users')
        .where('hashedStudentCode', isEqualTo: hashed)
        .limit(1)
        .get();
    if (excludeUid != null) {
      return snap.docs.any((doc) => doc.id != excludeUid);
    }
    return snap.docs.isNotEmpty;
  }

  /// Inicio de sesión con cifrado híbrido RSA-2048 + AES-256-CBC
  /// ref: Stallings cap 10.2 - Hybrid Cryptography
  ///
  /// Flujo de cifrado (patrón híbrido):
  /// 1. Generar clave AES-256 aleatoria por sesión
  /// 2. Cifrar contraseña con AES-256-CBC (cifrado simétrico rápido)
  /// 3. Cifrar clave AES con RSA-2048 pública (cifrado asimétrico)
  /// 4. Almacenar credenciales cifradas localmente de forma segura
  /// 5. Firebase Auth verifica la contraseña (necesita texto plano)
  ///
  /// El cifrado añade capa adicional de seguridad para datos sensibles
  Future<String> login(String email, String password) async {
    Stopwatch? stopwatchTotal;
    if (kDebugMode) {
      stopwatchTotal = Stopwatch()..start();
      debugPrint('[AuthService] INICIO login para email: $email');
    }

    try {
      // Intentar cifrar credenciales antes de cualquier operación
      // ref: Stallings - Data Encryption in Transit
      // Si el cifrado falla, hacemos fallback a Firebase Auth sin almacenamiento cifrado
      try {
        if (kDebugMode)
          debugPrint(
            '[AuthService] Iniciando cifrado de contraseña con CryptoService...',
          );
        final stopwatchCrypto = Stopwatch()..start();

        final encryptedPassword = await _cryptoService.encryptPassword(
          password,
        );

        if (kDebugMode) {
          stopwatchCrypto.stop();
          final cryptoTime = stopwatchCrypto.elapsedMilliseconds;
          debugPrint('[AuthService] Cifrado completado en $cryptoTime ms');

          final cipherPreview = encryptedPassword.ciphertext.length > 20
              ? '${encryptedPassword.ciphertext.substring(0, 20)}...'
              : encryptedPassword.ciphertext;
          debugPrint(
            '[AuthService] Payload generado — ciphertext: $cipherPreview, iv: ${encryptedPassword.iv}, keyLen: ${encryptedPassword.encryptedKey.length}',
          );
        }

        // Almacenar credenciales cifradas localmente si el cifrado fue exitoso
        await _secureStorage.write(
          key: 'encrypted_credentials_$email',
          value: encryptedPassword.toJson(),
        );
      } catch (e) {
        // Fallback si el cifrado falla: continuar con Firebase Auth
        if (kDebugMode)
          debugPrint(
            '[AuthService] Advertencia: Cifrado falló — usando fallback. Error: $e',
          );
      }

      if (kDebugMode)
        debugPrint('[AuthService] Enviando credenciales a Firebase Auth...');
      final stopwatchFirebase = Stopwatch()..start();

      // Firebase Auth requiere contraseña en texto plano para verificación
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        stopwatchFirebase.stop();
        final firebaseTime = stopwatchFirebase.elapsedMilliseconds;
        debugPrint('[AuthService] Firebase respondió en $firebaseTime ms');
      }

      // Verificar email (excepto admin)
      if (credential.user?.emailVerified == false &&
          email.trim().toLowerCase() != 'admin.00@uceva.edu.co') {
        await _auth.signOut();
        return 'email_not_verified:${email}';
      }

      final uid = credential.user?.uid;
      if (uid != null) {
        final userDoc = await _db.collection('users').doc(uid).get();
        final isSuspended = userDoc.data()?['suspended'] ?? false;
        if (isSuspended) {
          await _auth.signOut();
          if (kDebugMode)
            debugPrint('[AuthService] Resultado: Cuenta suspendida');
          return 'Tu cuenta ha sido suspendida. Contacta al administrador para más información.';
        }
      }

      // Guardar FCM token después del login exitoso
      try {
        await NotificationService().saveTokenForCurrentUser();
      } catch (_) {}

      // Actualizar lastActive al hacer login
      try {
        final uid = credential.user?.uid;
        if (uid != null) {
          await _db.collection('users').doc(uid).update({
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}

      if (kDebugMode && stopwatchTotal != null) {
        stopwatchTotal.stop();
        debugPrint(
          '[AuthService] Resultado: Inicio de sesión exitoso (total: ${stopwatchTotal.elapsedMilliseconds} ms)',
        );
      }
      return 'Inicio de sesión exitoso.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential') {
        if (kDebugMode)
          debugPrint('[AuthService] Resultado: Credenciales incorrectas');
        return 'Correo o contraseña incorrectos.';
      }
      if (e.code == 'invalid-email') {
        if (kDebugMode)
          debugPrint('[AuthService] Resultado: Correo electrónico inválido');
        return 'Correo electrónico inválido.';
      }
      if (e.code == 'user-disabled') {
        if (kDebugMode)
          debugPrint('[AuthService] Resultado: Cuenta deshabilitada');
        return 'Esta cuenta ha sido deshabilitada.';
      }
      if (kDebugMode)
        debugPrint('[AuthService] Resultado: Error Firebase — ${e.message}');
      return 'Error al iniciar sesión: ${e.message}';
    } catch (e) {
      if (kDebugMode)
        debugPrint(
          '[AuthService] Resultado: Error inesperado — ${e.toString()}',
        );
      return 'Error inesperado: ${e.toString()}';
    }
  }

  Future<String> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return 'Inicio de sesión cancelado.';

      if (!_ucevaEmailRegex.hasMatch(googleUser.email)) {
        await GoogleSignIn().signOut();
        return 'Solo se permiten emails @uceva.edu.co.';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final loginEmail = userCredential.user?.email?.toLowerCase() ?? '';
      if (!userCredential.user!.emailVerified &&
          loginEmail != 'admin.00@uceva.edu.co') {
        await _auth.signOut();
        await GoogleSignIn().signOut();
        return 'Debes verificar tu email antes de iniciar sesión.';
      }

      final uid = userCredential.user?.uid;
      if (uid != null) {
        final userDoc = await _db.collection('users').doc(uid).get();
        if (!userDoc.exists) {
          await _auth.signOut();
          await GoogleSignIn().signOut();
          return 'No se encontró una cuenta registrada con este email. Por favor regístrate primero.';
        }
        final isSuspended = userDoc.data()?['suspended'] ?? false;
        if (isSuspended) {
          await _auth.signOut();
          await GoogleSignIn().signOut();
          return 'Tu cuenta ha sido suspendida. Contacta al administrador para más información.';
        }
      }

      // Guardar FCM token después del login exitoso
      try {
        await NotificationService().saveTokenForCurrentUser();
      } catch (_) {}

      // Actualizar lastActive al hacer login con Google
      try {
        final uid = userCredential.user?.uid;
        if (uid != null) {
          await _db.collection('users').doc(uid).update({
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}

      return 'Inicio de sesión exitoso.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        return 'Ya existe una cuenta con este email usando otro método.';
      }
      return 'Error al iniciar sesión con Google: ${e.message}';
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  /// Registro con cifrado híbrido de contraseña
  /// ref: Stallings cap 10.3 - Key Management
  ///
  /// Flujo transaccional:
  /// 1. Validar email @uceva.edu.co
  /// 2. Normalizar teléfono → error si null
  /// 3. Verificar teléfono disponible
  /// 4. Verificar código estudiantil disponible
  /// 5. Cifrar contraseña (opcional, fallback si falla)
  /// 6. Crear cuenta Firebase Auth
  /// 7. Transacción Firestore atómica (users + studentCodes)
  /// 8. Enviar email de verificación
  /// 9. Reintentos automáticos en errores transitorios (hasta 3 veces)
  Future<String> register({
    required String fullName,
    required String studentCode,
    required String email,
    required String password,
    required String role,
    required String faculty,
    required String phone,
  }) async {
    Stopwatch? stopwatchTotal;
    if (kDebugMode) {
      stopwatchTotal = Stopwatch()..start();
      debugPrint('[AuthService] INICIO register para email: $email');
    }

    try {
      // Paso 1: Validar email @uceva.edu.co
      if (!_ucevaEmailRegex.hasMatch(email)) {
        if (kDebugMode)
          debugPrint('[AuthService] Resultado: Email no válido (dominio)');
        return 'Solo se permiten correos @uceva.edu.co.';
      }

      // Paso 2: Normalizar teléfono
      final normalizedPhone = _normalizePhone(phone);
      if (normalizedPhone == null) {
        if (kDebugMode)
          debugPrint('[AuthService] Resultado: Teléfono inválido');
        return 'Ingresa un número válido de 10 dígitos (ej: 3001234567)';
      }

      // Paso 3: Verificar teléfono disponible
      if (kDebugMode)
        debugPrint('[AuthService] Verificando disponibilidad del teléfono...');
      final stopwatchPhoneCheck = Stopwatch()..start();
      final phoneTaken = await _isPhoneTaken(normalizedPhone);
      if (kDebugMode) {
        stopwatchPhoneCheck.stop();
        debugPrint(
          '[AuthService] Verificación teléfono completada en ${stopwatchPhoneCheck.elapsedMilliseconds} ms',
        );
      }
      if (phoneTaken) {
        if (kDebugMode)
          debugPrint('[AuthService] Resultado: Teléfono ya registrado');
        return 'Este número ya está registrado en otra cuenta.';
      }

      // Paso 4: Verificar código estudiantil disponible
      if (kDebugMode)
        debugPrint(
          '[AuthService] Verificando disponibilidad del código estudiantil...',
        );
      final stopwatchCodeCheck = Stopwatch()..start();
      final codeTaken = await _isStudentCodeTaken(studentCode);
      if (kDebugMode) {
        stopwatchCodeCheck.stop();
        debugPrint(
          '[AuthService] Verificación código completada en ${stopwatchCodeCheck.elapsedMilliseconds} ms',
        );
      }
      if (codeTaken) {
        if (kDebugMode)
          debugPrint(
            '[AuthService] Resultado: Código estudiantil ya registrado',
          );
        return 'Este código estudiantil ya está registrado.';
      }

      // Paso 5: Cifrar contraseña (opcional)
      try {
        if (kDebugMode)
          debugPrint(
            '[AuthService] Iniciando cifrado de contraseña con CryptoService...',
          );
        final stopwatchCrypto = Stopwatch()..start();

        final encryptedPassword = await _cryptoService.encryptPassword(
          password,
        );

        if (kDebugMode) {
          stopwatchCrypto.stop();
          final cryptoTime = stopwatchCrypto.elapsedMilliseconds;
          debugPrint('[AuthService] Cifrado completado en $cryptoTime ms');

          final cipherPreview = encryptedPassword.ciphertext.length > 20
              ? '${encryptedPassword.ciphertext.substring(0, 20)}...'
              : encryptedPassword.ciphertext;
          debugPrint(
            '[AuthService] Payload generado — ciphertext: $cipherPreview, iv: ${encryptedPassword.iv}, keyLen: ${encryptedPassword.encryptedKey.length}',
          );
        }

        await _secureStorage.write(
          key: 'encrypted_credentials_$email',
          value: encryptedPassword.toJson(),
        );
      } catch (e) {
        if (kDebugMode)
          debugPrint(
            '[AuthService] Advertencia: Cifrado falló — usando fallback. Error: $e',
          );
      }

      // Preparar valores para la transacción (fuera del loop para evitar múltiples cifrados)
      final encryptedStudentCode = await _encryptFieldAsync(studentCode);

      // Paso 6-7: Crear cuenta y transacción con reintentos
      User? createdUser;
      int attempt = 0;
      const maxAttempts = 3;

      while (attempt < maxAttempts) {
        attempt++;
        if (kDebugMode)
          debugPrint('[AuthService] Intento $attempt de $maxAttempts');

        try {
          // Crear cuenta Firebase Auth (solo en primer intento)
          if (createdUser == null) {
            if (kDebugMode)
              debugPrint('[AuthService] Creando cuenta Firebase Auth...');
            final stopwatchFirebase = Stopwatch()..start();

            final credential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );

            // Forzar refresh del token
            await credential.user!.getIdToken(true);
            createdUser = credential.user!;

            if (kDebugMode) {
              stopwatchFirebase.stop();
              debugPrint(
                '[AuthService] Cuenta Firebase Auth creada en ${stopwatchFirebase.elapsedMilliseconds} ms',
              );
            }
          }

          // Transacción Firestore atómica
          if (kDebugMode)
            debugPrint('[AuthService] Ejecutando transacción Firestore...');
          final stopwatchTransaction = Stopwatch()..start();

          await _db.runTransaction((transaction) async {
            final userRef = _db.collection('users').doc(createdUser!.uid);
            final studentRef = _db.collection('studentCodes').doc(studentCode);

transaction.set(userRef, {
               'fullName': fullName,
               'studentCode': encryptedStudentCode,
               'hashedStudentCode': _hashStudentCode(studentCode),
               'email': email,
               'role': role,
               'faculty': faculty,
               'phone': normalizedPhone,
               'hashedPhone': _hashPhone(normalizedPhone),
               'profileImageUrl': null,
               'description': '',
               'rating': 0.0,
               'tripsCompleted': 0,
               'bazarPurchases': 0,
               'createdAt': FieldValue.serverTimestamp(),
               'suspended': false,
             });

            transaction.set(studentRef, {'uid': createdUser!.uid});
          });

          if (kDebugMode) {
            stopwatchTransaction.stop();
            debugPrint(
              '[AuthService] Transacción Firestore completada en ${stopwatchTransaction.elapsedMilliseconds} ms',
            );
          }

          // Éxito: enviar email de verificación y salir del loop
          if (kDebugMode)
            debugPrint('[AuthService] Enviando email de verificación...');
          await createdUser!.sendEmailVerification();

          if (kDebugMode && stopwatchTotal != null) {
            stopwatchTotal.stop();
            debugPrint(
              '[AuthService] Resultado: Registro exitoso (total: ${stopwatchTotal.elapsedMilliseconds} ms)',
            );
          }
          return 'verification_email_sent';
        } on FirebaseAuthException catch (e) {
          // Errores de negocio: no reintentar
          if (e.code == 'email-already-in-use') {
            if (kDebugMode)
              debugPrint('[AuthService] Resultado: Email ya registrado');
            return 'Este correo ya está registrado.';
          }
          if (e.code == 'weak-password') {
            if (kDebugMode)
              debugPrint('[AuthService] Resultado: Contraseña débil');
            return 'La contraseña es demasiado débil.';
          }
          if (e.code == 'invalid-email') {
            if (kDebugMode)
              debugPrint('[AuthService] Resultado: Email inválido');
            return 'El correo no es válido.';
          }
          // Otros errores Auth: re-throw para manejo genérico
          rethrow;
        } catch (e) {
          // Determinar si es error transitorio (reintentar) o permanente (fallar)
          final isTransient =
              (e is FirebaseException &&
                  (e.code == 'unavailable' ||
                      e.code == 'deadline-exceeded' ||
                      e.code == 'internal' ||
                      e.code == 'cancelled')) ||
              (e is! FirebaseAuthException &&
                  (e.toString().toLowerCase().contains('network') ||
                      e.toString().toLowerCase().contains('timeout')));

          if (isTransient && attempt < maxAttempts) {
            // Error transitorio: esperar con backoff exponencial
            final delayMs = 500 * attempt; // 500ms, 1000ms, 2000ms
            if (kDebugMode)
              debugPrint(
                '[AuthService] Error transitorio (intento $attempt): $e. Reintentando en ${delayMs}ms...',
              );
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }

          // Error permanente o máximo reintentos alcanzado
          if (kDebugMode)
            debugPrint(
              '[AuthService] Error permanente o máximo reintentos alcanzado (intento $attempt): $e',
            );

          // Rollback: eliminar cuenta huérfana si existe
          if (createdUser != null) {
            try {
              if (kDebugMode)
                debugPrint('[AuthService] Eliminando cuenta huérfana...');
              await createdUser.delete();
            } catch (deleteError) {
              if (kDebugMode)
                debugPrint(
                  '[AuthService] Error al eliminar cuenta huérfana: $deleteError',
                );
            }
          }

          if (kDebugMode)
            debugPrint('[AuthService] Resultado: Error al completar registro');
          return 'Error al completar el registro. Por favor intenta de nuevo.';
        }
      }

      // Si llega aquí, algo salió mal
      if (kDebugMode)
        debugPrint(
          '[AuthService] Resultado: Error inesperado en loop de reintentos',
        );
      return 'Error inesperado durante el registro.';
    } catch (e) {
      if (kDebugMode)
        debugPrint(
          '[AuthService] Resultado: Error inesperado — ${e.toString()}',
        );
      return 'Error inesperado: ${e.toString()}';
    }
  }

  Future<String> registerWithGoogle({
    required String studentCode,
    required String role,
    required String faculty,
    required String phone,
  }) async {
    try {
      if (_auth.currentUser != null) await _auth.signOut();
      try {
        await GoogleSignIn().disconnect();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return 'Registro cancelado por el usuario.';

      if (!_ucevaEmailRegex.hasMatch(googleUser.email)) {
        await GoogleSignIn().signOut();
        return 'Solo se permiten emails @uceva.edu.co.';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final existingUserDoc = await _db
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      if (existingUserDoc.exists) {
        final existingCode = existingUserDoc.data()?['studentCode'];
        if (existingCode != studentCode) {
          await _auth.signOut();
          await GoogleSignIn().signOut();
          return 'Este email ya está registrado con un código diferente.';
        }
        return 'Ya tienes una cuenta registrada con este email y código.';
      }

      final studentCodeDoc = await _db
          .collection('studentCodes')
          .doc(studentCode)
          .get();
      if (studentCodeDoc.exists) {
        await _auth.signOut();
        await GoogleSignIn().signOut();
        return 'Este código estudiantil ya está registrado.';
      }

      final normalizedPhone = _normalizePhone(phone);
      if (normalizedPhone == null) {
        await _auth.signOut();
        await GoogleSignIn().signOut();
        return 'Ingresa un número válido de 10 dígitos (ej: 3001234567)';
      }

      // Verificar que el teléfono no esté en uso
      if (await _isPhoneTaken(normalizedPhone)) {
        await _auth.signOut();
        await GoogleSignIn().signOut();
        return 'Este número ya está registrado en otra cuenta.';
      }

      // Verificar que el código estudiantil no esté en uso
      if (await _isStudentCodeTaken(studentCode)) {
        await _auth.signOut();
        await GoogleSignIn().signOut();
        return 'Este código estudiantil ya está registrado.';
      }

await _db.collection('users').doc(userCredential.user!.uid).set({
         'fullName': googleUser.displayName ?? '',
         'studentCode': await _encryptFieldAsync(studentCode),
         'hashedStudentCode': _hashStudentCode(studentCode),
         'email': googleUser.email,
         'role': role,
         'faculty': faculty,
         'phone': normalizedPhone,
         'hashedPhone': _hashPhone(normalizedPhone),
         'profileImageUrl': null,
         'description': '',
         'rating': 0.0,
         'tripsCompleted': 0,
         'bazarPurchases': 0,
         'createdAt': FieldValue.serverTimestamp(),
         'suspended': false,
       });

      await _db.collection('studentCodes').doc(studentCode).set({
        'uid': userCredential.user!.uid,
      });

      // Enviar verificación institucional (excepto admin)
      const adminEmail = 'admin.00@uceva.edu.co';
      final userEmail = userCredential.user?.email?.toLowerCase() ?? '';
      final isAdmin = userEmail == adminEmail;

      if (isAdmin) {
        return 'Cuenta creada exitosamente.';
      }

      try {
        await userCredential.user!.sendEmailVerification();
      } catch (_) {}
      return 'verification_email_sent';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        return 'Ya existe una cuenta con este email.';
      }
      return 'Error al registrar con Google: ${e.message}';
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  Future<UserModel?> getUserData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final decryptedStudentCode = await _decryptFieldAsync(
        data['studentCode'],
      );

      return UserModel.fromMap({
        'id': uid,
        ...data,
        'phone': data['phone'] is Map ? '' : (data['phone']?.toString() ?? ''),
        'studentCode': decryptedStudentCode,
      });
    } catch (e) {
      return null;
    }
  }

  Future<String> updateProfile({
    required String fullName,
    required String role,
    required String faculty,
    required String description,
    required String phone,
    String? profileImageUrl,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 'No hay sesión activa.';

      final normalizedPhone = _normalizePhone(phone);
      if (normalizedPhone == null) {
        return 'Ingresa un número válido de 10 dígitos (ej: 3001234567)';
      }

      // Verificar que el número no esté en uso por otro usuario
      if (await _isPhoneTaken(normalizedPhone, excludeUid: uid)) {
        return 'Este número ya está registrado en otra cuenta.';
      }

      final data = <String, dynamic>{
        'fullName': fullName,
        'role': role,
        'faculty': faculty,
        'description': description,
        'phone': normalizedPhone,
        'hashedPhone': _hashPhone(normalizedPhone),
      };
      if (profileImageUrl != null) data['profileImageUrl'] = profileImageUrl;

      await _db.collection('users').doc(uid).update(data);
      return 'Perfil actualizado correctamente.';
    } catch (e) {
      return 'Error al actualizar el perfil: ${e.toString()}';
    }
  }

  Future<String> updateStudentCode({required String newStudentCode}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 'No hay sesión activa.';

      if (newStudentCode.trim().isEmpty)
        return 'El código no puede estar vacío.';

      // Verificar que el nuevo código no esté en uso por otro usuario
      if (await _isStudentCodeTaken(newStudentCode.trim(), excludeUid: uid)) {
        return 'Este código estudiantil ya está registrado por otro usuario.';
      }

      // Obtener el código anterior para eliminar su entrada en studentCodes
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return 'Usuario no encontrado.';

      // Cifrar el nuevo código con el mismo método que register()
      final encryptedCode = await _encryptFieldAsync(newStudentCode.trim());
      final hashedCode = _hashStudentCode(newStudentCode.trim());

      // Actualizar en la colección users
      await _db.collection('users').doc(uid).update({
        'studentCode': encryptedCode,
        'hashedStudentCode': hashedCode,
      });

      // Registrar en studentCodes (el anterior se mantiene por integridad,
      // el nuevo se agrega apuntando a este uid)
      await _db.collection('studentCodes').doc(newStudentCode.trim()).set({
        'uid': uid,
      });

      return 'Código estudiantil actualizado correctamente.';
    } catch (e) {
      return 'Error al actualizar el código: ${e.toString()}';
    }
  }

  // Normaliza a 10 dígitos (sin prefijo) para guardar y comparar
  String? _normalizePhone(String phone) {
    if (phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return null;
    return digits;
  }

  Future<String> forgotPassword(String email) async {
    try {
      if (email.isEmpty) return 'El correo es obligatorio.';
      if (!_ucevaEmailRegex.hasMatch(email))
        return 'Solo se permiten emails @uceva.edu.co.';
      await _auth.sendPasswordResetEmail(email: email);
      return 'Email de recuperación enviado. Revisa tu bandeja de entrada.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'Usuario no encontrado.';
      if (e.code == 'invalid-credential')
        return 'Correo o contraseña incorrectos.';
      if (e.code == 'invalid-email') return 'Correo inválido.';
      return 'Error al enviar email: ${e.message}';
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  Future<void> logout() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _db.collection('users').doc(uid).update({'fcmToken': null});
      }
    } catch (_) {}
    await _auth.signOut();
  }

  /// Reenvía el correo de verificación al usuario actual.
  /// Retorna 'sent' si fue exitoso, o un mensaje de error.
  Future<String> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No hay sesión activa.';
      await user.sendEmailVerification();
      return 'sent';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') return 'too_many_requests';
      return 'Error al enviar correo: ${e.message}';
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }
}
