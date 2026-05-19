import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../models/report_model.dart';
import '../services/product_service.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'detalle_producto_screen.dart';
import 'calificar_bazar_screen.dart';
import 'report_form_screen.dart';

class PerfilVendedorScreen extends StatefulWidget {
  final String sellerId;
  final String sellerName;
  final String sellerInitials;
  final String? sellerImageUrl;

  const PerfilVendedorScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.sellerInitials,
    this.sellerImageUrl,
  });

  @override
  State<PerfilVendedorScreen> createState() => _PerfilVendedorScreenState();
}

class _PerfilVendedorScreenState extends State<PerfilVendedorScreen> {
  final ProductService _productService = ProductService();
  final ChatService _chatService = ChatService();

  Future<void> _enviarMensaje() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Usuario no autenticado'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (currentUserId == widget.sellerId) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    final currentUserName = doc.data()?['fullName'] ?? '';

    final chatId = await _chatService.getOrCreateDirectChat(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      otherUserId: widget.sellerId,
      otherUserName: widget.sellerName,
    );

    if (!mounted) return;

    if (chatId.startsWith('error:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear chat: $chatId'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserName: widget.sellerName,
          otherUserId: widget.sellerId,
          routeInfo: 'Chat directo',
          isDirectChat: true,
          collectionName: 'direct_chats',
        ),
      ),
    );
  }

  Future<void> _calificarVendedor() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final alreadyRated = await FirebaseFirestore.instance
        .collection('ratings')
        .where('raterId', isEqualTo: currentUserId)
        .where('ratedUserId', isEqualTo: widget.sellerId)
        .where('ratingType', isEqualTo: 'bazar')
        .get();

    if (alreadyRated.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya has calificado a este vendedor'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final productos = await _productService.getMyProductsOnce(widget.sellerId);
    final productosDisponibles = productos
        .where((p) => p.status == 'Disponible' || p.status == 'Vendido')
        .toList();

    ProductModel productoAUsar;
    if (productosDisponibles.isNotEmpty) {
      productoAUsar = productosDisponibles.first;
    } else {
      productoAUsar = ProductModel(
        id: '',
        name: 'Producto',
        description: '',
        price: 0,
        sellerId: widget.sellerId,
        sellerName: widget.sellerName,
        sellerInitials: widget.sellerInitials,
        imageUrls: [],
        category: '',
        status: 'Vendido',
        createdAt: DateTime.now(),
        sellerRating: 0.0,
        sellerCareer: '',
        contactMethod: 'Whatsapp',
      );
    }

    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CalificarBazarScreen(
          product: productoAUsar,
          ratedUser: UserModel(
            id: widget.sellerId,
            fullName: widget.sellerName,
            email: '',
            studentCode: '',
            role: '',
            faculty: '',
          ),
          currentUserRole: 'comprador',
        ),
      ),
    );

    if (mounted && result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por tu calificación!'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
      setState(() {});
    }
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
          'Perfil del vendedor',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.sellerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGreen),
            );
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text('Error cargando información del vendedor'),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          // Obtener el teléfono - intentar usar getUserData para obtener descifrado
          final rawPhoneVendedor = data['phone'];
          final phone = rawPhoneVendedor is Map
              ? ''
              : (rawPhoneVendedor?.toString() ?? '');
          final faculty = (data['faculty'] ?? '').toString();
          final rating = (data['rating'] ?? 0.0).toDouble();
          final trips = (data['tripsCompleted'] ?? 0) as int;
          final ventasCount = (data['bazarSales'] ?? 0) as int;

          return StreamBuilder<List<ProductModel>>(
            stream: _productService.getMyProducts(widget.sellerId),
            builder: (context, productsSnapshot) {
              final products = productsSnapshot.data ?? [];
              final ventasCompletadas = products
                  .where((p) => p.status == 'Vendido')
                  .toList();
              final catalogoActivo = products
                  .where((p) => p.status == 'Disponible')
                  .toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.accentGreen,
                            backgroundImage: widget.sellerImageUrl != null
                                ? NetworkImage(widget.sellerImageUrl!)
                                : null,
                            child: widget.sellerImageUrl == null
                                ? Text(
                                    widget.sellerInitials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.sellerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          if (faculty.isNotEmpty)
                            Text(
                              faculty,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatChip(
                                icon: Icons.star_rounded,
                                label: '${rating.toStringAsFixed(1)}',
                              ),
                              const SizedBox(width: 12),
                              _buildStatChip(
                                icon: Icons.directions_car_rounded,
                                label: '$trips viajes',
                              ),
                              const SizedBox(width: 12),
                              _buildStatChip(
                                icon: Icons.shopping_bag_outlined,
                                label: '$ventasCount ventas',
                              ),
                            ],
                          ),
const SizedBox(height: 12),
                           if (FirebaseAuth.instance.currentUser?.uid != widget.sellerId)
                             ElevatedButton.icon(
                               onPressed: _enviarMensaje,
                               icon: const Icon(Icons.chat_bubble_outline, size: 18),
                               label: const Text('Enviar mensaje'),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: AppColors.primaryGreen,
                                 foregroundColor: Colors.white,
                                 shape: RoundedRectangleBorder(
                                   borderRadius: BorderRadius.circular(10),
                                 ),
                                 elevation: 0,
                               ),
                             ),
                           if (rawPhoneVendedor != null)
                             ElevatedButton.icon(
                              onPressed: () =>
                                  _contactarVendedor(rawPhoneVendedor),
                              icon: const Icon(Icons.message, size: 18),
                              label: const Text('Contactar por WhatsApp'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _calificarVendedor,
                            icon: const Icon(
                              Icons.rate_review_outlined,
                              size: 18,
                            ),
                            label: const Text('Calificar vendedor'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportFormScreen(
                                  type: ReportType.user,
                                  targetId: widget.sellerId,
                                  targetName: widget.sellerName,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: const Text('Reportar usuario'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                      'Catálogo activo',
                      Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(height: 10),
                    if (catalogoActivo.isEmpty)
                      _buildEmptyState(
                        icon: Icons.inbox_rounded,
                        message: 'No hay productos disponibles',
                      )
                    else
                      _buildProductGrid(catalogoActivo),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'Ventas completadas',
                      Icons.check_circle_outline,
                    ),
                    const SizedBox(height: 10),
                    if (ventasCompletadas.isEmpty)
                      _buildEmptyState(
                        icon: Icons.inbox_rounded,
                        message: 'No hay ventas registradas',
                      )
                    else
                      _buildProductGrid(ventasCompletadas),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textLight),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.borderDefault),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<ProductModel> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final product = products[i];
        return _ProductGridItem(
          product: product,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleProductoScreen(product: product),
            ),
          ),
        );
      },
    );
  }

  Future<void> _contactarVendedor(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El vendedor no tiene número de WhatsApp registrado',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final fullPhone = cleanPhone.startsWith('57')
          ? cleanPhone
          : '57$cleanPhone';
      final message = Uri.encodeComponent(
        '¡Hola! Vi tu perfil en UniConnect y me interesa. ¿Estás disponible?',
      );
      final waUri = Uri.parse('https://wa.me/$fullPhone?text=$message');
      bool launched = false;
      if (await canLaunchUrl(waUri)) {
        launched = await launchUrl(waUri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        launched = await launchUrl(waUri, mode: LaunchMode.inAppBrowserView);
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir WhatsApp. Asegúrate de tenerlo instalado.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al contactar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

class _ProductGridItem extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductGridItem({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.imageUrls.isNotEmpty
                        ? Image.network(
                            product.imageUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                    if (product.status == 'Vendido')
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                'VENDIDO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.priceFormatted,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A5C40),
                    ),
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
      color: const Color(0xFFE8F5EE),
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF2D9E6B),
        size: 36,
      ),
    );
  }
}
