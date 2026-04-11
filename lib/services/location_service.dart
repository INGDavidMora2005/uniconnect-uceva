import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio centralizado de ubicación.
///
/// Correcciones aplicadas:
/// ─ Fix #16: stopSharingLocation ya no crashea si la ruta fue eliminada.
/// ─ Fix #19: Se expone [driverPositionStream] (broadcast) para que
///   MapaTrayectoScreen escuche las posiciones del conductor sin abrir
///   un segundo stream de GPS independiente.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream real del GPS (privado). Solo se abre UNA vez.
  StreamSubscription<Position>? _positionStreamSubscription;

  /// StreamController broadcast: cualquier widget puede escuchar
  /// la posición del conductor sin crear su propio stream de GPS.
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  /// Stream público de posición del conductor.
  /// Úsalo en MapaTrayectoScreen (modo conductor) en lugar de
  /// llamar a Geolocator.getPositionStream() directamente.
  Stream<Position> get driverPositionStream => _positionController.stream;

  // ── Permisos ───────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      throw Exception('Permisos de ubicación requeridos');
    }
  }

  // ── Compartir ubicación (conductor) ────────────────────────────────

  Future<void> startSharingLocation(String routeId) async {
    await _requestPermissions();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // Verificar que quien llama sea el conductor de la ruta
    final routeDoc = await _db.collection('routes').doc(routeId).get();
    final routeData = routeDoc.data();
    if (routeData == null || routeData['driverId'] != user.uid) {
      throw Exception('Solo el conductor puede compartir ubicación');
    }

    // Cancelar stream anterior si existía
    await _positionStreamSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Solo actualizar si se mueve > 10 metros
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          // 1. Emitir al broadcast para que el mapa local del conductor lo reciba
          //    sin necesidad de un segundo stream de GPS.
          if (!_positionController.isClosed) {
            _positionController.add(position);
          }

          // 2. Subir a Firestore con timestamp para detectar desconexiones.
          _db
              .collection('routes')
              .doc(routeId)
              .update({
                'driverLocation': {
                  'lat': position.latitude,
                  'lng': position.longitude,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              })
              .catchError((_) {
                // Si la ruta fue eliminada mientras el conductor compartía,
                // ignorar el error silenciosamente.
              });
        });
  }

  // ── Detener ubicación (conductor) ──────────────────────────────────

  /// Fix #16: Ahora verifica que el documento exista antes de intentar
  /// actualizar, evitando la excepción cuando la ruta ya fue eliminada.
  Future<void> stopSharingLocation(String routeId) async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    try {
      final doc = await _db.collection('routes').doc(routeId).get();
      if (doc.exists) {
        await doc.reference.update({'driverLocation': FieldValue.delete()});
      }
      // Si el documento no existe, la ruta ya fue eliminada. No hay
      // nada que limpiar, así que simplemente no hacemos nada.
    } on FirebaseException catch (_) {
      // La ruta fue eliminada justo entre el get y el update.
      // Ignorar — no es un estado incorrecto.
    } catch (_) {
      // Cualquier otro error no debe propagar ni crashear la app.
    }
  }

  // ── Stream de Firestore (pasajero observa al conductor) ────────────

  /// Retorna un stream en tiempo real del documento de la ruta.
  /// El pasajero lo usa para ver la posición actualizada del conductor.
  Stream<DocumentSnapshot> getDriverLocationStream(String routeId) {
    return _db.collection('routes').doc(routeId).snapshots();
  }

  // ── Posición actual única ──────────────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    await _requestPermissions();
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Limpieza del servicio ──────────────────────────────────────────

  /// Llamar solo al destruir la app. No llamar desde pantallas individuales.
  void dispose() {
    _positionStreamSubscription?.cancel();
    _positionController.close();
  }
}
