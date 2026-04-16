import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import 'editar_producto_screen.dart';

class MisPublicacionesScreen extends StatefulWidget {
  const MisPublicacionesScreen({super.key});

  @override
  State<MisPublicacionesScreen> createState() => _MisPublicacionesScreenState();
}

class _MisPublicacionesScreenState extends State<MisPublicacionesScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mis publicaciones',
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<ProductModel>>(
          stream: _uid != null ? ProductService().getMyProducts(_uid!) : null,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentGreen),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              );
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 48,
                      color: AppColors.borderDefault,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No tienes publicaciones',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '¡Publica tu primer producto!',
                      style: TextStyle(
                        color: AppColors.textPlaceholder,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProductCard(
                  product: products[i],
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditarProductoScreen(product: products[i]),
                    ),
                  ).then((_) => setState(() {})),
                  onDelete: () => _confirmDelete(products[i]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar producto'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este producto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ProductService().deleteProduct(product.id);
      if (!mounted) return;
      if (result == 'ok') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Producto eliminado')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(14),
            ),
            child: product.imageUrls.isNotEmpty
                ? Image.network(
                    product.imageUrls.first,
                    width: 130,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.priceFormatted,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A5C40),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estado: ${product.status}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A9990),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onEdit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            'Editar',
                            style: TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onDelete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            'Eliminar',
                            style: TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 130,
      height: 130,
      color: const Color(0xFFE8F5EE),
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF2D9E6B),
        size: 40,
      ),
    );
  }
}
