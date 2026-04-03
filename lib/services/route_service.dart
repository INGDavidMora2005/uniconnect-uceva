import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';
import '../services/cupo_service.dart';

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

  Future<String> finalizeRoute(String routeId) =>
    deleteRoute(routeId);

  Future<String> deleteRoute(String routeId) async {
    try {
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
