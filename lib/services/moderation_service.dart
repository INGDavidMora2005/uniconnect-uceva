import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/report_model.dart';
import 'notification_service.dart';

class ModerationService {
  static final ModerationService _instance = ModerationService._internal();
  factory ModerationService() => _instance;
  ModerationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ReportModel>> getReports() {
    return _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ReportModel.fromMap({'id': doc.id, ...doc.data()}))
              .toList(),
        );
  }

  Future<List<ReportModel>> getReportsOnce() async {
    final snap = await _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => ReportModel.fromMap({'id': doc.id, ...doc.data()}))
        .toList();
  }

  Future<void> submitReport({
    required ReportType type,
    required String targetId,
    required String targetName,
    required String reason,
    String? description,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final existing = await _db
        .collection('reports')
        .where('reportedByUserId', isEqualTo: uid)
        .where('targetId', isEqualTo: targetId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Ya tienes un reporte pendiente sobre este contenido.');
    }

    final userSnap = await _db.collection('users').doc(uid).get();
    final userName = userSnap.data()?['fullName'] ?? 'Usuario';

    await _db.collection('reports').add({
      'type': type == ReportType.user ? 'user' : 'publication',
      'targetId': targetId,
      'targetName': targetName,
      'reportedByUserId': uid,
      'reportedByName': userName,
      'reason': reason,
      'description': description ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await NotificationService().saveNotification(
      toUserId: uid,
      title: 'Reporte recibido',
      body:
          'Hemos recibido tu reporte sobre "$targetName". Nuestro equipo lo revisará en 24 a 72 horas.',
      type: 'moderation',
    );
  }

  Future<void> deletePublicationFromReport(
    String reportId,
    String productId,
    String reason,
  ) async {
    final productDoc = await _db.collection('products').doc(productId).get();
    final sellerId = productDoc.data()?['sellerId'] ?? '';
    final productName = productDoc.data()?['name'] ?? 'tu publicación';

    await _db.collection('products').doc(productId).delete();

    final reportDoc = await _db.collection('reports').doc(reportId).get();
    final reportedByUserId = reportDoc.data()?['reportedByUserId'] ?? '';

    await _db.collection('reports').doc(reportId).update({
      'status': 'reviewed',
    });

    if (sellerId.isNotEmpty) {
      await NotificationService().saveNotification(
        toUserId: sellerId,
        title: 'Publicación retirada',
        body:
            'Tu publicación "$productName" fue retirada por: $reason. Si crees que es un error, contacta al administrador.',
        type: 'moderation',
      );
    }

    if (reportedByUserId.isNotEmpty) {
      await NotificationService().saveNotification(
        toUserId: reportedByUserId,
        title: 'Reporte resuelto ✓',
        body:
            'Tu reporte sobre "$productName" fue revisado. La publicación fue eliminada por incumplir las normas de UniConnect.',
        type: 'moderation',
      );
    }
  }

  Future<void> deleteRouteFromReport(
    String reportId,
    String routeId,
    String reason,
  ) async {
    final routeDoc = await _db.collection('routes').doc(routeId).get();
    final driverId = routeDoc.data()?['driverId'] ?? '';
    final origin = routeDoc.data()?['origin'] ?? 'la ruta';
    final destination = routeDoc.data()?['destination'] ?? '';
    final routeName = '$origin → $destination';

    await _db.collection('routes').doc(routeId).delete();

    final reportDoc = await _db.collection('reports').doc(reportId).get();
    final reportedByUserId = reportDoc.data()?['reportedByUserId'] ?? '';

    await _db.collection('reports').doc(reportId).update({
      'status': 'reviewed',
    });

    if (driverId.isNotEmpty) {
      await NotificationService().saveNotification(
        toUserId: driverId,
        title: 'Ruta retirada',
        body:
            'Tu ruta "$routeName" została retirada por: $reason. Si crees que es un error, contacta al administrador.',
        type: 'moderation',
      );
    }

    if (reportedByUserId.isNotEmpty) {
      await NotificationService().saveNotification(
        toUserId: reportedByUserId,
        title: 'Reporte resuelto ✓',
        body:
            'Tu reporte sobre "$routeName" fue revisado. La ruta fue eliminada por incumplir las normas de UniConnect.',
        type: 'moderation',
      );
    }
  }

  Future<void> suspendUser(
    String reportId,
    String userId,
    String userName,
  ) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('Usuario no encontrado: $userId');
    }

    await _db.collection('users').doc(userId).update({
      'suspended': true,
      'suspendedAt': FieldValue.serverTimestamp(),
    });

    final productsSnap = await _db
        .collection('products')
        .where('sellerId', isEqualTo: userId)
        .where('status', isEqualTo: 'Disponible')
        .get();

    final batch = _db.batch();
    for (final doc in productsSnap.docs) {
      batch.update(doc.reference, {'status': 'Suspendido'});
    }
    await batch.commit();

    final routesSnap = await _db
        .collection('routes')
        .where('driverId', isEqualTo: userId)
        .get();

    final routesBatch = _db.batch();
    for (final doc in routesSnap.docs) {
      final routeStatus = doc.data()['status'] ?? '';
      if (routeStatus != 'Finalizada') {
        routesBatch.delete(doc.reference);
      }
    }
    await routesBatch.commit();

    await _db.collection('reports').doc(reportId).update({
      'status': 'reviewed',
    });

    await NotificationService().saveNotification(
      toUserId: userId,
      title: 'Cuenta suspendida',
      body:
          'Tu cuenta ha sido suspendida por violar las políticas de uso. Contacta al administrador para más información.',
      type: 'moderation',
    );
  }

  Future<void> unsuspendUser(String targetUserId) async {
    await _db.collection('users').doc(targetUserId).update({
      'suspended': false,
      'suspendedAt': FieldValue.delete(),
    });

    final productsSnap = await _db
        .collection('products')
        .where('sellerId', isEqualTo: targetUserId)
        .where('status', isEqualTo: 'Suspendido')
        .get();

    final batch = _db.batch();
    for (final doc in productsSnap.docs) {
      batch.update(doc.reference, {'status': 'Disponible'});
    }
    await batch.commit();
  }

  Future<void> dismissReport(String reportId) async {
    await _db.collection('reports').doc(reportId).update({
      'status': 'reviewedNoAction',
    });
  }

  Future<int> getPendingReportsCountForUser(String userId) async {
    final snap = await _db
        .collection('reports')
        .where('targetId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.length;
  }

  Future<void> deleteReport(String reportId) async {
    await _db.collection('reports').doc(reportId).delete();
  }
}
