import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/rating_model.dart';
import '../models/route_model.dart';
import '../services/rating_service.dart';
import '../services/auth_service.dart';
import '../widgets/primary_button.dart';

class CalificarScreen extends StatefulWidget {
  final RouteModel route;

  const CalificarScreen({super.key, required this.route});

  @override
  State<CalificarScreen> createState() => _CalificarScreenState();
}

class _CalificarScreenState extends State<CalificarScreen> {
  double _stars = 0;
  final List<String> _selectedTags = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  // Etiquetas rápidas del Figma
  final List<Map<String, String>> _tags = [
    {'emoji': '👍', 'label': 'Puntual'},
    {'emoji': '💬', 'label': 'Buen trato'},
    {'emoji': '🚗', 'label': 'Conducción segura'},
    {'emoji': '📍', 'label': 'Ruta correcta'},
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

  void _handleSubmit() async {
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
      final user = await AuthService().getUserData();
      if (user == null || AuthService().currentUser == null) {
        _showError('No se pudo obtener tu información');
        setState(() => _isLoading = false);
        return;
      }

      final parts = user.fullName.trim().split(' ');
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : parts[0][0].toUpperCase();

      final rating = RatingModel(
        id:               '',
        routeId:          widget.route.id,
        raterId:          AuthService().currentUser!.uid,
        raterName:        user.fullName,
        raterInitials:    initials,
        ratedUserId:      widget.route.driverId ?? '',
        stars:            _stars,
        tags:             _selectedTags,
        comment:          _commentController.text.trim(),
        routeDescription:
            '${widget.route.origin} → ${widget.route.destination} · ${widget.route.date} ${widget.route.time}',
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
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header verde oscuro ──────────────────────────
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
                    'Calificar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // ── Contenido ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Pregunta
                    const Text(
                      '¿Cómo fue tu experiencia?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.route.origin} → ${widget.route.destination} · ${widget.route.date} ${widget.route.time}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Card del conductor ───────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Avatar conductor
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.accentGreen,
                            child: Text(
                              widget.route.driverInitials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.route.driverName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Conductor',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Estrellas ────────────────────────
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
                                      horizontal: 6),
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

                    // ── Etiquetas rápidas ────────────────────
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
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accentGreen.withOpacity(0.1)
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

                    // ── Comentario ───────────────────────────
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
                                'Describe tu experiencia con este conductor',
                            filled: true,
                            fillColor: AppColors.backgroundWhite,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppColors.borderDefault),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppColors.borderDefault),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppColors.accentGreen, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Botón Enviar ─────────────────────────
                    PrimaryButton(
                      text: 'Enviar calificación',
                      onPressed: _handleSubmit,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 12),

                    // ── Omitir ───────────────────────────────
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