import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import '../services/cupo_service.dart';
import '../services/rating_service.dart';
import '../screens/solicitar_cupo_screen.dart';
import '../screens/calificar_screen.dart';

class RouteCard extends StatefulWidget {
  final RouteModel route;
  final VoidCallback onTap;
  final VoidCallback? onRefreshRejected;

  const RouteCard({
    super.key,
    required this.route,
    required this.onTap,
    this.onRefreshRejected,
  });

  @override
  State<RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  bool _finalizing = false;
  Future<String>? _requestStatusFuture;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  void _loadStatus() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && !_isDriver) {
      _requestStatusFuture = CupoService().getRequestStatus(
        uid,
        widget.route.id,
      );
    }
  }

  bool get _isDriver =>
      FirebaseAuth.instance.currentUser?.uid == widget.route.driverId;
  bool get _isFinalized => widget.route.status == RouteStatus.finalizada;
  bool get _isFull => widget.route.isFull;
  bool get _canDriverFinalize => _isDriver && !_isFinalized;

  Future<void> _handleFinalize() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Finalizar ruta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Confirmas que esta ruta ya terminó? Se notificará a los pasajeros para que califiquen.',
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
              backgroundColor: AppColors.accentGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Finalizar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _finalizing = true);
    final result = await RouteService().finalizeRoute(widget.route.id);
    if (!mounted) return;
    setState(() => _finalizing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'ok'
              ? '✅ Ruta finalizada. Se notificó a los pasajeros.'
              : result,
        ),
        backgroundColor: result == 'ok'
            ? const Color(0xFF1A5C40)
            : Colors.redAccent,
      ),
    );
  }

  void _handleRequestSeat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SolicitarCupoScreen(route: widget.route),
      ),
    ).then((_) {
      // Recargar estado y rutas rechazadas al volver
      setState(() => _loadStatus());
      widget.onRefreshRejected?.call();
    });
  }

  Widget _buildStatusBadge() {
    String label;
    Color bgColor;
    Color textColor;

    if (_isFinalized) {
      label = 'FINALIZADA';
      bgColor = Colors.red.shade400;
      textColor = Colors.white;
    } else if (_isDriver) {
      label = widget.route.status.toUpperCase();
      bgColor = AppColors.accentGreen;
      textColor = Colors.white;
    } else if (_isFull) {
      label = 'LLENA';
      bgColor = Colors.orange.shade600;
      textColor = Colors.white;
    } else {
      label = 'DISPONIBLE';
      bgColor = AppColors.accentGreen.withOpacity(0.15);
      textColor = AppColors.accentGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBadge(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${widget.route.origin} → ${widget.route.destination}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (!_isFinalized)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isFull
                          ? Colors.red.withOpacity(0.1)
                          : AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isFull
                          ? 'Lleno'
                          : '${widget.route.availableSeats} Cupos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isFull ? Colors.red : AppColors.accentGreen,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _isFinalized
                  ? '${widget.route.date} · ${widget.route.time}'
                  : '${widget.route.date} · ${widget.route.time} · ${widget.route.priceFormatted}',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.accentGreen,
                      child: Text(
                        widget.route.driverInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isDriver
                          ? '${widget.route.driverName} (tú)'
                          : widget.route.driverName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundApp,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⭐ ${widget.route.driverRating}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── CONDUCTOR: Finalizar ───────────────────────
            if (_canDriverFinalize)
              SizedBox(
                width: double.infinity,
                height: 36,
                child: _finalizing
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentGreen,
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _handleFinalize,
                        icon: const Icon(
                          Icons.flag_rounded,
                          size: 16,
                          color: AppColors.accentGreen,
                        ),
                        label: const Text(
                          'Finalizar ruta',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentGreen,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.accentGreen,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
              )
            // ── PASAJERO: según estado de solicitud ────────
            else if (!_isDriver && !_isFinalized)
              FutureBuilder<String>(
                future: _requestStatusFuture,
                builder: (context, snapshot) {
                  final status = snapshot.data ?? '';
                  final loading =
                      snapshot.connectionState == ConnectionState.waiting;

                  // Cupo confirmado
                  if (status == 'accepted') {
                    return Container(
                      width: double.infinity,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accentGreen,
                          width: 1.5,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.accentGreen,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Cupo confirmado',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentGreen,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Solicitud pendiente
                  if (status == 'pending') {
                    return SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.grey,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Solicitud enviada',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }

                  // Sin cupos
                  if (_isFull) {
                    return SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.grey,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Sin cupos disponibles',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }

                  // Disponible para solicitar
                  return SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: loading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: _handleRequestSeat,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.accentGreen,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Solicitar cupo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentGreen,
                              ),
                            ),
                          ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
