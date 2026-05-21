import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';
import '../services/cupo_service.dart';
import '../services/notification_service.dart';

class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  FirebaseFirestore? _dbInstance;
  FirebaseFirestore get _database => _dbInstance ?? FirebaseFirestore.instance;

  void setDatabase(FirebaseFirestore db) {
    _dbInstance = db;
  }

  Future<String> publishRoute(RouteModel route) async {
    try {
      await _database.collection('routes').add(route.toMap());
      return 'Ruta publicada exitosamente.';
    } catch (e) {
      return 'Error al publicar la ruta: $e';
    }
  }

  Stream<List<RouteModel>> getAvailableRoutes() {
    return _database
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
    return _database
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

  Stream<List<RouteModel>> getMyBookedRoutes(String passengerId) {
    return _database
        .collection('cupo_requests')
        .where('passengerId', isEqualTo: passengerId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((cupoSnap) async {
          final routeIds = cupoSnap.docs.map((doc) => doc.data()['routeId'] as String).toSet();
          if (routeIds.isEmpty) return [];

          final routesSnap = await _database.collection('routes')
              .where(FieldPath.documentId, whereIn: routeIds.toList())
              .get();

          return routesSnap.docs.map((doc) => RouteModel.fromFirestore(doc)).toList();
        });
  }

  Future<String> updateRouteStatus(String routeId, String newStatus) async {
    try {
      await _database.collection('routes').doc(routeId).update({'status': newStatus});
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
      final routeDoc = await _database.collection('routes').doc(routeId).get();
      if (!routeDoc.exists) return 'La ruta no existe.';
      final routeData = routeDoc.data() ?? {};
      final origin = (routeData['origin'] as String?) ?? '';
      final destination = (routeData['destination'] as String?) ?? '';
      final time = (routeData['time'] as String?) ?? '';
      final date = (routeData['date'] as String?) ?? '';
      final driverId = (routeData['driverId'] as String?) ?? '';

      // 2. Buscar pasajeros aceptados y notificarlos
      final acceptedRequests = await _database
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
        await _database.collection('users').doc(driverId).update({
          'tripsCompleted': FieldValue.increment(1),
        });
      }

      // 4. Borrar cupo_requests y la ruta
      await CupoService().deleteRequestsByRoute(routeId);
      await _database.collection('routes').doc(routeId).delete();

      return 'ok';
    } catch (e) {
      return 'Error al finalizar la ruta: $e';
    }
  }

  Future<String> deleteRoute(String routeId) async {
    try {
      await CupoService().deleteRequestsByRoute(routeId);
      await _database.collection('routes').doc(routeId).delete();
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
      final userDoc = await _database.collection('users').doc(passengerId).get();
      if (!userDoc.exists) return 'No se encontró tu perfil de usuario.';
      final passengerName =
          (userDoc.data()?['fullName'] as String?) ?? 'Pasajero';

      final routeDoc = await _database.collection('routes').doc(routeId).get();
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

  Future<String> updateRoute({
    required String routeId,
    required String time,
    required int availableSeats,
    required double price,
  }) async {
    try {
      await _database.collection('routes').doc(routeId).update({
        'time': time,
        'availableSeats': availableSeats,
        'totalSeats': availableSeats,
        'price': price,
      });
      return 'ok';
    } catch (e) {
      return 'Error al actualizar la ruta: $e';
    }
  }

  Future<String> cancelRoute({
    required String routeId,
    required String origin,
    required String destination,
  }) async {
    try {
      final acceptedRequests = await _database
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
          title: 'Ruta cancelada',
          body: 'El conductor canceló la ruta $origin → $destination.',
          type: 'route_cancelled',
          extra: {
            'routeId': routeId,
            'origin': origin,
            'destination': destination,
          },
        );
      }

      for (final doc in acceptedRequests.docs) {
        await doc.reference.update({'status': 'cancelled'});
      }

      await _database.collection('routes').doc(routeId).update({
        'status': 'Cancelada',
      });

      return 'ok';
    } catch (e) {
      return 'Error al cancelar la ruta: $e';
    }
  }
}
