import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';

class EditarProductoScreen extends StatefulWidget {
  final ProductModel product;

  const EditarProductoScreen({super.key, required this.product});

  @override
  State<EditarProductoScreen> createState() => _EditarProductoScreenState();
}

class _EditarProductoScreenState extends State<EditarProductoScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;

  late String _category;
  late String _contactMethod;
  bool _loading = false;
  bool _uploadingImages = false;
  final List<File> _selectedImages = [];

  final List<String> _categories = [
    'Libros',
    'Batas',
    'Calculadoras',
    'Equipos',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(
      text: widget.product.price.toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.product.description,
    );
    _category = widget.product.category;
    _contactMethod = widget.product.contactMethod;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && _selectedImages.length < 3) {
      setState(() => _selectedImages.add(File(pickedFile.path)));
    }
  }

  Future<void> _handleUpdate() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Ingresa el nombre del producto');
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      _showError('Ingresa el precio');
      return;
    }
    if (_selectedImages.isEmpty && widget.product.imageUrls.isEmpty) {
      _showError('Selecciona al menos una foto del producto');
      return;
    }

    setState(() => _uploadingImages = true);

    try {
      List<String> imageUrls = widget.product.imageUrls;
      if (_selectedImages.isNotEmpty) {
        // Upload new images
        imageUrls = [];
        for (final image in _selectedImages) {
          final url = await CloudinaryService.uploadImage(image);
          imageUrls.add(url);
        }
      }

      setState(() => _uploadingImages = false);
      setState(() => _loading = true);

      final priceText = _priceController.text
          .trim()
          .replaceAll('.', '')
          .replaceAll(',', '');
      final price = double.tryParse(priceText) ?? 0;

      final updatedProduct = ProductModel(
        id: widget.product.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        category: _category,
        contactMethod: _contactMethod,
        imageUrls: imageUrls,
        sellerId: widget.product.sellerId,
        sellerName: widget.product.sellerName,
        sellerInitials: widget.product.sellerInitials,
        sellerRating: widget.product.sellerRating,
        sellerCareer: widget.product.sellerCareer,
        sellerPhone: widget.product.sellerPhone,
        status: widget.product.status,
        createdAt: widget.product.createdAt,
      );

      final result = await ProductService().updateProduct(updatedProduct);
      if (!mounted) return;
      setState(() => _loading = false);

      if (result == 'ok') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Producto actualizado')));
        Navigator.pop(context, true);
      } else {
        _showError(result);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _uploadingImages = false;
      });
      final msg = e is CloudinaryUploadException
          ? e.message
          : 'Error inesperado. Intenta de nuevo.';
      _showError(msg);
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
          title: const Text(
            'Editar producto',
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
              // Fotos
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Fotos del producto'),
                  if (widget.product.imageUrls.isNotEmpty &&
                      _selectedImages.isEmpty)
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.product.imageUrls.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(
                                  widget.product.imageUrls[index],
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_selectedImages.isNotEmpty)
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_selectedImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedImages.removeAt(index),
                                    ),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (_selectedImages.length < 3)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.accentGreen.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                color: AppColors.accentGreen,
                                size: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Cambiar fotos (${_selectedImages.isEmpty ? widget.product.imageUrls.length : _selectedImages.length}/3)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              _label('Nombre del producto'),
              _field(
                controller: _nameController,
                hint: 'Ej: Calculadora marca casio ...',
              ),

              const SizedBox(height: 16),

              _label('Categoría'),
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
                    value: _category,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textMedium,
                    ),
                    items: _categories
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
                    onChanged: (v) => setState(() => _category = v ?? 'Libros'),
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
                  onPressed: (_loading || _uploadingImages)
                      ? null
                      : _handleUpdate,
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
                  child: (_loading || _uploadingImages)
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Actualizar producto',
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
