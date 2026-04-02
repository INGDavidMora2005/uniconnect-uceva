import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedFaculty;

  String? _selectedRole;

  bool _loading = true;
  bool _saving = false;

  final List<String> roles = [
    'Estudiante',
    'Docente',
    'Administrativo',
    'Colaborador',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
  final user = await AuthService().getUserData();

  if (user != null) {
    _nameController.text = user.fullName;
    _descriptionController.text = user.description;
    _selectedRole = user.role;

    _selectedFaculty =
        user.faculty.isNotEmpty ? user.faculty : null;
  }

  if (!mounted) return;
  setState(() {
    _loading = false;
  });
}

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final result = await AuthService().updateProfile(
      fullName: _nameController.text.trim(),
      role: _selectedRole ?? '',
      faculty: _selectedFaculty ?? '',
      description: _descriptionController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );

    if (result == 'Perfil actualizado correctamente.') {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppColors.textPlaceholder,
        fontSize: 14,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Editar Perfil',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentGreen,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 38,
                              backgroundColor: AppColors.accentGreen,
                              child: Icon(
                                Icons.person,
                                size: 34,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cambio de foto pendiente'),
                                  ),
                                );
                              },
                              child: const Text(
                                'Cambiar foto',
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildSectionLabel('Nombre completo'),
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            _inputDecoration('Ingresa tu nombre completo'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildSectionLabel('Descripción breve'),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration:
                            _inputDecoration('Escribe una breve descripción'),
                      ),
                      const SizedBox(height: 16),

                      _buildSectionLabel('Rol'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: _inputDecoration('Selecciona tu rol'),
                        items: roles.map((role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'El rol es obligatorio';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildSectionLabel('Facultad'),
DropdownButtonFormField<String>(
  value: _selectedFaculty,
  dropdownColor: Colors.white,
  decoration: _inputDecoration('Selecciona tu facultad'),
  items: const [
    DropdownMenuItem(
      value: 'Facultad de Ingeniería',
      child: Text('Facultad de Ingeniería'),
    ),
    DropdownMenuItem(
      value: 'Facultad de Ciencias Sociales',
      child: Text('Facultad de Ciencias Sociales'),
    ),
    DropdownMenuItem(
      value: 'Facultad de Ciencias de la Salud',
      child: Text('Facultad de Ciencias de la Salud'),
    ),
    DropdownMenuItem(
      value: 'Facultad de Ciencias Básicas',
      child: Text('Facultad de Ciencias Básicas'),
    ),
    DropdownMenuItem(
      value: 'Facultad de Ciencias de la Educación',
      child: Text('Facultad de Ciencias de la Educación'),
    ),
    DropdownMenuItem(
      value: 'Facultad de Ciencias de la Comunicación',
      child: Text('Facultad de Ciencias de la Comunicación'),
    ),
  ],
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'La facultad es obligatoria';
    }
    return null;
  },
  onChanged: (value) {
    setState(() {
      _selectedFaculty = value;
    });
  },
),
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Guardar cambios',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}