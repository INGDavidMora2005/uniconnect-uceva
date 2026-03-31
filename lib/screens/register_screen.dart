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
  String? _selectedFaculty;
  bool _isLoading = false;
  bool _useGoogle = false; // true para Google, false para formulario

  final List<String> _roles = ['Estudiante', 'Docente', 'Administrativo'];
  final List<String> _faculties = [
    'Facultad de Ingeniería',
    'Facultad de Ciencias Sociales',
    'Facultad de Ciencias de la Salud',
    'Facultad de Ciencias Básicas',
    'Facultad de Ciencias de la Educación',
    'Facultad de Ciencias de la Comunicación',
  ];

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
    if (_selectedRole == null) {
      _showError('Selecciona un rol');
      return;
    }
    if (_selectedFaculty == null) {
      _showError('Selecciona una facultad');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final message = _useGoogle
          ? await AuthService().registerWithGoogle(
              studentCode: _codeController.text.trim(),
              role:    _selectedRole!,
              faculty: _selectedFaculty!,
            )
          : await AuthService().register(
              fullName:    _nameController.text.trim(),
              studentCode: _codeController.text.trim(),
              email:       _emailController.text.trim(),
              password:    _passwordController.text,
              role:        _selectedRole!,
              faculty:     _selectedFaculty!,
            );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (message.startsWith('Cuenta creada')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        Navigator.pop(context);
      } else {
        _showError(message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Error inesperado: ${e.toString()}');
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

                if (_useGoogle) ...[
                  CustomTextField(
                    label: 'Código Estudiantil',
                    hint: 'Ej: 230231053',
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Ingresa tu código' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_useGoogle) ...[
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
                      if (v.length < 8) return 'Mínimo 8 caracteres';
                      if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Debe contener al menos una mayúscula';
                      if (!RegExp(r'[a-z]').hasMatch(v)) return 'Debe contener al menos una minúscula';
                      if (!RegExp(r'[0-9]').hasMatch(v)) return 'Debe contener al menos un número';
                      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v)) return 'Debe contener al menos un carácter especial';
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
                ],

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

                const SizedBox(height: 16),

                // Selector de Facultad
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Facultad',
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
                            'Selecciona tu facultad',
                            style: TextStyle(
                              color: AppColors.textPlaceholder,
                              fontSize: 14,
                            ),
                          ),
                          value: _selectedFaculty,
                          items: _faculties
                              .map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedFaculty = v),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                PrimaryButton(
                  text: _useGoogle ? 'Registrarse con Google' : 'Crear cuenta',
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