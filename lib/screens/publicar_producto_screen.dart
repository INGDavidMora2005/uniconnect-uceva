import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class PublicarProductoScreen extends StatefulWidget {
  const PublicarProductoScreen({super.key});

  @override
  State<PublicarProductoScreen> createState() => _PublicarProductoScreenState();
}

class _PublicarProductoScreenState extends State<PublicarProductoScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _condition = 'Nuevo';
  String _contactMethod = 'Whatsapp';
  bool _loading = false;

  final List<String> _conditions = [
    'Nuevo',
    'Como nuevo',
    'Buen estado',
    'Regular',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handlePublish() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Ingresa el nombre del producto');
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      _showError('Ingresa el precio');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Ingresa una descripción');
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await AuthService().getUserData();
      if (user == null) {
        _showError('No se pudo obtener tu información');
        setState(() => _loading = false);
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final parts = user.fullName.trim().split(' ');
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : parts[0][0].toUpperCase();

      final priceText = _priceController.text
          .trim()
          .replaceAll('.', '')
          .replaceAll(',', '');
      final price = double.tryParse(priceText) ?? 0;

      final product = ProductModel(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        condition: _condition,
        contactMethod: _contactMethod,
        imageUrls: [],
        sellerId: uid,
        sellerName: parts[0] + (parts.length > 1 ? ' ${parts[1][0]}.' : ''),
        sellerInitials: initials,
        sellerRating: user.rating,
        sellerCareer: user
            .faculty, // ✅ Fix: era user.career (no existe), se usa user.faculty
        status: 'Disponible',
      );

      final result = await ProductService().publishProduct(product);
      if (!mounted) return;
      setState(() => _loading = false);

      if (result == 'ok') {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.accentGreen,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Producto publicado!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu producto ya está visible en el Bazar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        _showError(result);
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F1),
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'Publicar producto',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto placeholder
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.accentGreen.withOpacity(0.4),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.accentGreen,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Agregar fotos del producto',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Máximo 5 fotos',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textPlaceholder,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _label('Nombre del producto'),
              _field(
                controller: _nameController,
                hint: 'Ej: Calculadora marca casio ...',
              ),
              const SizedBox(height: 16),

              _label('Estado'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _condition,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textMedium,
                    ),
                    items: _conditions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _condition = v ?? 'Nuevo'),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Precio'),
              _field(
                controller: _priceController,
                hint: '\$ 0.000',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              _label('Descripción'),
              _field(
                controller: _descriptionController,
                hint: 'Describe el estado y detalles del producto',
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              _label('Contacto preferido'),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _contactMethod = 'Whatsapp'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _contactMethod == 'Whatsapp'
                              ? AppColors.accentGreen
                              : Colors.white,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10),
                          ),
                          border: Border.all(
                            color: _contactMethod == 'Whatsapp'
                                ? AppColors.accentGreen
                                : AppColors.borderDefault,
                          ),
                        ),
                        child: Text(
                          'Whatsapp',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _contactMethod == 'Whatsapp'
                                ? Colors.white
                                : AppColors.textMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _contactMethod = 'Chat app'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _contactMethod == 'Chat app'
                              ? AppColors.accentGreen
                              : Colors.white,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(10),
                          ),
                          border: Border.all(
                            color: _contactMethod == 'Chat app'
                                ? AppColors.accentGreen
                                : AppColors.borderDefault,
                          ),
                        ),
                        child: Text(
                          'Chat app',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _contactMethod == 'Chat app'
                                ? Colors.white
                                : AppColors.textMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handlePublish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    disabledBackgroundColor: AppColors.accentGreen.withOpacity(
                      0.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Publicar producto',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMedium,
      ),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 14, color: AppColors.textDark),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: AppColors.textPlaceholder,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accentGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
