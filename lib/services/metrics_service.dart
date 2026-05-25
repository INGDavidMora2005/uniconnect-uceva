import 'package:cloud_firestore/cloud_firestore.dart';

class MetricsService {
  static final MetricsService _instance = MetricsService._internal();
  factory MetricsService() => _instance;
  MetricsService._internal();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<int> totalUsuariosRegistrados() {
    return _db.collection('users').snapshots().map((snap) => snap.docs.length);
  }

  Stream<int> usuariosActivosUltimos7Dias() {
    return _db
        .collection('users')
        .where('lastActive',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))))
        .snapshots()
        .handleError((e) => 0)
        .map((snap) => snap.docs.length);
  }

  Stream<int> rutasPublicadasHoy() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _db
        .collection('routes')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> productosActivosEnBazar() {
    return _db
        .collection('products')
        .where('status', isEqualTo: 'Disponible')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> reportesPendientesDeRevision() {
    return _db
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}