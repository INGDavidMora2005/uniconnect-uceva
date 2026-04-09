import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionStreamSubscription;

  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      throw Exception('Permisos de ubicación requeridos');
    }
  }

  Future<void> startSharingLocation(String routeId) async {
    await _requestPermissions();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // Verificar que el usuario sea el conductor
    final routeDoc = await _db.collection('routes').doc(routeId).get();
    final routeData = routeDoc.data();
    if (routeData == null || routeData['driverId'] != user.uid) {
      throw Exception('Solo el conductor puede compartir ubicación');
    }

    // Cancelar stream anterior si existe
    await stopSharingLocation(routeId);

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _db.collection('routes').doc(routeId).update({
              'driverLocation': {
                'lat': position.latitude,
                'lng': position.longitude,
                'updatedAt': FieldValue.serverTimestamp(),
              },
            });
          },
        );
  }

  Future<void> stopSharingLocation(String routeId) async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Eliminar ubicación de Firestore
    await _db.collection('routes').doc(routeId).update({
      'driverLocation': FieldValue.delete(),
    });
  }

  Stream<DocumentSnapshot> getDriverLocationStream(String routeId) {
    return _db.collection('routes').doc(routeId).snapshots();
  }

  Future<Position?> getCurrentPosition() async {
    await _requestPermissions();
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }
}
