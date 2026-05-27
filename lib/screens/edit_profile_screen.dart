import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _studentCodeController = TextEditingController();

  String? _selectedFaculty;
  String? _selectedRole;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _profileImageUrl;
  String _originalStudentCode = ''; // URL de la imagen de perfil

  // ── Listas de opciones ─────────────────────────────────────
  final List<String> _roles = [
    'Estudiante',
    'Docente',
    'Administrativo',
    'Colaborador',
  ];

  final List<String> _faculties = [
    'Facultad de Ingeniería',
    'Facultad de Ciencias Sociales',
    'Facultad de Ciencias de la Salud',
    'Facultad de Ciencias Básicas',
    'Facultad de Ciencias de la Educación',
    'Facultad de Ciencias de la Comunicación',
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
      _phoneController.text = user.phone;
      _profileImageUrl = user.profileImageUrl;

      _originalStudentCode = user.studentCode ?? '';
      _studentCodeController.text = _originalStudentCode;

      _selectedRole = _roles.contains(user.role) ? user.role : null;
      _selectedFaculty = _faculties.contains(user.faculty)
          ? user.faculty
          : null;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final url = await CloudinaryService.uploadImage(File(picked.path));
      setState(() {
        _profileImageUrl = url;
        _uploadingImage = false;
      });
    } catch (e) {
      setState(() => _uploadingImage = false);
      if (mounted) {
        final msg = e is CloudinaryUploadException
            ? e.message
            : 'Error inesperado al subir la imagen.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // 1. Guardar perfil
    final profileResult = await AuthService().updateProfile(
      fullName: _nameController.text.trim(),
      role: _selectedRole ?? '',
      faculty: _selectedFaculty ?? '',
      description: _descriptionController.text.trim(),
      phone: _phoneController.text.trim(),
      profileImageUrl: _profileImageUrl,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!profileResult.startsWith('Perfil actualizado')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileResult),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 2. Actualizar código estudiantil si cambió
    final newCode = _studentCodeController.text.trim();
    if (newCode != _originalStudentCode) {
      final codeResult = await AuthService().updateStudentCode(
        newStudentCode: newCode,
      );

      if (!codeResult.startsWith('Código estudiantil actualizado')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(codeResult),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    // 3. Éxito
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil actualizado correctamente.'),
        backgroundColor: AppColors.accentGreen,
      ),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _studentCodeController.dispose();
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

  Widget _sectionLabel(String text) => Padding(
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
                child: CircularProgressIndicator(color: AppColors.accentGreen),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Avatar ───────────────────────────────
                      Center(
                        child: Column(
                          children: [
                            _uploadingImage
                                ? const CircleAvatar(
                                    radius: 38,
                                    backgroundColor: AppColors.accentGreen,
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 38,
                                    backgroundColor: AppColors.accentGreen,
                                    backgroundImage: _profileImageUrl != null
                                        ? NetworkImage(_profileImageUrl!)
                                        : null,
                                    child: _profileImageUrl == null
                                        ? const Icon(
                                            Icons.person,
                                            size: 34,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _uploadingImage ? null : _pickImage,
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
                      const SizedBox(height: 16),

                      // ── Nombre ───────────────────────────────
                      _sectionLabel('Nombre completo'),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration(
                          'Ingresa tu nombre completo',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Descripción ──────────────────────────
                      _sectionLabel('Descripción breve'),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration(
                          'Escribe una breve descripción',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Rol ──────────────────────────────────
                      _sectionLabel('Rol'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: _inputDecoration('Selecciona tu rol'),
                        items: _roles
                            .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            )
                            .toList(),
                        validator: (v) => v == null || v.isEmpty
                            ? 'El rol es obligatorio'
                            : null,
                        onChanged: (v) => setState(() => _selectedRole = v),
                      ),
                      const SizedBox(height: 12),

                      // ── Facultad ─────────────────────────────
                      _sectionLabel('Facultad'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedFaculty,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        decoration: _inputDecoration('Selecciona tu facultad'),
                        items: _faculties
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(f, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        validator: (v) => v == null || v.isEmpty
                            ? 'La facultad es obligatorio'
                            : null,
                        onChanged: (v) => setState(() => _selectedFaculty = v),
                      ),
                       const SizedBox(height: 12),

                       // ── Código Estudiantil ─────────────────────
                       _sectionLabel('Código Estudiantil'),
                       TextFormField(
                         controller: _studentCodeController,
                         decoration: _inputDecoration('Ej: 230231053'),
                         keyboardType: TextInputType.number,
                         validator: (v) {
                           if (v == null || v.trim().isEmpty) {
                             return 'Ingresa tu código estudiantil';
                           }
                           return null;
                         },
                       ),
                       const SizedBox(height: 12),

                       // ── Teléfono ─────────────────────────────
                       _sectionLabel('Teléfono WhatsApp'),
                      TextFormField(
                        controller: _phoneController,
                        decoration: _inputDecoration('Ej: 3001234567'),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final digits = value.replaceAll(RegExp(r'\D'), '');
                          if (digits.length != 10) {
                            return 'El número debe tener 10 dígitos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Botón Guardar ────────────────────────
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
