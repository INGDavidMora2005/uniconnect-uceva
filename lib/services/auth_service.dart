// TODO: reemplazar con Firebase Auth cuando esté lista la integración
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 2));
    return email.contains('@uceva.edu.co') && password.length >= 6;
  }

  Future<bool> register({
    required String fullName,
    required String studentCode,
    required String email,
    required String password,
    required String role,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }

  Future<void> logout() async {}
}