import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';

class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── PUBLICAR RUTA ─────────────────────────────────────────
  Future<String> publishRoute(RouteModel route) async {
    try {
      await _db.collection('routes').add(route.toMap());
      return 'Ruta publicada exitosamente.';
    } catch (e) {
      return 'Error al publicar la ruta: ${e.toString()}';
    }
  }

  // ── OBTENER RUTAS DISPONIBLES ─────────────────────────────
  Stream<List<RouteModel>> getAvailableRoutes() {
    return _db
        .collection('routes')
        .where('status', isEqualTo: 'Activa')
        .snapshots()
        .map((snapshot) {
          final routes = snapshot.docs
              .map((doc) => RouteModel.fromFirestore(doc))
              .toList();
          // Ordenar localmente por fecha de creación (más recientes primero)
          return routes;
        });
  }

  // ── OBTENER MIS RUTAS ─────────────────────────────────────
  Stream<List<RouteModel>> getMyRoutes(String driverId) {
    return _db
        .collection('routes')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RouteModel.fromFirestore(doc))
            .toList());
  }
}