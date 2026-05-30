import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/route_model.dart';
import '../models/report_model.dart';
import '../services/route_service.dart';
import '../services/cupo_service.dart';
import '../services/location_service.dart';
import '../screens/solicitar_cupo_screen.dart';
import '../screens/mapa_trayecto_screen.dart';
import '../screens/route_details_screen.dart';
import '../screens/report_form_screen.dart';
import '../screens/editar_ruta_screen.dart';

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
  bool _starting = false;
  Future<String>? _requestStatusFuture;
  bool _isSharingLocation = false;
  bool _isDriver = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _isDriver = uid == widget.route.driverId;
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

  Future<void> _startPassengerSharing() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = (userDoc.data()?['fullName'] as String?) ?? 'Pasajero';
      final parts = name.trim().split(' ');
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : (parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'P');

      await LocationService().startSharingPassengerLocation(
        routeId: widget.route.id,
        passengerId: uid,
        passengerName: name,
        passengerInitials: initials,
      );
      _isSharingLocation = true;
    } catch (_) {
      // Manejar error silenciosamente o mostrar snackbar si es necesario
    }
  }

  Future<void> _stopPassengerSharing() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await LocationService().stopSharingPassengerLocation(
        routeId: widget.route.id,
        passengerId: uid,
      );
      _isSharingLocation = false;
    }
  }

  bool get _isFinalized => widget.route.status == RouteStatus.finalizada;
  bool get _isFull => widget.route.isFull;

  // ════════════════════════════════════════════════════════════════════
  // DIÁLOGOS
  // ════════════════════════════════════════════════════════════════════

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
          '¿Confirmas que esta ruta ya terminó? Se notificará a los '
          'pasajeros para que califiquen.',
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
    await LocationService().stopSharingLocation(widget.route.id);
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

  Future<void> _handleStartRoute() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Iniciar ruta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Confirmas que la ruta ya comenzó? Los pasajeros podrán '
          'ver tu ubicación en tiempo real.',
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
            child: const Text('Iniciar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _starting = true);
    final result = await RouteService().startRoute(widget.route.id);
    if (result == 'ok') {
      await LocationService().startSharingLocation(widget.route.id);
    }
    if (!mounted) return;
    setState(() => _starting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'ok'
              ? '✅ Ruta iniciada. Los pasajeros pueden ver el mapa en vivo.'
              : result,
        ),
        backgroundColor: result == 'ok'
            ? const Color(0xFF1A5C40)
            : Colors.redAccent,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // CAMBIO 3 — BOTÓN UNIFICADO "VER TRAYECTO EN VIVO"
  // ═════════════════════════════════════════════════��══════════════════

  Widget _buildLiveMapButton({required bool isDriver}) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MapaTrayectoScreen(route: widget.route, isDriver: isDriver),
          ),
        ),
        icon: const Icon(
          Icons.map_outlined,
          size: 16,
          color: AppColors.accentGreen,
        ),
        label: const Text(
          'Ver trayecto en vivo',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.accentGreen,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.accentGreen, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // ACCIONES DEL CONDUCTOR
  // ════════════════════════════════════════════════════════════════════

  Widget _buildDriverActions() {
    if (!_isDriver || _isFinalized) return const SizedBox.shrink();

    if (widget.route.status == RouteStatus.enCurso) {
      return Column(
        children: [
          _buildLiveMapButton(isDriver: true),
          const SizedBox(height: 8),
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
          ),
        ],
      );
    } else {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditarRutaScreen(route: widget.route),
                  ),
                );
                if (updated == true && context.mounted) {
                  setState(() {});
                }
              },
              icon: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.accentGreen,
              ),
              label: const Text(
                'Editar ruta',
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
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: _starting
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
                    onPressed: _handleStartRoute,
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: AppColors.accentGreen,
                    ),
                    label: const Text(
                      'Iniciar ruta',
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
          ),
        ],
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // NAVEGACIÓN
  // ════════════════════════════════════════════════════════════

  void _handleCardTap() {
    if (_isDriver) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RouteDetailsScreen(route: widget.route, isDriver: true),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RouteDetailsScreen(route: widget.route, isDriver: false),
        ),
      );
    }
  }

  void _handleRequestSeat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SolicitarCupoScreen(route: widget.route),
      ),
    ).then((_) {
      setState(() => _loadStatus());
      widget.onRefreshRejected?.call();
    });
  }

  // ════════════════════════════════════════════════════════════════════
  // BADGE DE ESTADO
  // ════════��═══════════════════════════════════════════════════════════

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
      bgColor = AppColors.accentGreen.withValues(alpha:0.15);
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

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleCardTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Column(
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
                                ? Colors.red.withValues(alpha:0.1)
                                : AppColors.accentGreen.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isFull
                                ? 'Lleno'
                                : '${widget.route.availableSeats} Cupos',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isFull
                                  ? Colors.red
                                  : AppColors.accentGreen,
                            ),
                          ),
                        ),
                      if (!_isDriver)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_vert,
                              size: 18,
                              color: AppColors.textLight,
                            ),
                            onSelected: (value) {
                              if (value == 'report') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportFormScreen(
                                      type: ReportType.publication,
                                      targetId: widget.route.id,
                                      targetName:
                                          '${widget.route.origin} → ${widget.route.destination}',
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'report',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.flag_outlined,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Reportar ruta',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Text(
                    _isFinalized
                        ? '${widget.route.date} · ${widget.route.time}'
                        : '${widget.route.date} · ${widget.route.time} · ${widget.route.priceFormatted}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
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

                  _buildDriverActions(),

                  if (!_isDriver && !_isFinalized)
                    FutureBuilder<String>(
                      future: _requestStatusFuture,
                      builder: (context, snapshot) {
                        final status = snapshot.data ?? '';
                        final loading =
                            snapshot.connectionState == ConnectionState.waiting;

                        if (status == 'accepted' &&
                            widget.route.status == RouteStatus.enCurso &&
                            !_isSharingLocation) {
                          _startPassengerSharing();
                        } else if ((status != 'accepted' ||
                                widget.route.status != RouteStatus.enCurso) &&
                            _isSharingLocation) {
                          _stopPassengerSharing();
                        }

                        if (status == 'accepted') {
                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen.withValues(alpha:0.1),
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
                              ),

                              if (widget.route.status ==
                                  RouteStatus.enCurso) ...[
                                const SizedBox(height: 8),
                                _buildLiveMapButton(isDriver: false),
                              ],
                            ],
                          );
                        }

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

                        return SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: loading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isSharingLocation) unawaited(_stopPassengerSharing());
    super.dispose();
  }
}
