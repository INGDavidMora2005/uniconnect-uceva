import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

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
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _driverPosition;
  bool _isLoading = true;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    if (widget.isDriver) {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        setState(() {
          _driverPosition = LatLng(position.latitude, position.longitude);
        });
      });
    } else {
      _driverLocationSubscription = LocationService().getDriverLocationStream(widget.route.id).listen((DocumentSnapshot doc) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          final driverLocation = data?['driverLocation'];
          if (driverLocation != null) {
            final lat = driverLocation['lat'] as double?;
            final lng = driverLocation['lng'] as double?;
            if (lat != null && lng != null) {
              setState(() {
                _driverPosition = LatLng(lat, lng);
              });
            }
          }
        }
      });
    }
  }

  Future<void> _initializeMap() async {
    if (widget.isDriver) {
      // Conductor: obtener posición actual
      try {
        final position = await LocationService().getCurrentPosition();
        if (position != null) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _driverPosition = _currentPosition;
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _mapController.move(_currentPosition!, 15));
        } else {
          final center = widget.route.originLat != null && widget.route.originLng != null
              ? LatLng(widget.route.originLat!, widget.route.originLng!)
              : const LatLng(0, 0);
          WidgetsBinding.instance.addPostFrameCallback((_) => _mapController.move(center, 15));
          _showError('No se pudo obtener la ubicación actual');
          return;
        }
      } catch (e) {
        final center = widget.route.originLat != null && widget.route.originLng != null
            ? LatLng(widget.route.originLat!, widget.route.originLng!)
            : const LatLng(0, 0);
        WidgetsBinding.instance.addPostFrameCallback((_) => _mapController.move(center, 15));
        _showError(e.toString());
      }
    } else {
      // Pasajero: obtener posición actual y escuchar al conductor
      final position = await LocationService().getCurrentPosition();
      if (position != null) {
        _currentPosition = LatLng(position.latitude, position.longitude);
      }
      // Centrar en origen si no hay driverLocation
      final center =
          widget.route.originLat != null && widget.route.originLng != null
          ? LatLng(widget.route.originLat!, widget.route.originLng!)
          : _currentPosition ?? const LatLng(0, 0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _mapController.move(center, 15));
      if (position == null) {
        _showError('No se pudo obtener la ubicación actual');
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!widget.isEmbedded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    if (widget.isDriver) {
      LocationService().stopSharingLocation(widget.route.id);
    }
    _positionSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _driverPosition ?? _currentPosition ?? const LatLng(0, 0),
                  initialZoom: 15,
                  minZoom: 10,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.uniconnect',
                  ),
                  MarkerLayer(markers: _buildMarkers()),
                ],
              ),
            ],
          );

    return widget.isEmbedded
        ? body
        : Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.primaryGreen,
              title: Text(
                '${widget.route.origin} → ${widget.route.destination}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: body,
            floatingActionButton: FloatingActionButton(
              onPressed: _centerOnDriver,
              backgroundColor: AppColors.primaryGreen,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Marcador del conductor
    if (_driverPosition != null) {
      markers.add(
        Marker(
          point: _driverPosition!,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF1D9E75),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      );
    }

    // Marcador del pasajero/usuario actual
    if (_currentPosition != null && !widget.isDriver) {
      markers.add(
        Marker(
          point: _currentPosition!,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF085041),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_pin_circle,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      );
    }

    // Marcador de origen
    if (widget.route.originLat != null && widget.route.originLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.route.originLat!, widget.route.originLng!),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
        ),
      );
    }

    // Marcador de destino
    if (widget.route.destLat != null && widget.route.destLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.route.destLat!, widget.route.destLng!),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag, color: Colors.white, size: 24),
          ),
        ),
      );
    }

    return markers;
  }

  void _centerOnDriver() {
    if (_driverPosition != null) {
      _mapController.move(_driverPosition!, 15);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El conductor aún no ha iniciado la ruta')),
      );
    }
  }


}
