import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';
import '../models/report_model.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../services/cupo_service.dart';
import '../services/user_history_service.dart';

import 'mapa_trayecto_screen.dart';
import 'report_form_screen.dart';

class RouteDetailsScreen extends StatefulWidget {
  final RouteModel route;
  final bool isDriver;

  const RouteDetailsScreen({
    super.key,
    required this.route,
    required this.isDriver,
  });

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  bool _isDriver = false;
  bool _hasCupoAceptado = false;
  bool _loading = false;
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _isDriver = uid == widget.route.driverId;
    _checkCupoAceptado();
    if (uid != null) {
      unawaited(UserHistoryService().logRouteView(uid, widget.route));
    }
  }

  /// Verifica si el pasajero tiene cupo aceptado para mostrar botón de chat
  Future<void> _checkCupoAceptado() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || _isDriver) return;
    final status = await CupoService().getRequestStatus(uid, widget.route.id);
    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    if (mounted) {
      setState(() {
        _hasCupoAceptado = status == 'accepted';
        _currentUserName = userDoc.data()?['fullName'] ?? '';
      });
    }
  }

  Future<void> _cancelarReserva() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    setState(() => _loading = true);
    await CupoService().cancelSeat(
      routeId: widget.route.id,
      passengerId: uid,
      passengerName: _currentUserName,
      driverId: widget.route.driverId ?? '',
      origin: widget.route.origin,
      destination: widget.route.destination,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasCupoAceptado = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reserva cancelada exitosamente'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: const Text(
          'Detalles del viaje',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isDriver)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
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
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Reportar ruta'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info principal
            Text(
              '${widget.route.origin} → ${widget.route.destination}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.route.date} · ${widget.route.time}',
              style: const TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 8),
            Text(
              'Precio: ${widget.route.priceFormatted}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.accentGreen,
              ),
            ),
            const SizedBox(height: 16),

            // Conductor
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accentGreen,
                  child: Text(
                    widget.route.driverInitials,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.route.driverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '⭐ ${widget.route.driverRating}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Detalles adicionales
            if (widget.route.meetingPoint.isNotEmpty) ...[
              Text(
                'Punto de encuentro: ${widget.route.meetingPoint}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.route.note != null && widget.route.note!.isNotEmpty) ...[
              Text(
                'Nota: ${widget.route.note}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Cupos disponibles: ${widget.route.availableSeats}/${widget.route.totalSeats}',
              style: const TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),

            // Estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.route.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.route.statusColor),
              ),
              child: Text(
                widget.route.statusLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.route.statusColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Mapa si en curso
            if (widget.route.status == RouteStatus.enCurso) ...[
              const Text(
                'Trayecto en vivo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: MapaTrayectoScreen(
                  route: widget.route,
                  isDriver: widget.isDriver,
                  isEmbedded: true,
                ),
              ),
            ],
            // Botones para pasajeros con cupo aceptado
            if (_hasCupoAceptado)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  label: const Text(
                    'Abrir chat con el conductor',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    final routeId = widget.route.id;
                    final driverId = widget.route.driverId ?? '';

                    debugPrint('=== ABRIR CHAT ===');
                    debugPrint('routeId: $routeId');
                    debugPrint('passengerId: $uid');
                    debugPrint('driverId: $driverId');
                    debugPrint('passengerName: $_currentUserName');
                    debugPrint('driverName: ${widget.route.driverName}');

                    if (routeId.isEmpty || uid.isEmpty || driverId.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Error: faltan datos para abrir el chat'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }

                    final chatId = await ChatService().getOrCreateChat(
                      routeId: routeId,
                      passengerId: uid,
                      driverId: driverId,
                      passengerName: _currentUserName,
                      driverName: widget.route.driverName,
                      origin: widget.route.origin,
                      destination: widget.route.destination,
                    );

                    debugPrint('chatId resultado: $chatId');

                    if (!mounted) return;
                    if (chatId.startsWith('error')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('No se pudo abrir el chat: $chatId'),
                            backgroundColor: Colors.redAccent),
                      );
                      return;
                    }
                    Navigator.pushNamed(context, '/chat', arguments: {
                      'chatId': chatId,
                      'otherUserName': widget.route.driverName,
                      'otherUserId': driverId,
                      'routeInfo':
                          '${widget.route.origin} → ${widget.route.destination}',
                    });
                  },
                ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                      label: const Text(
                        'Cancelar reserva',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loading
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('¿Cancelar reserva?'),
                                  content: const Text(
                                    'Si cancelas, tu cupo será liberado y el conductor será notificado. Esta acción no se puede deshacer.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Volver'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Sí, cancelar',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) await _cancelarReserva();
                            },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
