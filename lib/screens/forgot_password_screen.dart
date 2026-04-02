import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/unicomnect_logo_light.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _resetPassword() async {
    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    final result = await _authService.forgotPassword(email);

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );

    if (result.contains('enviado')) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const UniConnectLogoLight(scale: 1.2),
            const SizedBox(height: 40),
            const Text(
              'Ingresa tu correo electrónico para recibir un enlace de recuperación.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nota: El email puede llegar a la carpeta de Spam.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _emailController,
              label: 'Correo Electrónico',
              hint: 'Ingresa tu email @uceva.edu.co',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : PrimaryButton(
                    text: 'Enviar Email',
                    onPressed: _resetPassword,
                  ),
          ],
        ),
      ),
    );
  }
}