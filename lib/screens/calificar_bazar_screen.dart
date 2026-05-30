import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/product_model.dart';
import '../models/rating_model.dart';
import '../models/user_model.dart';
import '../services/rating_service.dart';
import '../services/auth_service.dart';
import '../widgets/primary_button.dart';

/// Pantalla de calificación mutua entre comprador y vendedor
/// al cerrar una transacción del bazar (UU-20 → habilita UU-21).
class CalificarBazarScreen extends StatefulWidget {
  /// Producto que fue vendido
  final ProductModel product;

  /// Datos del usuario a calificar (el otro lado de la transacción).
  /// Si el vendedor califica → [ratedUser] es el comprador.
  /// Si el comprador califica → [ratedUser] es el vendedor.
  final UserModel ratedUser;

  /// Rol del usuario actual en la transacción ('vendedor' o 'comprador')
  final String currentUserRole;

  const CalificarBazarScreen({
    super.key,
    required this.product,
    required this.ratedUser,
    required this.currentUserRole,
  });

  @override
  State<CalificarBazarScreen> createState() => _CalificarBazarScreenState();
}

class _CalificarBazarScreenState extends State<CalificarBazarScreen> {
  double _stars = 0;
  final List<String> _selectedTags = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, String>> _tags = [
    {'emoji': '👍', 'label': 'Buen trato'},
    {'emoji': '✅', 'label': 'Como descrito'},
    {'emoji': '⚡', 'label': 'Entrega rápida'},
    {'emoji': '💬', 'label': 'Buena comunicación'},
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una calificación'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = await AuthService().getUserData();
      if (currentUser == null || AuthService().currentUser == null) {
        _showError('No se pudo obtener tu información');
        setState(() => _isLoading = false);
        return;
      }

      final parts = currentUser.fullName.trim().split(' ');
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : parts[0][0].toUpperCase();

      final rating = RatingModel(
        id: '',
        routeId: '',
        raterId: AuthService().currentUser!.uid,
        raterName: currentUser.fullName,
        raterInitials: initials,
        ratedUserId: widget.ratedUser.id,
        stars: _stars,
        tags: _selectedTags,
        comment: _commentController.text.trim(),
        routeDescription:
            'Transacción: ${widget.product.name} · ${widget.currentUserRole}',
        ratingType: 'bazar',
        productId: widget.product.id,
        productName: widget.product.name,
      );

      final result = await RatingService().submitRating(rating);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result == 'Calificación enviada exitosamente.') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Calificación enviada!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showError(result);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: ${e.toString()}');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.ratedUser.fullName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();

    final otherRole = widget.currentUserRole == 'vendedor'
        ? 'Comprador'
        : 'Vendedor';

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              color: AppColors.primaryGreen,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Calificar transacción',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // ── Contenido ────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      '¿Cómo fue la transacción?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.product.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Card del usuario a calificar ─────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.accentGreen,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.ratedUser.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            otherRole,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Mensaje introductorio mejorado
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha:0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryGreen.withValues(alpha:0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.rate_review_outlined,
                                      size: 20,
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '¿Cómo fue el trato con el vendedor?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Califica su servicio y cuéntanos si el producto llegó según lo acordado.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMedium,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Estrellas ───────────────────────────────────────
                          Text(
                            _stars == 0
                                ? 'Toca para calificar'
                                : '${_stars.toInt()} de 5 estrellas',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _stars = (i + 1).toDouble()),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Icon(
                                    i < _stars
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 42,
                                    color: i < _stars
                                        ? const Color(0xFFFFB800)
                                        : AppColors.borderDefault,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Etiquetas rápidas ────────────────────────────────────
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: _tags.map((tag) {
                        final label = tag['label']!;
                        final emoji = tag['emoji']!;
                        final selected = _selectedTags.contains(label);
                        return GestureDetector(
                          onTap: () => _toggleTag(label),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accentGreen.withValues(alpha:0.1)
                                  : AppColors.backgroundWhite,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accentGreen
                                    : AppColors.borderDefault,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              '$emoji $label',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? AppColors.accentGreen
                                    : AppColors.textMedium,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── Comentario ───────────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comentario (Opcional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _commentController,
                          maxLines: 3,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Describe tu experiencia en la transacción',
                            filled: true,
                            fillColor: AppColors.backgroundWhite,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.borderDefault,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.borderDefault,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.accentGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Botón Enviar ─────────────────────────────────────────
                    PrimaryButton(
                      text: 'Enviar calificación',
                      onPressed: _handleSubmit,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 12),

                    // ── Omitir ───────────────────────────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Omitir por ahora',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
