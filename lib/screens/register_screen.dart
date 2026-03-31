import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _nameController     = TextEditingController();
  final _codeController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;

  final List<String> _roles = ['Estudiante', 'Docente', 'Administrativo'];

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      _showError('Selecciona un rol');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthService().register(
        fullName:    _nameController.text.trim(),
        studentCode: _codeController.text.trim(),
        email:       _emailController.text.trim(),
        password:    _passwordController.text,
        role:        _selectedRole!,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada exitosamente!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        Navigator.pop(context);
      } else {
        _showError('No se pudo crear la cuenta. Verifica tus datos.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Error: ${e.toString()}');
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
                const SizedBox(height: 40),
                const Text(
                  'Crea tu cuenta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Solo para la comunidad UCEVA',
                  style: TextStyle(fontSize: 14, color: AppColors.textLight),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completa los siguientes campos para realizar el registro',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
                const SizedBox(height: 32),

                CustomTextField(
                  label: 'Nombre completo',
                  hint: 'Tu nombre completo',
                  controller: _nameController,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingresa tu nombre' : null,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Código Estudiantil',
                  hint: 'Ej: 230231053',
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingresa tu código' : null,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Correo Institucional (@uceva.edu.co)',
                  hint: 'nombre@uceva.edu.co',
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
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Contraseña',
                  hint: 'Crea una contraseña',
                  isPassword: true,
                  controller: _passwordController,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Confirma la contraseña',
                  hint: 'Repite tu contraseña',
                  isPassword: true,
                  controller: _confirmController,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                    if (v != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Selector de Rol
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rol',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text(
                            'Selecciona tu rol',
                            style: TextStyle(
                              color: AppColors.textPlaceholder,
                              fontSize: 14,
                            ),
                          ),
                          value: _selectedRole,
                          items: _roles
                              .map((r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedRole = v),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                PrimaryButton(
                  text: 'Crear cuenta',
                  onPressed: _handleRegister,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: const TextSpan(
                      text: '¿Ya tienes cuenta? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: 'Inicia sesión',
                          style: TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}