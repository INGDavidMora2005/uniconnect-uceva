import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../models/product_model.dart';
import '../models/report_model.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../services/user_history_service.dart';
import 'chat_screen.dart';
import 'perfil_vendedor_screen.dart';
import 'report_form_screen.dart';

class DetalleProductoScreen extends StatefulWidget {
  final ProductModel product;

  const DetalleProductoScreen({super.key, required this.product});

  @override
  State<DetalleProductoScreen> createState() => _DetalleProductoScreenState();
}

class _DetalleProductoScreenState extends State<DetalleProductoScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isOwner => _uid == widget.product.sellerId;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid != null) {
      unawaited(UserHistoryService().logProductView(uid, widget.product));
    }
  }

  Future<void> _handleContact(BuildContext context) async {
    try {
      // Obtener el número del vendedor directamente desde Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.product.sellerId)
          .get();

      if (!userDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo encontrar la información del vendedor'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Descifrar el teléfono si está encriptado
      final rawPhone = userDoc.data()?['phone'];
      String userPhone = '';

      if (rawPhone is Map<String, dynamic>) {
        // Formato encriptado legacy (usuarios registrados antes del cambio)
        // No se puede descifrar desde otro dispositivo, pedir al usuario que actualice su perfil
        userPhone = '';
      } else {
        userPhone = rawPhone?.toString() ?? '';
      }
      final phone = userPhone.replaceAll(RegExp(r'\D'), '');

      if (phone.isEmpty) {
        if (context.mounted) {
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

      final fullPhone = phone.startsWith('57') ? phone : '57$phone';
      final message = Uri.encodeComponent(
        '¡Hola! Vi tu publicación de "${widget.product.name}" en UniConnect y me interesa. ¿Sigue disponible?',
      );
      final waUri = Uri.parse('https://wa.me/$fullPhone?text=$message');
      bool launched = false;
      if (await canLaunchUrl(waUri)) {
        launched = await launchUrl(waUri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        launched = await launchUrl(waUri, mode: LaunchMode.inAppBrowserView);
      }

      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo abrir WhatsApp. Asegúrate de tenerlo instalado.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al contactar al vendedor: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleSendMessage(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Verificar si ya existe chat de ruta con el vendedor
    String? routeChatId;
    final snap1 = await FirebaseFirestore.instance
        .collection('chats')
        .where('driverId', isEqualTo: widget.product.sellerId)
        .where('passengerId', isEqualTo: currentUserId)
        .limit(1)
        .get();
    if (snap1.docs.isNotEmpty) {
      routeChatId = snap1.docs.first.id;
    } else {
      final snap2 = await FirebaseFirestore.instance
          .collection('chats')
          .where('driverId', isEqualTo: currentUserId)
          .where('passengerId', isEqualTo: widget.product.sellerId)
          .limit(1)
          .get();
      if (snap2.docs.isNotEmpty) routeChatId = snap2.docs.first.id;
    }

    final String finalChatId;
    final String finalCollection;
    final bool finalIsDirect;

    if (routeChatId != null) {
      finalChatId = routeChatId;
      finalCollection = 'chats';
      finalIsDirect = false;
    } else {
      // Obtener nombre del usuario actual
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final currentUserName = userDoc.data()?['fullName'] ?? '';

      final directChatId = await ChatService().getOrCreateDirectChat(
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        otherUserId: widget.product.sellerId,
        otherUserName: widget.product.sellerName,
      );

      if (directChatId.startsWith('error:')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al abrir chat: $directChatId'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      finalChatId = directChatId;
      finalCollection = 'direct_chats';
      finalIsDirect = true;
    }

    if (!context.mounted) return;

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: finalChatId,
          otherUserName: widget.product.sellerName,
          otherUserId: widget.product.sellerId,
          routeInfo: '',
          isDirectChat: finalIsDirect,
          collectionName: finalCollection,
          initialMessage: '¡Hola! Estoy interesado en tu producto "${widget.product.name}". ¿Sigue disponible?',
        ),
      ),
    );
  }

  void _handleReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportFormScreen(
          type: ReportType.publication,
          targetId: widget.product.id,
          targetName: widget.product.name,
        ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar producto',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: const Text(
          '¿Confirmas que deseas eliminar esta publicación? Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 13, color: AppColors.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textLight),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await ProductService().deleteProduct(widget.product.id);
    if (context.mounted) Navigator.pop(context);
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
            'Detalle del producto',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen
              widget.product.imageUrls.isNotEmpty
                  ? Image.network(
                      widget.product.imageUrls.first,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.product.status == 'Vendido'
                                ? Colors.red.shade50
                                : const Color(0xFFE8F5EE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.product.status == 'Vendido'
                                ? 'No disponible'
                                : 'Disponible',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.product.status == 'Vendido'
                                  ? Colors.redAccent
                                  : AppColors.accentGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.product.priceFormatted,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A5C40),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tags categoría
                    Wrap(
                      spacing: 8,
                      children: [
                        _tag(widget.product.category),
                        if (widget.product.contactMethod.isNotEmpty)
                          _tag(widget.product.contactMethod),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Vendedor (tappable → perfil)
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PerfilVendedorScreen(
                            sellerId: widget.product.sellerId,
                            sellerName: widget.product.sellerName,
                            sellerInitials: widget.product.sellerInitials,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8EDE9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'VENDEDOR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFAFB8B3),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: AppColors.textLight,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.accentGreen,
                                  child: Text(
                                    widget.product.sellerInitials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.product.sellerName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      if (widget
                                          .product
                                          .sellerCareer
                                          .isNotEmpty)
                                        Text(
                                          widget.product.sellerCareer,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF8A9990),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.product.sellerRating}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Descripción
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EDE9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DESCRIPCION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFAFB8B3),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.product.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4A6558),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botones — se muestran según el método de contacto elegido
                    if (!_isOwner) ...[
                      // Chat app
                      if (widget.product.contactMethod == 'Chat app' ||
                          widget.product.contactMethod == 'Ambos') ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleSendMessage(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              'Contactar vendedor',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // WhatsApp
                      if (widget.product.contactMethod == 'Whatsapp' ||
                          widget.product.contactMethod == 'Ambos' ||
                          widget.product.contactMethod.isEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleContact(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                              ],
                            ),
                            label: const Text(
                              'Contactar por WhatsApp',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleReport(context),
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text(
                            'Reportar publicación',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleDelete(context),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          label: const Text(
                            'Eliminar publicación',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5EE),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.accentGreen,
      ),
    ),
  );

  Widget _imagePlaceholder() => Container(
    width: double.infinity,
    height: 220,
    color: const Color(0xFFE8F5EE),
    child: const Icon(
      Icons.image_outlined,
      color: AppColors.accentGreen,
      size: 56,
    ),
  );
}