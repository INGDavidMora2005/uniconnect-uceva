import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';

class SolicitarCupoScreen extends StatefulWidget {
  final RouteModel route;

  const SolicitarCupoScreen({super.key, required this.route});

  @override
  State<SolicitarCupoScreen> createState() => _SolicitarCupoScreenState();
}

class _SolicitarCupoScreenState extends State<SolicitarCupoScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _loading = false;

  // Verde del AppBar / header
  static const Color _appBarGreen = Color(0xFF1A5C40);
  // Verde de la tarjeta — más claro que el AppBar
  static const Color _headerGreen = Color(0xFF256B4A);
  // Verde medio para el avatar
  static const Color _avatarGreen = Color(0xFF2D9E6B);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final result = await RouteService().requestSeat(
      routeId: widget.route.id,
      passengerId: uid,
      message: _messageController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result == 'ok') {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                '¡Solicitud enviada!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'El conductor recibirá tu solicitud y te notificaremos cuando responda.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F1),
        appBar: AppBar(
          backgroundColor: _appBarGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          title: const Text(
            'Solicitar cupo',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Tarjeta resumen de la ruta ─────────────────
              // Figma: Rectangle 19 — 353×140px, mismos chips y conductor
              Container(
                width: double.infinity,
                // Altura mínima alineada con Figma (140px del Rectangle 19)
                constraints: const BoxConstraints(minHeight: 140),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _headerGreen,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${route.origin} → ${route.destination}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Chips: Hoy · hora · cupos  (Figma: Frame 10, 3 Rectangle outline)
                    Row(
                      children: [
                        _chip('Hoy'),
                        const SizedBox(width: 8),
                        _chip(route.time),
                        const SizedBox(width: 8),
                        _chip(
                          '${route.availableSeats} '
                          '${route.availableSeats == 1 ? 'Cupo' : 'Cupos'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Conductor: avatar + nombre + rating (Figma: Frame 9)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _avatarGreen,
                          child: Text(
                            route.driverInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            route.driverName,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${route.driverRating}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Detalles del viaje ──────────────────────────
              // Figma: Rectangle 24 — 353×150px
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8EDE9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DETALLES DEL VIAJE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFAFB8B3),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _detailRow(
                      'Punto de encuentro',
                      route.meetingPoint,
                      valueColor: const Color(0xFF1A1A1A),
                      bold: true,
                    ),
                    const Divider(height: 22, color: Color(0xFFF0F0F0)),
                    _detailRow(
                      'Aporte por pasajero',
                      route.priceFormatted,
                      valueColor: const Color(0xFF2D9E6B),
                      bold: true,
                    ),
                    const Divider(height: 22, color: Color(0xFFF0F0F0)),
                    _detailRow(
                      'Cupos disponibles',
                      '${route.availableSeats} - ${route.totalSeats}',
                      valueColor: const Color(0xFF2D9E6B),
                      bold: true,
                    ),
                    if (route.note != null && route.note!.isNotEmpty) ...[
                      const Divider(height: 22, color: Color(0xFFF0F0F0)),
                      _detailRow('Nota', route.note!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Mensaje opcional ────────────────────────────
              // Figma: label texto + Rectangle 23 (72px alto)
              const Text(
                'Mensaje para el conductor (Opcional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 72, // Alineado con Figma: Rectangle 23 = 72px
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E5E2)),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ej: Estaré puntual, voy con maleta pequeña...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFBFC8C3),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Aviso info ──────────────────────────────────
              // Figma: Rectangle 29 — 353×100px, ícono ℹ️ emoji, texto a la derecha
              Container(
                height: 100, // Alineado con Figma: Rectangle 29 = 100px
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Figma usa el emoji ℹ️, no un ícono de Material
                    const Text('ℹ️', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'El conductor recibirá tu solicitud y deberá aceptarla. Te notificaremos cuando responda.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF4A6558),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Botón confirmar ─────────────────────────────
              // Figma: Rectangle 27 — 353×48px
              SizedBox(
                width: double.infinity,
                height: 48, // Figma: 48px (era 52px en el código anterior)
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D9E6B),
                    disabledBackgroundColor:
                        const Color(0xFF2D9E6B).withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                          'Confirmar solicitud',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Cancelar ────────────────────────────────────
              // Figma: Rectangle 12 — botón con fondo (outline), 353×48px
              SizedBox(
                width: double.infinity,
                height: 48, // Figma: 48px
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF2D9E6B),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D9E6B),
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

  // ── Helpers ────────────────────────────────────────────────

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.55),
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color valueColor = const Color(0xFF6B7C74),
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF8A9990),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}