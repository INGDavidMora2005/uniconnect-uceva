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

  // ── LOGIN CON GOOGLE ──────────────────────────────────────
  Future<String> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return 'Inicio de sesión cancelado.';
      }

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
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Verificar studentCode después de autenticar
      final studentCodeDoc = await _db
          .collection('studentCodes')
          .doc(studentCode)
          .get();
      if (studentCodeDoc.exists) {
        // Eliminar la cuenta recién creada si el código ya existe
        await credential.user!.delete();
        return 'Este código estudiantil ya está registrado.';
      }

      await _db.collection('users').doc(credential.user!.uid).set({
        'fullName': fullName,
        'studentCode': studentCode,
        'email': email,
        'role': role,
        'faculty': faculty,
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
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }

      try {
        await GoogleSignIn().disconnect();
      } catch (e) {
        // Ignorar si no hay sesión activa de Google
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return 'Registro cancelado por el usuario.';
      }

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
        final existingStudentCode = existingUserDoc.data()?['studentCode'];
        if (existingStudentCode != studentCode) {
          await _auth.signOut();
          await GoogleSignIn().signOut();
          return 'Este email ya está registrado con un código estudiantil diferente.';
        }
        return 'Ya tienes una cuenta registrada con este email y código estudiantil.';
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
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 'No hay sesión activa.';

      await _db.collection('users').doc(uid).update({
        'fullName': fullName,
        'role': role,
        'faculty': faculty,
        'description': description,
      });

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
