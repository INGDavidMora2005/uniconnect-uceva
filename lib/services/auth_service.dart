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

  // Usuario actual de Firebase
  User? get currentUser => _auth.currentUser;

  // Stream del estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── LOGIN ─────────────────────────────────────────────────
  Future<String> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Verificar si el email está confirmado
      if (!credential.user!.emailVerified) {
        await _auth.signOut();
        return 'Debes verificar tu email antes de iniciar sesión. Revisa tu bandeja de entrada.';
      }

      return 'Inicio de sesión exitoso.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'Usuario no encontrado.';
      } else if (e.code == 'wrong-password') {
        return 'Contraseña incorrecta.';
      } else if (e.code == 'invalid-email') {
        return 'Correo electrónico inválido.';
      } else if (e.code == 'user-disabled') {
        return 'Esta cuenta ha sido deshabilitada.';
      } else {
        return 'Error al iniciar sesión: ${e.message}';
      }
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  // ── LOGIN CON GOOGLE ───────────────────────────────────────
  Future<String> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return 'Inicio de sesión cancelado.';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Verificar si el email está confirmado
      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        await GoogleSignIn().signOut();
        return 'Debes verificar tu email antes de iniciar sesión. Revisa tu bandeja de entrada.';
      }

      return 'Inicio de sesión exitoso.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        return 'Ya existe una cuenta con este email usando otro método.';
      } else {
        return 'Error al iniciar sesión con Google: ${e.message}';
      }
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
  }) async {
    try {
      // Verificar que el código estudiantil sea único
      final studentCodeDoc = await _db.collection('studentCodes').doc(studentCode).get();
      if (studentCodeDoc.exists) {
        return 'Este código estudiantil ya está registrado.';
      }

      // 1. Crear usuario en Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Guardar datos del usuario en Firestore
      await _db.collection('users').doc(credential.user!.uid).set({
        'fullName':    fullName,
        'studentCode': studentCode,
        'email':       email,
        'role':        role,
        'faculty':     faculty,
        'rating':      0.0,
        'createdAt':   FieldValue.serverTimestamp(),
      });

      // Crear registro en studentCodes para unicidad
      await _db.collection('studentCodes').doc(studentCode).set({
        'uid': credential.user!.uid,
      });

      return 'Cuenta creada exitosamente.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'Este correo electrónico ya está registrado.';
      } else if (e.code == 'weak-password') {
        return 'La contraseña es demasiado débil.';
      } else if (e.code == 'invalid-email') {
        return 'El correo electrónico no es válido.';
      } else {
        return 'Error al crear la cuenta: ${e.message}';
      }
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  // ── REGISTRO CON GOOGLE ───────────────────────────────────
  Future<String> registerWithGoogle({
    required String studentCode,
    required String role,
    required String faculty,
  }) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return 'Registro cancelado por el usuario.';
      }

      // Validar dominio @uceva.edu.co
      if (!googleUser.email.endsWith('@uceva.edu.co')) {
        await GoogleSignIn().signOut();
        return 'Solo se permiten emails @uceva.edu.co.';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Verificar que el código estudiantil sea único
      final studentCodeDoc = await _db.collection('studentCodes').doc(studentCode).get();
      if (studentCodeDoc.exists) {
        await _auth.signOut();
        await GoogleSignIn().signOut();
        return 'Este código estudiantil ya está registrado.';
      }

      // Guardar datos adicionales en Firestore
      await _db.collection('users').doc(userCredential.user!.uid).set({
        'fullName':    googleUser.displayName ?? '',
        'studentCode': studentCode,
        'email':       googleUser.email,
        'role':        role,
        'faculty':     faculty,
        'rating':      0.0,
        'createdAt':   FieldValue.serverTimestamp(),
      });

      // Crear registro en studentCodes para unicidad
      await _db.collection('studentCodes').doc(studentCode).set({
        'uid': userCredential.user!.uid,
      });

      // Enviar email de verificación adicional
      await userCredential.user!.sendEmailVerification();

      return 'Cuenta creada exitosamente. Revisa tu email para verificar la cuenta.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        return 'Ya existe una cuenta con este email.';
      } else {
        return 'Error al registrar con Google: ${e.message}';
      }
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

      return UserModel.fromMap({
        'id': uid,
        ...doc.data()!,
      });
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
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return 'No hay un usuario autenticado.';
      }

      await _db.collection('users').doc(uid).set({
        'fullName': fullName,
        'role': role,
        'faculty': faculty,
        'description': description,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return 'Perfil actualizado correctamente.';
    } catch (e) {
      return 'Error al actualizar el perfil: ${e.toString()}';
    }
  }

  // ── LOGOUT ────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
  }
}