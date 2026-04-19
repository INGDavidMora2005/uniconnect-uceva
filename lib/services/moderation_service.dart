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
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
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
}
