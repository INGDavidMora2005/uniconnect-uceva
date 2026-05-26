import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'home_rutas_screen.dart';
import 'forgot_password_screen.dart';
import 'email_verification_screen.dart';

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
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final hasText = _passwordController.text.isNotEmpty;
    if (hasText != _hasPassword) {
      setState(() => _hasPassword = hasText);
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_useGoogle && !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String message;
    try {
      if (_useGoogle) {
        final result = await AuthService().loginWithGoogle();
        if (result.isEmpty ||
            result.contains('cancelado') ||
            result.contains('Error')) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Google Sign-In no está disponible en este dispositivo',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
        message = result;
      } else {
        message = await AuthService().login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Sign-In no está disponible en este dispositivo',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (message.startsWith('email_not_verified:')) {
      final emailFromMsg = message.split(':').length > 1
          ? message.substring('email_not_verified:'.length)
          : '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(email: emailFromMsg),
        ),
      );
      return;
    }

    if (message.startsWith('Inicio de sesión exitoso')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeRutasScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
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
                  style: TextStyle(fontSize: 16, color: AppColors.textLight),
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
                          backgroundColor: _useGoogle
                              ? AppColors.accentGreen
                              : AppColors.backgroundWhite,
                          foregroundColor: _useGoogle
                              ? Colors.white
                              : AppColors.textDark,
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
                          backgroundColor: !_useGoogle
                              ? AppColors.accentGreen
                              : AppColors.backgroundWhite,
                          foregroundColor: !_useGoogle
                              ? Colors.white
                              : AppColors.textDark,
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
                       if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@uceva\.edu\.co$').hasMatch(v)) {
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
                      if (v == null || v.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (v.length < 8) return 'Mínimo 8 caracteres';
                      return null;
                    },
                  ),
                   if (_hasPassword) ...[
                     const SizedBox(height: 8),
                     if (kDebugMode) // UU-42 B-08: badge solo visible en debug
                       GestureDetector(
                         onTap: () => Navigator.pushNamed(context, '/crypto-test'),
                         child: Container(
                           padding: const EdgeInsets.symmetric(
                             horizontal: 10,
                             vertical: 4,
                           ),
                           decoration: BoxDecoration(
                             color: const Color(
                               0xFF1B5E20,
                             ).withValues(alpha: 0.15),
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(
                               color: const Color(0xFF2E7D32),
                               width: 1,
                             ),
                           ),
                           child: const Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Icon(
                                 Icons.lock_outline,
                                 size: 12,
                                 color: Color(0xFF2E7D32),
                               ),
                               SizedBox(width: 4),
                               Text(
                                 'AES-256 + RSA-2048 activo',
                                 style: TextStyle(
                                   fontSize: 11,
                                   color: Color(0xFF2E7D32),
                                   fontWeight: FontWeight.w500,
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),
                   ],
                  const SizedBox(height: 30),
                ],
                PrimaryButton(
                  text: _useGoogle
                      ? 'Iniciar sesión con Google'
                      : 'Iniciar sesión',
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
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
