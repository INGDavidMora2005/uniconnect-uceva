import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── LOGIN ─────────────────────────────────────────────────
  Future<String> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return 'Inicio de sesión exitoso.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'Usuario no encontrado.';
      if (e.code == 'wrong-password') return 'Contraseña incorrecta.';
      if (e.code == 'invalid-email') return 'Correo electrónico inválido.';
      if (e.code == 'user-disabled')
        return 'Esta cuenta ha sido deshabilitada.';
      return 'Error al iniciar sesión: ${e.message}';
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  // ── LOGIN CON GOOGLE ──────────────────────────────────────
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

  // ── REGISTRO ──────────────────────────────────────────────
  Future<String> register({
    required String fullName,
    required String studentCode,
    required String email,
    required String password,
    required String role,
    required String faculty,
    required String phone, // ← NUEVO
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final studentCodeDoc = await _db
          .collection('studentCodes')
          .doc(studentCode)
          .get();
      if (studentCodeDoc.exists) {
        await credential.user!.delete();
        return 'Este código estudiantil ya está registrado.';
      }

      await _db.collection('users').doc(credential.user!.uid).set({
        'fullName': fullName,
        'studentCode': studentCode,
        'email': email,
        'role': role,
        'faculty': faculty,
        'phone': phone,
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

      return 'Cuenta creada exitosamente.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use')
        return 'Este correo ya está registrado.';
      if (e.code == 'weak-password') return 'La contraseña es demasiado débil.';
      if (e.code == 'invalid-email') return 'El correo no es válido.';
      return 'Error al crear la cuenta: ${e.message}';
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  // ── REGISTRO CON GOOGLE ───────────────────────────────────
  Future<String> registerWithGoogle({
    required String studentCode,
    required String role,
    required String faculty,
    required String phone, // ← NUEVO
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

      await _db.collection('users').doc(userCredential.user!.uid).set({
        'fullName': googleUser.displayName ?? '',
        'studentCode': studentCode,
        'email': googleUser.email,
        'role': role,
        'faculty': faculty,
        'phone': phone,
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

  // ── OBTENER DATOS DEL USUARIO ─────────────────────────────
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

  // ── ACTUALIZAR PERFIL ─────────────────────────────────────
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
      final data = <String, dynamic>{
        'fullName': fullName,
        'role': role,
        'faculty': faculty,
        'description': description,
        'phone': phone,
      };
      if (profileImageUrl != null) data['profileImageUrl'] = profileImageUrl;
      await _db.collection('users').doc(uid).update(data);
      return 'Perfil actualizado correctamente.';
    } catch (e) {
      return 'Error al actualizar el perfil: ${e.toString()}';
    }
  }

  // ── RESET PASSWORD ────────────────────────────────────────
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

  // ── LOGOUT ────────────────────────────────────────────────
  Future<void> logout() async => await _auth.signOut();
}
