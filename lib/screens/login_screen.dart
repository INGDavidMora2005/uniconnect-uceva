import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'home_rutas_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _useGoogle = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_useGoogle && !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final message = _useGoogle
        ? await AuthService().loginWithGoogle()
        : await AuthService().login(
            _emailController.text.trim(),
            _passwordController.text,
          );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (message.startsWith('Inicio de sesión exitoso')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeRutasScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Text(
                  'Bienvenido a',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textLight,
                  ),
                ),
                const Text(
                  'UniConnect',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa con tu correo institucional UCEVA',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
                const SizedBox(height: 24),

                // Toggle entre Google y Formulario
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _useGoogle = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _useGoogle ? AppColors.accentGreen : AppColors.backgroundWhite,
                          foregroundColor: _useGoogle ? Colors.white : AppColors.textDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Google'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _useGoogle = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_useGoogle ? AppColors.accentGreen : AppColors.backgroundWhite,
                          foregroundColor: !_useGoogle ? Colors.white : AppColors.textDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Formulario'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!_useGoogle) ...[
                  CustomTextField(
                    label: 'Correo',
                    hint: 'Correo institucional',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa tu correo';
                      if (!v.contains('@uceva.edu.co')) {
                        return 'Usa tu correo @uceva.edu.co';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Contraseña',
                    hint: 'Contraseña',
                    isPassword: true,
                    controller: _passwordController,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                      if (v.length < 8) return 'Mínimo 8 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                ],
                PrimaryButton(
                  text: _useGoogle ? 'Iniciar sesión con Google' : 'Iniciar sesión',
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text(
                        'Regístrate aquí',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}