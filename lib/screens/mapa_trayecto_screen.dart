import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/route_model.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de mapa en vivo para conductores y pasajeros.
///
/// Correcciones aplicadas:
/// ─ Fix #17: Se dibuja la ruta real entre origen y destino (polyline via OSRM).
/// ─ Fix #18: El mapa hace fitBounds automático al cargar para encuadrar
///   todos los puntos relevantes sin zoom manual.
/// ─ Fix #19: El conductor ya NO abre un segundo stream de GPS propio.
///   En su lugar escucha el broadcast stream de LocationService,
///   que es el mismo que sube datos a Firestore.
/// ─ Fix #20: Se muestra un badge "⚠️ Sin señal" si la posición del
///   conductor no se actualizó en los últimos 30 segundos.
/// ─ Fix #21: userAgentPackageName corregido al package real de la app.
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
  // ── Estado del mapa ─────────────────────────────────────────────────
  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _boundsAlreadySet = false;

  // ── Posiciones ───────────────────────────────────────────────────────
  LatLng? _driverPosition; // Posición del conductor (tiempo real)
  LatLng? _myPosition; // Posición del pasajero (solo al inicio)

  // ── Polyline ─────────────────────────────────────────────────────────
  List<LatLng> _routePolyline = [];
  bool _polylineLoading = false;

  // ── Fix #20: Detección de conductor desconectado ─────────────────────
  DateTime? _lastDriverUpdate;
  Timer? _stalenessTimer; // Refresca el badge cada 5 s

  // ── Suscripciones ────────────────────────────────────────────────────
  /// Fix #19: Para el conductor, escuchamos el broadcast de LocationService
  /// (no abrimos un segundo Geolocator.getPositionStream).
  StreamSubscription<dynamic>? _driverPositionSub;

  /// Para el pasajero, escuchamos Firestore.
  StreamSubscription<DocumentSnapshot>? _firestoreSub;

  // ── Puntos fijos de la ruta ───────────────────────────────────────────
  LatLng? get _originPoint =>
      widget.route.originLat != null && widget.route.originLng != null
      ? LatLng(widget.route.originLat!, widget.route.originLng!)
      : null;

  LatLng? get _destPoint =>
      widget.route.destLat != null && widget.route.destLng != null
      ? LatLng(widget.route.destLat!, widget.route.destLng!)
      : null;

  // ── Coordenada de referencia para Cartago, Valle (fallback) ──────────
  static const LatLng _fallbackCenter = LatLng(4.7390, -75.8983);

  // ────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initialize();

    // Fix #20: Timer para refrescar el badge de staleness
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

    // Cargar polyline si hay coordenadas disponibles
    if (_originPoint != null && _destPoint != null) {
      _fetchRoutePolyline();
    }
  }

  // ── Inicialización como CONDUCTOR ────────────────────────────────────
  Future<void> _initAsDriver() async {
    // Obtener posición inicial (una sola llamada)
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

    // Fix #19: Suscribirse al broadcast stream de LocationService
    // (ya activo desde que el conductor presionó "Iniciar ruta").
    // NO se crea un nuevo Geolocator.getPositionStream aquí.
    _driverPositionSub = LocationService().driverPositionStream.listen((
      position,
    ) {
      if (!mounted) return;
      setState(() {
        _driverPosition = LatLng(position.latitude, position.longitude);
        _lastDriverUpdate = DateTime.now();
      });
    });
  }

  // ── Inicialización como PASAJERO ─────────────────────────────────────
  Future<void> _initAsPassenger() async {
    // Posición propia del pasajero (una sola lectura)
    final position = await LocationService().getCurrentPosition();
    if (!mounted) return;

    if (position != null) {
      _myPosition = LatLng(position.latitude, position.longitude);
    }

    _applyFallbackCenter();
    setState(() => _isLoading = false);

    // Escuchar la posición del conductor en Firestore
    _firestoreSub = LocationService()
        .getDriverLocationStream(widget.route.id)
        .listen((DocumentSnapshot doc) {
          if (!doc.exists || !mounted) return;

          final data = doc.data() as Map<String, dynamic>?;
          final loc = data?['driverLocation'];
          if (loc == null) return;

          final lat = (loc['lat'] as num?)?.toDouble();
          final lng = (loc['lng'] as num?)?.toDouble();
          final updatedAt = loc['updatedAt'] as Timestamp?;

          if (lat == null || lng == null) return;

          setState(() {
            _driverPosition = LatLng(lat, lng);
            // Fix #20: timestamp de última actualización del conductor
            _lastDriverUpdate = updatedAt?.toDate() ?? DateTime.now();
          });

          // Primera vez que aparece el conductor → encuadrar el mapa
          if (!_boundsAlreadySet) _tryFitBounds();
        });
  }

  // ── Fix #18: Encuadrar todos los puntos relevantes ───────────────────
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
        // Calcular bounds manualmente para mayor compatibilidad
        double minLat = points.map((p) => p.latitude).reduce(min);
        double maxLat = points.map((p) => p.latitude).reduce(max);
        double minLng = points.map((p) => p.longitude).reduce(min);
        double maxLng = points.map((p) => p.longitude).reduce(max);

        final bounds = LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        );

        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(60, 80, 60, 100),
          ),
        );
        _boundsAlreadySet = true;
      } catch (_) {
        // Si fitCamera falla (mapa aún no renderizado), centrar en driver
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

  // ── Fix #17: Obtener polyline de ruta usando OSRM (gratuito) ─────────
  Future<void> _fetchRoutePolyline() async {
    if (_originPoint == null || _destPoint == null) return;

    if (mounted) setState(() => _polylineLoading = true);

    try {
      final origin = _originPoint!;
      final dest = _destPoint!;

      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${dest.longitude},${dest.latitude}'
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
          final coordinates = routes[0]['geometry']['coordinates'] as List;

          final points = coordinates
              .map(
                (c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();

          setState(() {
            _routePolyline = points;
            _polylineLoading = false;
          });
          return;
        }
      }

      // OSRM no respondió correctamente → fallback: línea recta
      _applyPolylineFallback();
    } catch (_) {
      // Sin internet o timeout → fallback: línea recta
      if (mounted) _applyPolylineFallback();
    }
  }

  void _applyPolylineFallback() {
    if (_originPoint != null && _destPoint != null) {
      setState(() {
        _routePolyline = [_originPoint!, _destPoint!];
        _polylineLoading = false;
      });
    } else {
      setState(() => _polylineLoading = false);
    }
  }

  // ── Fix #20: Badge de estado del conductor ────────────────────────────
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

  // ── Marcadores ────────────────────────────────────────────────────────
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Conductor
    if (_driverPosition != null) {
      final isStale =
          _lastDriverUpdate != null &&
          DateTime.now().difference(_lastDriverUpdate!).inSeconds > 30;

      markers.add(
        Marker(
          point: _driverPosition!,
          width: 46,
          height: 46,
          child: _MapPin(
            icon: Icons.directions_car_rounded,
            color: isStale ? Colors.orange.shade700 : AppColors.accentGreen,
            tooltip: 'Conductor',
          ),
        ),
      );
    }

    // Pasajero (yo)
    if (_myPosition != null && !widget.isDriver) {
      markers.add(
        Marker(
          point: _myPosition!,
          width: 46,
          height: 46,
          child: const _MapPin(
            icon: Icons.person_rounded,
            color: AppColors.primaryGreen,
            tooltip: 'Tú',
          ),
        ),
      );
    }

    // Origen
    if (_originPoint != null) {
      markers.add(
        Marker(
          point: _originPoint!,
          width: 46,
          height: 58,
          child: _MapPinWithTail(
            icon: Icons.trip_origin_rounded,
            color: Colors.green.shade700,
          ),
        ),
      );
    }

    // Destino
    if (_destPoint != null) {
      markers.add(
        Marker(
          point: _destPoint!,
          width: 46,
          height: 58,
          child: _MapPinWithTail(
            icon: Icons.flag_rounded,
            color: Colors.red.shade700,
          ),
        ),
      );
    }

    return markers;
  }

  // ── Acciones ──────────────────────────────────────────────────────────
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

  void _recalculateRoute() {
    setState(() => _routePolyline = []);
    _fetchRoutePolyline();
  }

  // ── Dispose ───────────────────────────────────────────────────────────
  @override
  void dispose() {
    _driverPositionSub?.cancel();
    _firestoreSub?.cancel();
    _stalenessTimer?.cancel();
    // IMPORTANTE: no llamamos LocationService().stopSharingLocation() aquí.
    // Eso lo maneja route_card.dart al finalizar la ruta explícitamente.
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────
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
        // ── Mapa base ───────────────────────────────────────────────
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
            // Fix #21: package correcto para el user-agent de OSM
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.uceva.uniconnect_app',
              maxZoom: 18,
            ),

            // Fix #17: Polyline de la ruta calculada
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

            MarkerLayer(markers: _buildMarkers()),
          ],
        ),

        // ── Badge de carga de polyline ──────────────────────────────
        if (_polylineLoading)
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentGreen,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Calculando ruta...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Fix #20: Badge de estado del conductor (solo para pasajeros)
        if (!widget.isDriver && !_polylineLoading)
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(child: _buildDriverStatusBadge()),
          ),

        // ── Leyenda ─────────────────────────────────────────────────
        Positioned(
          bottom: widget.isEmbedded ? 10 : 100,
          left: 12,
          child: _buildLegend(),
        ),

        // ── Botones de acción (solo modo fullscreen) ─────────────────
        if (!widget.isEmbedded) ...[
          // Centrar en conductor
          Positioned(
            bottom: 100,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'center_driver_btn',
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
              heroTag: 'fit_bounds_btn',
              onPressed: () {
                _boundsAlreadySet = false;
                _tryFitBounds();
              },
              backgroundColor: Colors.white,
              elevation: 3,
              child: Icon(
                Icons.zoom_out_map_rounded,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
          ),

          // Recalcular ruta (OSRM)
          Positioned(
            bottom: 200,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'recalc_route_btn',
              onPressed: _recalculateRoute,
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

    // Modo embebido: solo el mapa sin Scaffold
    if (widget.isEmbedded) return mapBody;

    // Modo fullscreen: con AppBar
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
      ),
      body: mapBody,
    );
  }

  // ── Leyenda del mapa ──────────────────────────────────────────────────
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
          _legendRow(Colors.green.shade700, 'Origen'),
          const SizedBox(height: 5),
          _legendRow(Colors.red.shade700, 'Destino'),
          const SizedBox(height: 5),
          _legendRow(AppColors.accentGreen, 'Conductor'),
          if (!widget.isDriver && _myPosition != null) ...[
            const SizedBox(height: 5),
            _legendRow(AppColors.primaryGreen, 'Tú'),
          ],
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
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
  }
}

// ── Widgets auxiliares de marcadores ──────────────────────────────────────

/// Marcador circular simple (conductor, pasajero).
class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;

  const _MapPin({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 42,
        height: 42,
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
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

/// Marcador con "cola" estilo pin de mapa (origen, destino).
class _MapPinWithTail extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MapPinWithTail({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
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
                color: Colors.black.withOpacity(0.2),
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
    );
  }
}
