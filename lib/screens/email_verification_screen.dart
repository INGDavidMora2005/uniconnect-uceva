import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  int _countdown = 0;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _handleResend() async {
    if (_countdown > 0) return;

    setState(() => _isLoading = true);
    final result = await AuthService().sendVerificationEmail();
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result == 'sent') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo reenviado. Revisa tu bandeja de entrada.'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
      _startCountdown();
    } else if (result == 'too_many_requests') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demasiados intentos. Espera antes de reenviar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono
                Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.accentGreen,
                  size: 72,
                ),
                const SizedBox(height: 24),
                // Título
                const Text(
                  'Revisa tu correo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                // Subtítulo
                const Text(
                  'Hemos enviado un enlace de verificación a:',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                // Email mostrado
                Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                //Texto explicativo
                const Text(
                  'Una vez verificado, podrás iniciar sesión normalmente.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Botón Reenviar
                PrimaryButton(
                  text: _countdown > 0 ? 'Reenviar en ${_countdown}s' : 'Reenviar correo',
                  onPressed: _handleResend,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                // Botón Volver al inicio de sesión
                TextButton(
                  onPressed: () async {
                    await AuthService().logout();
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text('Volver al inicio de sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
