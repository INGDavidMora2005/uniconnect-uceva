import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../services/product_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'editar_producto_screen.dart';
import 'calificar_bazar_screen.dart';

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
                  // ── UU-20 ──────────────────────────────────
                  onToggleStatus: () => _confirmToggleStatus(products[i]),
                  onCalificar: () => _goToCalificar(products[i]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── UU-20: Confirmar cambio de estado ────────────────────────────────────
  Future<void> _confirmToggleStatus(ProductModel product) async {
    final isAvailable = product.status == 'Disponible';
    final actionLabel = isAvailable ? 'Marcar como vendido' : 'Volver a publicar';
    final confirmMsg = isAvailable
        ? '¿Marcar este producto como vendido? Dejará de aparecer en el Bazar.'
        : '¿Volver a publicar este producto? Reaparecerá en el Bazar como disponible.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(actionLabel),
        content: Text(confirmMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  isAvailable ? AppColors.primaryGreen : AppColors.accentGreen,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newStatus = isAvailable ? 'Vendido' : 'Disponible';
    final result =
        await ProductService().updateProductStatus(product.id, newStatus);

    if (!mounted) return;

    if (result == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAvailable
                ? 'Producto marcado como vendido'
                : 'Producto publicado nuevamente',
          ),
          backgroundColor: AppColors.accentGreen,
        ),
      );

      // ── Si se marcó como vendido → ofrecer calificar al comprador (UU-21)
      if (isAvailable && mounted) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _ofrecerCalificar(product);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.redAccent),
      );
    }
  }

  // ── UU-20: Ofrecer calificación al cerrar transacción ───────────────────
  Future<void> _ofrecerCalificar(ProductModel product) async {
    final calificar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¡Transacción cerrada!'),
        content: const Text(
          '¿Deseas calificar al comprador ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Después'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.accentGreen),
            child: const Text('Calificar'),
          ),
        ],
      ),
    );

    if (calificar == true && mounted) {
      _goToCalificar(product);
    }
  }

  // ── UU-20 → UU-21: Navegar a calificación de bazar ──────────────────────
  Future<void> _goToCalificar(ProductModel product) async {
    // Simulamos al comprador como el usuario actual para la demo;
    // en producción aquí se pasaría el UserModel real del comprador
    // obtenido de la colección de transacciones/solicitudes.
    final currentUser = await AuthService().getUserData();
    if (!mounted || currentUser == null) return;

    // Construcción del UserModel del comprador.
    // NOTA: cuando exista la colección de transacciones, reemplazar
    // esto por la consulta real del comprador de este producto.
    final buyerPlaceholder = UserModel(
      id: '',
      fullName: 'Comprador desconocido',
      email: '',
      studentCode: '',
      role: '',
      faculty: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalificarBazarScreen(
          product: product,
          ratedUser: buyerPlaceholder,
          currentUserRole: 'vendedor',
        ),
      ),
    );
  }

  // ── Confirmar eliminación ────────────────────────────────────────────────
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

// ── Widget de tarjeta de producto ───────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;
  final VoidCallback onCalificar;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
    required this.onCalificar,
  });

  bool get _isVendido => product.status == 'Vendido';

  @override
  Widget build(BuildContext context) {
    return Container(
      // Altura un poco mayor para acomodar los botones extra
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
          // ── Imagen ─────────────────────────────────────────────────────
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: product.imageUrls.isNotEmpty
                    ? Image.network(
                        product.imageUrls.first,
                        width: 110,
                        height: 155,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              // Badge de estado encima de la imagen
              if (_isVendido)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF085041),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Vendido',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Contenido ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
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
                  // Chip de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isVendido
                          ? const Color(0xFFE8F5EE)
                          : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isVendido
                            ? AppColors.primaryGreen
                            : const Color(0xFF856900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Fila 1: Editar + Eliminar ───────────────────────────
                  Row(
                    children: [
                      // Editar solo si está disponible
                      if (!_isVendido) ...[
                        Expanded(
                          child: _SmallButton(
                            label: 'Editar',
                            color: AppColors.accentGreen,
                            onPressed: onEdit,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: _SmallButton(
                          label: 'Eliminar',
                          color: Colors.redAccent,
                          onPressed: onDelete,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // ── Fila 2: Marcar vendido / Volver a publicar ──────────
                  SizedBox(
                    width: double.infinity,
                    child: _SmallButton(
                      label: _isVendido
                          ? 'Volver a publicar'
                          : 'Marcar como vendido',
                      color: _isVendido
                          ? AppColors.accentGreen
                          : AppColors.primaryGreen,
                      onPressed: onToggleStatus,
                    ),
                  ),

                  // ── Fila 3: Calificar (solo si está vendido) ────────────
                  if (_isVendido) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: _SmallButton(
                        label: '⭐ Calificar comprador',
                        color: const Color(0xFF856900),
                        onPressed: onCalificar,
                      ),
                    ),
                  ],
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
      width: 110,
      height: 155,
      color: const Color(0xFFE8F5EE),
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF2D9E6B),
        size: 36,
      ),
    );
  }
}

// ── Botón pequeño reutilizable ───────────────────────────────────────────────
class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _SmallButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10.5, color: Colors.white),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}