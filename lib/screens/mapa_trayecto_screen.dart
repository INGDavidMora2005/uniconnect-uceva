// Funcion de mapas en vivo

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../models/route_model.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de mapa en vivo.
///
/// Cambios del plan implementados:
/// ─ Cambio 1: El conductor ve los marcadores de todos sus pasajeros.
///   El pasajero sube su posición a Firestore al abrir el mapa y la
///   elimina al cerrarlo.
/// ─ Cambio 2: Se traza una segunda polyline (azul) desde la posición
///   actual del conductor hasta el pasajero más cercano, calculada
///   con OSRM. Se recalcula cada vez que el conductor se mueve > 50 m.
/// ─ Cambio 3: El botón que abre esta pantalla es el mismo para ambos
///   roles (manejado en route_card.dart); aquí solo se adapta la UI
///   interna según [isDriver].
///
/// Fixes de la versión anterior que se conservan:
/// ─ Fix #16: stopSharingLocation no crashea si la ruta fue eliminada.
/// ─ Fix #17: Polyline verde de la ruta publicada (origen → destino).
/// ─ Fix #18: fitBounds automático al cargar.
/// ─ Fix #19: El conductor no abre un segundo stream de GPS propio.
/// ─ Fix #20: Badge "Sin señal" si la posición del conductor no se
///   actualizó en los últimos 30 s.
/// ─ Fix #21: userAgentPackageName correcto.
class MapaTrayectoScreen extends StatefulWidget {
  final RouteModel route;
  final bool isDriver;
  final bool isEmbedded;

  const MapaTrayectoScreen({
    super.key,
    required this.route,
    required this.isDriver,
    this.isEmbedded = false,
  });

  @override
  State<MapaTrayectoScreen> createState() => _MapaTrayectoScreenState();
}

class _MapaTrayectoScreenState extends State<MapaTrayectoScreen> {
  // ── Mapa ────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _boundsAlreadySet = false;

  // ── Posiciones ───────────────────────────────────────────────────────
  LatLng? _driverPosition;
  LatLng? _myPosition; // Posición propia del pasajero

  /// Cambio 1 — mapa de posiciones de pasajeros (visible al conductor).
  Map<String, LatLng> _passengerPositions = {};
  Map<String, Map<String, String>> _passengerInfos = {};
  // passengerInfos[uid] = {'name': '...', 'initials': '...'}

  // ── Polylines ────────────────────────────────────────────────────────
  List<LatLng> _routePolyline = []; // Verde: ruta publicada origen→destino
  List<LatLng> _pickupPolyline = []; // Azul: conductor→pasajero más cercano
  bool _polylineLoading = false;
  bool _usingRouteFallback = false;
  bool _usingPickupFallback = false;

  // ── Cambio 2 — control de recalculo del pickup ────────────────────────
  bool _isCalculatingPickup = false;

  // ── Fix #20 — detección de conductor desconectado ────────────────────
  DateTime? _lastDriverUpdate;
  Timer? _stalenessTimer;

  // ── Suscripciones ────────────────────────────────────────────────────
  /// Fix #19: El conductor escucha el broadcast de LocationService,
  /// no abre su propio Geolocator.getPositionStream.
  StreamSubscription<Position>? _driverBroadcastSub;

  /// El pasajero escucha el documento de la ruta para ver al conductor.
  /// El conductor también escucha el documento para ver a los pasajeros.
  StreamSubscription<DocumentSnapshot>? _routeDocSub;

  // ── Fallback geográfico ───────────────────────────────────────────────
  // Cartago, Valle del Cauca
  static const LatLng _fallbackCenter = LatLng(4.7390, -75.8983);

  // ── Usuario actual ────────────────────────────────────────────────────
  String _myUid = '';

  // ── Puntos fijos de la ruta publicada ─────────────────────────────────
  LatLng? get _originPoint =>
      widget.route.originLat != null && widget.route.originLng != null
      ? LatLng(widget.route.originLat!, widget.route.originLng!)
      : null;

  LatLng? get _destPoint =>
      widget.route.destLat != null && widget.route.destLng != null
      ? LatLng(widget.route.destLat!, widget.route.destLng!)
      : null;

  // ════════════════════════════════════════════════════════════════════
  // CICLO DE VIDA
  // ════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _initialize();

    // Fix #20: Refrescar el badge de staleness cada 5 s (solo pasajeros)
    if (!widget.isDriver) {
      _stalenessTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _initialize() async {
    if (widget.isDriver) {
      await _initAsDriver();
    } else {
      await _initAsPassenger();
    }

    // Cargar polyline verde (ruta publicada) si hay coordenadas
    if (_originPoint != null && _destPoint != null) {
      _fetchRoutePolyline();
    }
  }

  // ── Inicialización como CONDUCTOR ─────────────────────────────────────
  Future<void> _initAsDriver() async {
    // Posición inicial (una sola lectura)
    final position = await LocationService().getCurrentPosition();
    if (!mounted) return;

    if (position != null) {
      setState(() {
        _driverPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _tryFitBounds();
    } else {
      _applyFallbackCenter();
    }

    // Fix #19: Escuchar el broadcast en lugar de abrir un nuevo GPS
    _driverBroadcastSub = LocationService().driverPositionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _driverPosition = LatLng(pos.latitude, pos.longitude);
        _lastDriverUpdate = DateTime.now();
      });
      // Cambio 2: recalcular pickup si el conductor se movió suficiente
      _tryRecalculatePickupPolyline();
    });

    // Cambio 1: Escuchar Firestore para ver posiciones de pasajeros
    _routeDocSub = LocationService()
        .getRouteStream(widget.route.id)
        .listen(_onRouteDocUpdate);
  }

  // ── Inicialización como PASAJERO ──────────────────────────────────────
  Future<void> _initAsPassenger() async {
    // Posición propia del pasajero (una sola lectura)
    final position = await LocationService().getCurrentPosition();
    if (!mounted) return;
    if (position != null) {
      _myPosition = LatLng(position.latitude, position.longitude);
    }

    _applyFallbackCenter();
    if (mounted) setState(() => _isLoading = false);

    // Cambio 1: Subir posición del pasajero a Firestore si la ruta está en curso
    if (widget.route.status == RouteStatus.enCurso) {
      await _startPassengerLocationSharing();
    }

    // Escuchar el documento de la ruta para ver al conductor
    _routeDocSub = LocationService()
        .getRouteStream(widget.route.id)
        .listen(_onRouteDocUpdate);
  }

  // ── Cambio 1 — Subir posición del pasajero ────────────────────────────
  Future<void> _startPassengerLocationSharing() async {
    if (_myUid.isEmpty) return;
    try {
      // Obtener datos del usuario desde Firestore para nombre e iniciales
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myUid)
          .get();
      final name = (userDoc.data()?['fullName'] as String?) ?? 'Pasajero';
      final parts = name.trim().split(' ');
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : (parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'P');

      await LocationService().startSharingPassengerLocation(
        routeId: widget.route.id,
        passengerId: _myUid,
        passengerName: name,
        passengerInitials: initials,
      );
    } catch (_) {
      // La compartición de ubicación del pasajero es una mejora opcional;
      // si falla, el mapa sigue funcionando.
    }
  }

  // ── Handler compartido del documento de Firestore ─────────────────────
  void _onRouteDocUpdate(DocumentSnapshot doc) {
    if (!doc.exists || !mounted) return;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    if (widget.isDriver) {
      // ── CONDUCTOR: leer posiciones de pasajeros ──────────────────────
      final rawMap = data['passengerLocations'] as Map<String, dynamic>?;
      final newPositions = <String, LatLng>{};
      final newInfos = <String, Map<String, String>>{};

      if (rawMap != null) {
        for (final entry in rawMap.entries) {
          final uid = entry.key;
          final loc = entry.value as Map<String, dynamic>?;
          if (loc == null) continue;
          final lat = (loc['lat'] as num?)?.toDouble();
          final lng = (loc['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          newPositions[uid] = LatLng(lat, lng);
          newInfos[uid] = {
            'name': (loc['name'] as String?) ?? 'Pasajero',
            'initials': (loc['initials'] as String?) ?? 'P',
          };
        }
      }

      setState(() {
        _passengerPositions = newPositions;
        _passengerInfos = newInfos;
      });

      // Cambio 2: Recalcular pickup con las nuevas posiciones
      _tryRecalculatePickupPolyline();
    } else {
      // ── PASAJERO: leer posición del conductor ────────────────────────
      final driverLoc = data['driverLocation'] as Map<String, dynamic>?;
      if (driverLoc == null) return;

      final lat = (driverLoc['lat'] as num?)?.toDouble();
      final lng = (driverLoc['lng'] as num?)?.toDouble();
      final updatedAt = driverLoc['updatedAt'] as Timestamp?;

      if (lat == null || lng == null) return;

      setState(() {
        _driverPosition = LatLng(lat, lng);
        _lastDriverUpdate = updatedAt?.toDate() ?? DateTime.now();
      });

      if (!_boundsAlreadySet) _tryFitBounds();
    }
  }



  // 
  // CAMBIO 2 — POLYLINE DE PICKUP (conductor → pasajero más cercano)
  // 

  /// Distancia Haversine en metros entre dos puntos.
  double _haversineDistance(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  /// Retorna la posición del pasajero más cercano al conductor.
  LatLng? _nearestPassenger() {
    if (_driverPosition == null || _passengerPositions.isEmpty) return null;
    LatLng? nearest;
    double minDist = double.infinity;
    for (final pos in _passengerPositions.values) {
      final d = _haversineDistance(_driverPosition!, pos);
      if (d < minDist) {
        minDist = d;
        nearest = pos;
      }
    }
    return nearest;
  }

  /// Decide si hay que recalcular el pickup y lo lanza.
  void _tryRecalculatePickupPolyline() {
    if (!widget.isDriver) return;
    if (_driverPosition == null) return;
    if (_isCalculatingPickup) return;

    if (_passengerPositions.isEmpty) {
      if (mounted) setState(() => _pickupPolyline = []);
      return;
    }

    // Siempre recalcular cuando cambian las posiciones
    _fetchPickupPolyline();
  }

  /// Obtiene la polyline de pickup vía OSRM.
  /// Fallback: línea recta si OSRM no responde.
  Future<void> _fetchPickupPolyline() async {
    if (_driverPosition == null || _passengerPositions.isEmpty) return;

    final nearest = _nearestPassenger();
    if (nearest == null) return;

    if (mounted) setState(() => _isCalculatingPickup = true);

    try {
      final driver = _driverPosition!;
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${driver.longitude},${driver.latitude};'
        '${nearest.longitude},${nearest.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http
          .get(uri, headers: {'User-Agent': 'UniConnectUCEVA/1.0'})
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final coords = routes[0]['geometry']['coordinates'] as List;
          final points = coords
              .map(
                (c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();
          setState(() {
            _pickupPolyline = points;
            _isCalculatingPickup = false;
            _usingPickupFallback = false;
          });
          return;
        }
      }
      _applyPickupFallback(nearest);
    } catch (_) {
      if (mounted) _applyPickupFallback(_nearestPassenger());
    }
  }

  void _applyPickupFallback(LatLng? target) {
    if (!mounted) return;
    setState(() {
      _pickupPolyline = (_driverPosition != null && target != null)
          ? [_driverPosition!, target]
          : [];
      _isCalculatingPickup = false;
      _usingPickupFallback = true;
    });
  }

  // ════════════════════════════════════════════════════════════════════
  // FIX #17 — POLYLINE DE RUTA PUBLICADA (origen → destino)
  // ════════════════════════════════════════════════════════════════════

  Future<void> _fetchRoutePolyline() async {
    if (_originPoint == null || _destPoint == null) return;
    if (mounted) setState(() => _polylineLoading = true);

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_originPoint!.longitude},${_originPoint!.latitude};'
        '${_destPoint!.longitude},${_destPoint!.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http
          .get(uri, headers: {'User-Agent': 'UniConnectUCEVA/1.0'})
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final coords = routes[0]['geometry']['coordinates'] as List;
          setState(() {
            _routePolyline = coords
                .map(
                  (c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ),
                )
                .toList();
            _polylineLoading = false;
            _usingRouteFallback = false;
          });
          return;
        }
      }
      _applyRouteFallback();
    } catch (_) {
      if (mounted) _applyRouteFallback();
    }
  }

  void _applyRouteFallback() {
    if (!mounted) return;
    setState(() {
      _routePolyline = (_originPoint != null && _destPoint != null)
          ? [_originPoint!, _destPoint!]
          : [];
      _polylineLoading = false;
      _usingRouteFallback = true;
    });
  }

  // ════════════════════════════════════════════════════════════════════
  // FIX #18 — FIT BOUNDS AUTOMÁTICO
  // ════════════════════════════════════════════════════════════════════

  void _tryFitBounds() {
    final points = <LatLng>[
      if (_driverPosition != null) _driverPosition!,
      if (_originPoint != null) _originPoint!,
      if (_destPoint != null) _destPoint!,
      if (_myPosition != null && !widget.isDriver) _myPosition!,
    ];

    if (points.isEmpty) {
      _applyFallbackCenter();
      return;
    }

    if (points.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(points.first, 15);
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final minLat = points.map((p) => p.latitude).reduce(min);
        final maxLat = points.map((p) => p.latitude).reduce(max);
        final minLng = points.map((p) => p.longitude).reduce(min);
        final maxLng = points.map((p) => p.longitude).reduce(max);

        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(
              LatLng(minLat, minLng),
              LatLng(maxLat, maxLng),
            ),
            padding: const EdgeInsets.fromLTRB(60, 80, 60, 100),
          ),
        );
        _boundsAlreadySet = true;
      } catch (_) {
        if (_driverPosition != null) {
          _mapController.move(_driverPosition!, 14);
        }
      }
    });
  }

  void _applyFallbackCenter() {
    if (!mounted) return;
    setState(() => _isLoading = false);
    final center = _originPoint ?? _myPosition ?? _fallbackCenter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(center, 14);
    });
  }

  // ════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _driverBroadcastSub?.cancel();
    _routeDocSub?.cancel();
    _stalenessTimer?.cancel();



    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  // MARCADORES
  // ════════════════════════════════════════════════════════════════════

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // ── Conductor ─────────────────────────────────────────────────────
    if (_driverPosition != null) {
      final isStale =
          _lastDriverUpdate != null &&
          DateTime.now().difference(_lastDriverUpdate!).inSeconds > 30;

      markers.add(
        Marker(
          point: _driverPosition!,
          width: 46,
          height: 58,
          child: _MapPinWithTail(
            icon: Icons.directions_car_rounded,
            color: isStale ? Colors.orange.shade700 : AppColors.accentGreen,
            tooltip: 'Conductor',
          ),
        ),
      );
    }

    // ── Pasajero propio (solo visible en modo pasajero) ───────────────
    if (_myPosition != null && !widget.isDriver) {
      markers.add(
        Marker(
          point: _myPosition!,
          width: 46,
          height: 58,
          child: const _MapPinWithTail(
            icon: Icons.person_rounded,
            color: AppColors.primaryGreen,
            tooltip: 'Tú',
          ),
        ),
      );
    }

    // ── Cambio 1: Pasajeros visibles al conductor ──────────────────────
    if (widget.isDriver) {
      for (final entry in _passengerPositions.entries) {
        final uid = entry.key;
        final pos = entry.value;
        final info = _passengerInfos[uid] ?? {};
        final name = info['name'] ?? 'Pasajero';
        markers.add(
          Marker(
            point: pos,
            width: 46,
            height: 58,
            child: _MapPinWithTail(
              icon: Icons.person_pin_circle_rounded,
              color: Colors.blue.shade700,
              tooltip: name,
            ),
          ),
        );
      }
    }

    // ── Origen ────────────────────────────────────────────────────────
    if (_originPoint != null) {
      markers.add(
        Marker(
          point: _originPoint!,
          width: 46,
          height: 58,
          child: const _MapPinWithTail(
            icon: Icons.trip_origin_rounded,
            color: Colors.green,
            tooltip: 'Origen',
          ),
        ),
      );
    }

    // ── Destino ───────────────────────────────────────────────────────
    if (_destPoint != null) {
      markers.add(
        Marker(
          point: _destPoint!,
          width: 46,
          height: 58,
          child: _MapPinWithTail(
            icon: Icons.flag_rounded,
            color: Colors.red.shade700,
            tooltip: 'Destino',
          ),
        ),
      );
    }

    return markers;
  }

  // ════════════════════════════════════════════════════════════════════
  // FIX #20 — BADGE ESTADO DEL CONDUCTOR
  // ════════════════════════════════════════════════════════════════════

  Widget _buildDriverStatusBadge() {
    final Color bg;
    final Color fg;
    final String text;

    if (_driverPosition == null) {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade600;
      text = '📍 Esperando al conductor...';
    } else if (_lastDriverUpdate == null) {
      bg = const Color(0xFFE8F5EE);
      fg = AppColors.accentGreen;
      text = '🚗 En vivo';
    } else {
      final diff = DateTime.now().difference(_lastDriverUpdate!);
      if (diff.inSeconds > 30) {
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        text = '⚠️ Sin señal del conductor (${diff.inSeconds}s)';
      } else {
        bg = const Color(0xFFE8F5EE);
        fg = AppColors.accentGreen;
        text = '🚗 En vivo';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // LEYENDA
  // ════════════════════════════════════════════════════════════════════

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(Colors.green, 'Origen'),
          const SizedBox(height: 5),
          _legendRow(Colors.red.shade700, 'Destino'),
          const SizedBox(height: 5),
          _legendRow(AppColors.accentGreen, 'Conductor'),
          if (!widget.isDriver && _myPosition != null) ...[
            const SizedBox(height: 5),
            _legendRow(AppColors.primaryGreen, 'Tú'),
          ],
          // Cambio 1: leyenda para pasajeros (vista del conductor)
          if (widget.isDriver && _passengerPositions.isNotEmpty) ...[
            const SizedBox(height: 5),
            _legendRow(Colors.blue.shade700, 'Pasajero(s)'),
          ],
          // Cambio 2: leyenda para la polyline de pickup
          if (widget.isDriver && _pickupPolyline.isNotEmpty) ...[
            const SizedBox(height: 5),
            _legendPolyline(Colors.blue.shade600, 'Ruta al pasajero'),
          ],
          if (_routePolyline.isNotEmpty) ...[
            const SizedBox(height: 5),
            _legendPolyline(AppColors.accentGreen, 'Ruta publicada'),
          ],
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textDark,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  Widget _legendPolyline(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textDark,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  // ════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ════════════════════════════════════════════════════════════════════

  void _centerOnDriver() {
    if (_driverPosition != null) {
      _mapController.move(_driverPosition!, 16);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El conductor aún no ha iniciado la ruta'),
          backgroundColor: Colors.black54,
        ),
      );
    }
  }

  void _refitBounds() {
    _boundsAlreadySet = false;
    _tryFitBounds();
  }

  void _recalcAllPolylines() {
    setState(() {
      _routePolyline = [];
      _pickupPolyline = [];
    });
    _fetchRoutePolyline();
    _tryRecalculatePickupPolyline();
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accentGreen),
            SizedBox(height: 12),
            Text(
              'Cargando mapa...',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    final mapBody = Stack(
      children: [
        // ── Mapa base ─────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                _driverPosition ??
                _originPoint ??
                _myPosition ??
                _fallbackCenter,
            initialZoom: 14,
            minZoom: 5,
            maxZoom: 18,
          ),
          children: [
            // Fix #21: package correcto
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.uceva.uniconnect_app',
              maxZoom: 18,
            ),

            // Fix #17: Polyline verde — ruta publicada origen→destino
            if (_routePolyline.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePolyline,
                    color: AppColors.accentGreen.withOpacity(0.85),
                    strokeWidth: 5.0,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),

            // Cambio 2: Polyline azul — conductor → pasajero más cercano
            if (widget.isDriver && _pickupPolyline.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _pickupPolyline,
                    color: Colors.blue.shade600.withOpacity(0.9),
                    strokeWidth: 4.0,
                    borderColor: Colors.white,
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

            MarkerLayer(markers: _buildMarkers()),
          ],
        ),

        // ── Badge de carga de polylines ──────────────────────────────
        if (_polylineLoading || _isCalculatingPickup)
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCalculatingPickup
                          ? 'Calculando ruta al pasajero...'
                          : 'Calculando ruta...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Fix #20: Badge de estado del conductor (solo pasajeros,
        // y solo cuando no hay otro badge cargando)
        if (!widget.isDriver && !_polylineLoading && !_isCalculatingPickup)
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(child: _buildDriverStatusBadge()),
          ),

        // ── Leyenda ───────────────────────────────────────────────────
        Positioned(
          bottom: widget.isEmbedded ? 10 : 100,
          left: 12,
          child: _buildLegend(),
        ),

        // ── Botones de acción (solo fullscreen) ───────────────────────
        if (!widget.isEmbedded) ...[
          // Centrar en conductor
          Positioned(
            bottom: 100,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'fab_center',
              onPressed: _centerOnDriver,
              backgroundColor: AppColors.primaryGreen,
              elevation: 3,
              child: const Icon(
                Icons.my_location_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // Fix #18: Encuadrar todos los puntos
          Positioned(
            bottom: 150,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'fab_fit',
              onPressed: _refitBounds,
              backgroundColor: Colors.white,
              elevation: 3,
              child: Icon(
                Icons.zoom_out_map_rounded,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
          ),
          // Recalcular todas las rutas
          Positioned(
            bottom: 200,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'fab_recalc',
              onPressed: _recalcAllPolylines,
              backgroundColor: Colors.white,
              elevation: 3,
              child: Icon(
                Icons.route_rounded,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
          ),
        ],
      ],
    );

    // Modo embebido: solo el mapa, sin Scaffold
    if (widget.isEmbedded) return mapBody;

    // Modo fullscreen: con AppBar completo
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.route.origin} → ${widget.route.destination}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.isDriver ? 'Compartiendo ubicación' : 'Mapa en vivo',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        // Contador de pasajeros conectados (solo conductor)
        actions: [
          if (widget.isDriver && _passengerPositions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_passengerPositions.length} pasajero'
                    '${_passengerPositions.length > 1 ? 's' : ''} conectado'
                    '${_passengerPositions.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: mapBody,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES DE MARCADORES
// ════════════════════════════════════════════════════════════════════

/// Pin con "cola" estilo clásico de mapa.
class _MapPinWithTail extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;

  const _MapPinWithTail({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          // Cola del pin
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(2),
                bottomRight: Radius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
