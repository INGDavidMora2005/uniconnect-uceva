import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  Future<bool> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── REGISTRO ──────────────────────────────────────────────
  Future<bool> register({
    required String fullName,
    required String studentCode,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
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
        'faculty':     '',
        'rating':      0.0,
        'createdAt':   FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
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
  Future<bool> updateProfile({
    required String fullName,
    required String role,
    required String faculty,
    required String description,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      await _db.collection('users').doc(uid).set({
      
        'fullName': fullName,
        'role': role,
        'faculty': faculty,
        'description': description,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      return false;
    }
  }

  // ── LOGOUT ────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
  }
}