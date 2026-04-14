import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio centralizado de ubicación.
///
/// Responsabilidades:
/// ─ Conductor: un único stream de GPS (broadcast) que alimenta tanto
///   la UI del mapa como Firestore. Sin streams duplicados.
/// ─ Pasajero: stream propio de GPS que sube su posición a Firestore
///   mientras tiene el mapa abierto.
/// ─ Ambos: stream de Firestore para escuchar el documento de la ruta.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Stream GPS del conductor ─────────────────────────────────────────
  // Un único stream real; se expone como broadcast para que
  // MapaTrayectoScreen lo escuche sin abrir un segundo GPS.
  StreamSubscription<Position>? _driverGpsSub;
  final StreamController<Position> _driverPositionCtrl =
      StreamController<Position>.broadcast();

  Stream<Position> get driverPositionStream => _driverPositionCtrl.stream;

  // ── Streams GPS de pasajeros ─────────────────────────────────────────
  // Clave: passengerId. Cada pasajero tiene su propio stream.
  final Map<String, StreamSubscription<Position>> _passengerGpsSubs = {};

  // ── Permisos ─────────────────────────────────────────────────────────
  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      throw Exception('Permisos de ubicación requeridos');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // CONDUCTOR
  // ════════════════════════════════════════════════════════════════════

  /// Inicia el stream de GPS del conductor y sube posición a Firestore.
  /// También emite posiciones al broadcast [driverPositionStream] para
  /// que el mapa local no abra un segundo GPS.
  Future<void> startSharingLocation(String routeId) async {
    await _requestPermissions();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final routeDoc = await _db.collection('routes').doc(routeId).get();
    final routeData = routeDoc.data();
    if (routeData == null || routeData['driverId'] != user.uid) {
      throw Exception('Solo el conductor puede compartir ubicación');
    }

    await _driverGpsSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _driverGpsSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position position) {
          // 1. Emitir al broadcast (mapa local del conductor)
          if (!_driverPositionCtrl.isClosed) {
            _driverPositionCtrl.add(position);
          }

          // 2. Subir a Firestore con timestamp para detección de staleness
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
                // Ignorar si el documento fue eliminado mientras tanto
              });
        });
  }

  /// Detiene el GPS del conductor y limpia su posición en Firestore.
  /// No crashea si el documento de la ruta ya fue eliminado.
  Future<void> stopSharingLocation(String routeId) async {
    await _driverGpsSub?.cancel();
    _driverGpsSub = null;

    try {
      final doc = await _db.collection('routes').doc(routeId).get();
      if (doc.exists) {
        await doc.reference.update({'driverLocation': FieldValue.delete()});
      }
    } on FirebaseException catch (_) {
      // Documento eliminado entre el get y el update — ignorar.
    } catch (_) {
      // Cualquier otro error no debe propagar.
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // PASAJERO
  // ════════════════════════════════════════════════════════════════════

  /// El pasajero inicia su propio stream de GPS y sube su posición al
  /// campo `passengerLocations.{passengerId}` del documento de la ruta.
  /// El conductor puede leer ese campo en tiempo real para ver a todos
  /// los pasajeros en el mapa.
  Future<void> startSharingPassengerLocation({
    required String routeId,
    required String passengerId,
    required String passengerName,
    required String passengerInitials,
  }) async {
    await _requestPermissions();

    // Cancelar suscripción previa si el pasajero reabrió el mapa
    await _passengerGpsSubs[passengerId]?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // Solo actualizar si se movió > 15 m
    );

    _passengerGpsSubs[passengerId] =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          Position position,
        ) {
          // Dot-notation de Firestore permite actualizar un solo campo
          // del mapa sin sobreescribir los otros pasajeros.
          _db
              .collection('routes')
              .doc(routeId)
              .update({
                'passengerLocations.$passengerId': {
                  'lat': position.latitude,
                  'lng': position.longitude,
                  'updatedAt': FieldValue.serverTimestamp(),
                  'name': passengerName,
                  'initials': passengerInitials,
                },
              })
              .catchError((_) {
                // Ignorar si la ruta fue finalizada mientras el pasajero
                // todavía tenía el mapa abierto.
              });
        });
  }

  /// El pasajero deja de compartir y elimina su entrada en Firestore.
  Future<void> stopSharingPassengerLocation({
    required String routeId,
    required String passengerId,
  }) async {
    await _passengerGpsSubs[passengerId]?.cancel();
    _passengerGpsSubs.remove(passengerId);

    try {
      final doc = await _db.collection('routes').doc(routeId).get();
      if (doc.exists) {
        await doc.reference.update({
          'passengerLocations.$passengerId': FieldValue.delete(),
        });
      }
    } on FirebaseException catch (_) {
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════════
  // COMPARTIDO
  // ════════════════════════════════════════════════════════════════════

  /// Stream del documento completo de la ruta.
  /// ─ El pasajero lo usa para leer `driverLocation`.
  /// ─ El conductor lo usa para leer `passengerLocations`.
  Stream<DocumentSnapshot> getRouteStream(String routeId) {
    return _db.collection('routes').doc(routeId).snapshots();
  }

  // Alias para compatibilidad con el código anterior
  Stream<DocumentSnapshot> getDriverLocationStream(String routeId) =>
      getRouteStream(routeId);

  /// Obtiene la posición actual una sola vez (sin stream continuo).
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

  /// Libera todos los recursos. Llamar solo al destruir la app.
  void dispose() {
    _driverGpsSub?.cancel();
    for (final sub in _passengerGpsSubs.values) {
      sub.cancel();
    }
    _passengerGpsSubs.clear();
    _driverPositionCtrl.close();
  }
}
