import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';
import '../services/cupo_service.dart';
import '../services/notification_service.dart';

class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> publishRoute(RouteModel route) async {
    try {
      await _db.collection('routes').add(route.toMap());
      return 'Ruta publicada exitosamente.';
    } catch (e) {
      return 'Error al publicar la ruta: $e';
    }
  }

  Stream<List<RouteModel>> getAvailableRoutes() {
    return _db
        .collection('routes')
        .where(
          'status',
          whereIn: [
            RouteStatus.activa,
            RouteStatus.disponible,
            RouteStatus.enCurso,
            RouteStatus.llena,
          ],
        )
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => RouteModel.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<RouteModel>> getMyRoutes(String driverId) {
    return _db
        .collection('routes')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snap) {
          final routes = snap.docs
              .map((doc) => RouteModel.fromFirestore(doc))
              .toList();
          routes.sort((a, b) => b.id.compareTo(a.id));
          return routes;
        });
  }

  Future<String> updateRouteStatus(String routeId, String newStatus) async {
    try {
      await _db.collection('routes').doc(routeId).update({'status': newStatus});
      return 'ok';
    } catch (e) {
      return 'Error al actualizar el estado: $e';
    }
  }

  Future<String> startRoute(String routeId) =>
      updateRouteStatus(routeId, RouteStatus.enCurso);

  /// Finaliza la ruta:
  /// 1. Notifica a pasajeros aceptados para calificar
  /// 2. Suma +1 a tripsCompleted del conductor
  /// 3. Borra cupo_requests
  /// 4. Borra la ruta
  Future<String> finalizeRoute(String routeId) async {
    try {
      // 1. Obtener datos de la ruta
      final routeDoc = await _db.collection('routes').doc(routeId).get();
      if (!routeDoc.exists) return 'La ruta no existe.';
      final routeData = routeDoc.data() ?? {};
      final origin = (routeData['origin'] as String?) ?? '';
      final destination = (routeData['destination'] as String?) ?? '';
      final time = (routeData['time'] as String?) ?? '';
      final date = (routeData['date'] as String?) ?? '';
      final driverId = (routeData['driverId'] as String?) ?? '';

      // 2. Buscar pasajeros aceptados y notificarlos
      final acceptedRequests = await _db
          .collection('cupo_requests')
          .where('routeId', isEqualTo: routeId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (final doc in acceptedRequests.docs) {
        final data = doc.data();
        final passengerId = (data['passengerId'] as String?) ?? '';
        if (passengerId.isEmpty) continue;

        await NotificationService().saveNotification(
          toUserId: passengerId,
          title: '¿Cómo fue tu viaje?',
          body:
              'Califica tu experiencia en la ruta $origin → $destination · $date $time',
          type: 'rate_trip',
          extra: {
            'routeId': routeId,
            'origin': origin,
            'destination': destination,
            'time': time,
            'date': date,
            'driverName': (routeData['driverName'] as String?) ?? '',
            'driverInitials': (routeData['driverInitials'] as String?) ?? '',
            'driverRating': (routeData['driverRating'] ?? 0.0),
            'driverId': driverId,
            'price': (routeData['price'] ?? 0.0),
            'totalSeats': (routeData['totalSeats'] ?? 4),
            'meetingPoint': (routeData['meetingPoint'] as String?) ?? '',
          },
        );
      }

      // 3. Sumar +1 a tripsCompleted del conductor
      if (driverId.isNotEmpty) {
        await _db.collection('users').doc(driverId).update({
          'tripsCompleted': FieldValue.increment(1),
        });
      }

      // 4. Borrar cupo_requests y la ruta
      await CupoService().deleteRequestsByRoute(routeId);
      await _db.collection('routes').doc(routeId).delete();

      return 'ok';
    } catch (e) {
      return 'Error al finalizar la ruta: $e';
    }
  }

  Future<String> deleteRoute(String routeId) async {
    try {
      await CupoService().deleteRequestsByRoute(routeId);
      await _db.collection('routes').doc(routeId).delete();
      return 'ok';
    } catch (e) {
      return 'Error al eliminar la ruta: $e';
    }
  }

  Future<String> requestSeatDelegated({
    required String routeId,
    required String passengerId,
    required String message,
  }) async {
    try {
      final userDoc = await _db.collection('users').doc(passengerId).get();
      if (!userDoc.exists) return 'No se encontró tu perfil de usuario.';
      final passengerName =
          (userDoc.data()?['fullName'] as String?) ?? 'Pasajero';

      final routeDoc = await _db.collection('routes').doc(routeId).get();
      if (!routeDoc.exists) return 'La ruta no existe.';
      final data = routeDoc.data() ?? {};

      final driverId = (data['driverId'] as String?) ?? '';
      if (driverId.isEmpty) return 'La ruta no tiene conductor asignado.';

      final routeStatus = (data['status'] as String?) ?? RouteStatus.activa;
      if (routeStatus == RouteStatus.finalizada) {
        return 'Esta ruta ya ha finalizado.';
      }
      if (routeStatus == RouteStatus.llena) {
        return 'Esta ruta ya no tiene cupos disponibles.';
      }

      final wasRejected = await CupoService().hasRejectedRequest(
        passengerId,
        routeId,
      );
      if (wasRejected) {
        return 'Tu solicitud fue rechazada para esta ruta.';
      }

      final result = await CupoService().requestSeat(
        routeId: routeId,
        passengerId: passengerId,
        passengerName: passengerName,
        driverId: driverId,
        message: message,
        origin: (data['origin'] as String?) ?? '',
        destination: (data['destination'] as String?) ?? '',
        time: (data['time'] as String?) ?? '',
      );

      return result;
    } catch (e) {
      return 'Error al procesar la solicitud: $e';
    }
  }
}
