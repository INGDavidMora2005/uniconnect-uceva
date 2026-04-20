import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'crypto_service.dart';

/// Servicio de autenticación con cifrado híbrido RSA-2048 + AES-256-CBC
/// Implementación basada en Stallings - Cryptography and Network Security
/// El cifrado añade una capa adicional de seguridad para credenciales

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Servicio de cifrado híbrido RSA + AES-256
  /// ref: Stallings - Cap 10.2 Hybrid Cryptography
  final CryptoService _cryptoService = CryptoService();

  /// Almacenamiento seguro para credenciales cifradas
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
    final stopwatchTotal = Stopwatch()..start();
    debugPrint('[AuthService] INICIO login para email: $email');

    try {
      debugPrint(
        '[AuthService] Iniciando cifrado de contraseña con CryptoService...',
      );
      final stopwatchCrypto = Stopwatch()..start();

      // Cifrar credenciales antes de cualquier operación
      // ref: Stallings - Data Encryption in Transit
      final encryptedPassword = await _cryptoService.encryptPassword(password);

      stopwatchCrypto.stop();
      final cryptoTime = stopwatchCrypto.elapsedMilliseconds;
      debugPrint('[AuthService] Cifrado completado en $cryptoTime ms');

      final cipherPreview = encryptedPassword.ciphertext.length > 20
          ? '${encryptedPassword.ciphertext.substring(0, 20)}...'
          : encryptedPassword.ciphertext;
      debugPrint(
        '[AuthService] Payload generado — ciphertext: $cipherPreview, iv: ${encryptedPassword.iv}, keyLen: ${encryptedPassword.encryptedKey.length}',
      );

      // Almacenar credenciales cifradas de forma segura localmente
      // Esto proporciona recuperación de credentials si es necesario
      await _secureStorage.write(
        key: 'encrypted_credentials_$email',
        value: encryptedPassword.toJson(),
      );

      debugPrint('[AuthService] Enviando credenciales a Firebase Auth...');
      final stopwatchFirebase = Stopwatch()..start();

      // Firebase Auth requiere contraseña en texto plano para verificación
      // El cifrado anterior es para almacenamiento seguro local
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      stopwatchFirebase.stop();
      final firebaseTime = stopwatchFirebase.elapsedMilliseconds;
      debugPrint('[AuthService] Firebase respondió en $firebaseTime ms');

      final uid = credential.user?.uid;
      if (uid != null) {
        final userDoc = await _db.collection('users').doc(uid).get();
        final isSuspended = userDoc.data()?['suspended'] ?? false;
        if (isSuspended) {
          await _auth.signOut();
          debugPrint('[AuthService] Resultado: Cuenta suspendida');
          return 'Tu cuenta ha sido suspendida. Contacta al administrador para más información.';
        }
      }
      stopwatchTotal.stop();
      debugPrint(
        '[AuthService] Resultado: Inicio de sesión exitoso (total: ${stopwatchTotal.elapsedMilliseconds} ms)',
      );
      return 'Inicio de sesión exitoso.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        debugPrint('[AuthService] Resultado: Usuario no encontrado');
        return 'Usuario no encontrado.';
      }
      if (e.code == 'wrong-password') {
        debugPrint('[AuthService] Resultado: Contraseña incorrecta');
        return 'Contraseña incorrecta.';
      }
      if (e.code == 'invalid-email') {
        debugPrint('[AuthService] Resultado: Correo electrónico inválido');
        return 'Correo electrónico inválido.';
      }
      if (e.code == 'user-disabled') {
        debugPrint('[AuthService] Resultado: Cuenta deshabilitada');
        return 'Esta cuenta ha sido deshabilitada.';
      }
      debugPrint('[AuthService] Resultado: Error Firebase — ${e.message}');
      return 'Error al iniciar sesión: ${e.message}';
    } catch (e) {
      debugPrint('[AuthService] Resultado: Error inesperado — ${e.toString()}');
      return 'Error inesperado: ${e.toString()}';
    }
  }

  Future<String> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return 'Inicio de sesión cancelado.';

      if (!googleUser.email.endsWith('@uceva.edu.co')) {
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

      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        await GoogleSignIn().signOut();
        return 'Debes verificar tu email antes de iniciar sesión.';
      }

      final uid = userCredential.user?.uid;
      if (uid != null) {
        final userDoc = await _db.collection('users').doc(uid).get();
        final isSuspended = userDoc.data()?['suspended'] ?? false;
        if (isSuspended) {
          await _auth.signOut();
          await GoogleSignIn().signOut();
          return 'Tu cuenta ha sido suspendida. Contacta al administrador para más información.';
        }
      }

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
  /// El mismo flujo de cifrado que login():
  /// 1. Cifrar contraseña con AES-256-CBC
  /// 2. Cifrar clave AES con RSA-2048 pública
  /// 3. Almacenar de forma segura para recuperación
  Future<String> register({
    required String fullName,
    required String studentCode,
    required String email,
    required String password,
    required String role,
    required String faculty,
    required String phone,
  }) async {
    final stopwatchTotal = Stopwatch()..start();
    debugPrint('[AuthService] INICIO register para email: $email');

    try {
      final normalizedPhone = _normalizePhone(phone);
      if (normalizedPhone == null) {
        debugPrint('[AuthService] Resultado: Teléfono inválido');
        return 'Ingresa un número válido de 10 dígitos (ej: 3001234567)';
      }

      debugPrint(
        '[AuthService] Iniciando cifrado de contraseña con CryptoService...',
      );
      final stopwatchCrypto = Stopwatch()..start();

      // Cifrar contraseña para almacenamiento seguro local
      // ref: Stallings - Secure Storage of Credentials
      final encryptedPassword = await _cryptoService.encryptPassword(password);

      stopwatchCrypto.stop();
      final cryptoTime = stopwatchCrypto.elapsedMilliseconds;
      debugPrint('[AuthService] Cifrado completado en $cryptoTime ms');

      final cipherPreview = encryptedPassword.ciphertext.length > 20
          ? '${encryptedPassword.ciphertext.substring(0, 20)}...'
          : encryptedPassword.ciphertext;
      debugPrint(
        '[AuthService] Payload generado — ciphertext: $cipherPreview, iv: ${encryptedPassword.iv}, keyLen: ${encryptedPassword.encryptedKey.length}',
      );

      await _secureStorage.write(
        key: 'encrypted_credentials_$email',
        value: encryptedPassword.toJson(),
      );

      debugPrint('[AuthService] Enviando credenciales a Firebase Auth...');
      final stopwatchFirebase = Stopwatch()..start();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      stopwatchFirebase.stop();
      final firebaseTime = stopwatchFirebase.elapsedMilliseconds;
      debugPrint('[AuthService] Firebase respondió en $firebaseTime ms');

      // Verificar que el teléfono no esté en uso (ahora hay sesión activa)
      if (await _isPhoneTaken(normalizedPhone)) {
        await credential.user!.delete();
        debugPrint('[AuthService] Resultado: Teléfono ya registrado');
        return 'Este número ya está registrado en otra cuenta.';
      }

      final studentCodeDoc = await _db
          .collection('studentCodes')
          .doc(studentCode)
          .get();
      if (studentCodeDoc.exists) {
        await credential.user!.delete();
        debugPrint('[AuthService] Resultado: Código estudiantil ya registrado');
        return 'Este código estudiantil ya está registrado.';
      }

      await _db.collection('users').doc(credential.user!.uid).set({
        'fullName': fullName,
        'studentCode': studentCode,
        'email': email,
        'role': role,
        'faculty': faculty,
        'phone': normalizedPhone,
        'profileImageUrl': null,
        'description': '',
        'rating': 0.0,
        'tripsCompleted': 0,
        'bazarPurchases': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('studentCodes').doc(studentCode).set({
        'uid': credential.user!.uid,
      });

      stopwatchTotal.stop();
      debugPrint(
        '[AuthService] Resultado: Cuenta creada exitosamente (total: ${stopwatchTotal.elapsedMilliseconds} ms)',
      );
      return 'Cuenta creada exitosamente.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        debugPrint('[AuthService] Resultado: Email ya registrado');
        return 'Este correo ya está registrado.';
      }
      if (e.code == 'weak-password') {
        debugPrint('[AuthService] Resultado: Contraseña débil');
        return 'La contraseña es demasiado débil.';
      }
      if (e.code == 'invalid-email') {
        debugPrint('[AuthService] Resultado: Email inválido');
        return 'El correo no es válido.';
      }
      debugPrint('[AuthService] Resultado: Error Firebase — ${e.message}');
      return 'Error al crear la cuenta: ${e.message}';
    } catch (e) {
      debugPrint('[AuthService] Resultado: Error inesperado — ${e.toString()}');
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

      if (!googleUser.email.endsWith('@uceva.edu.co')) {
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

      await _db.collection('users').doc(userCredential.user!.uid).set({
        'fullName': googleUser.displayName ?? '',
        'studentCode': studentCode,
        'email': googleUser.email,
        'role': role,
        'faculty': faculty,
        'phone': normalizedPhone,
        'profileImageUrl': null,
        'description': '',
        'rating': 0.0,
        'tripsCompleted': 0,
        'bazarPurchases': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('studentCodes').doc(studentCode).set({
        'uid': userCredential.user!.uid,
      });

      return 'Cuenta creada exitosamente.';
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
      return UserModel.fromMap({'id': uid, ...doc.data()!});
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
      };
      if (profileImageUrl != null) data['profileImageUrl'] = profileImageUrl;

      await _db.collection('users').doc(uid).update(data);
      return 'Perfil actualizado correctamente.';
    } catch (e) {
      return 'Error al actualizar el perfil: ${e.toString()}';
    }
  }

  // Normaliza a 10 dígitos (sin prefijo) para guardar y comparar
  String? _normalizePhone(String phone) {
    if (phone.isEmpty) return '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return null;
    return digits;
  }

  // Verifica si un número (normalizado a 10 dígitos) ya está registrado
  Future<bool> _isPhoneTaken(
    String normalizedDigits, {
    String? excludeUid,
  }) async {
    // Buscar por el número sin prefijo
    final snap1 = await _db
        .collection('users')
        .where('phone', isEqualTo: normalizedDigits)
        .limit(1)
        .get();

    // También buscar por número con prefijo +57 (por si hay datos antiguos)
    final withPrefix = '+57$normalizedDigits';
    final snap2 = await _db
        .collection('users')
        .where('phone', isEqualTo: withPrefix)
        .limit(1)
        .get();

    final allDocs = [...snap1.docs, ...snap2.docs];

    if (excludeUid != null) {
      return allDocs.any((doc) => doc.id != excludeUid);
    }
    return allDocs.isNotEmpty;
  }

  Future<String> forgotPassword(String email) async {
    try {
      if (email.isEmpty) return 'El correo es obligatorio.';
      if (!email.endsWith('@uceva.edu.co'))
        return 'Solo se permiten emails @uceva.edu.co.';
      await _auth.sendPasswordResetEmail(email: email);
      return 'Email de recuperación enviado. Revisa tu bandeja de entrada.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'Usuario no encontrado.';
      if (e.code == 'invalid-email') return 'Correo inválido.';
      return 'Error al enviar email: ${e.message}';
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  Future<void> logout() async => await _auth.signOut();
}
