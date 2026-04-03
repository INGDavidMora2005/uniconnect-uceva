import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import 'publicar_producto_screen.dart';
import 'detalle_producto_screen.dart';

class BazarScreen extends StatefulWidget {
  const BazarScreen({super.key});

  @override
  State<BazarScreen> createState() => _BazarScreenState();
}

class _BazarScreenState extends State<BazarScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  List<ProductModel> _applySearch(List<ProductModel> products) {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return products;
    return products.where((p) =>
        p.name.toLowerCase().contains(query) ||
        p.description.toLowerCase().contains(query)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.primaryGreen,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bazar UCEVA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '¿Qué necesitas?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentGreen,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar libros, calculadoras...',
                          hintStyle: const TextStyle(
                              color: AppColors.textPlaceholder, fontSize: 13),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close,
                                      color: AppColors.textPlaceholder),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.search, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Publicaciones recientes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Ver todas',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<ProductModel>>(
                  stream: ProductService().getProducts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(
                              color: AppColors.accentGreen),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      );
                    }

                    final products = _applySearch(snapshot.data ?? []);

                    if (products.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.storefront_outlined,
                                  size: 48, color: AppColors.borderDefault),
                              SizedBox(height: 12),
                              Text(
                                'No hay productos disponibles',
                                style: TextStyle(
                                    color: AppColors.textLight, fontSize: 14),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '¡Se el primero en publicar!',
                                style: TextStyle(
                                    color: AppColors.textPlaceholder,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, i) => _ProductCard(
                        product: products[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetalleProductoScreen(product: products[i]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PublicarProductoScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Publicar Producto',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _initials {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: product.imageUrls.isNotEmpty
                  ? Image.network(
                      product.imageUrls.first,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A9990),
                          ),
                        ),
                      ),
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 13),
                      const SizedBox(width: 2),
                      Text(
                        '${product.sellerRating}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 110,
      width: double.infinity,
      color: const Color(0xFFE8F5EE),
      child: const Icon(Icons.image_outlined,
          color: Color(0xFF2D9E6B), size: 36),
    );
  }
}