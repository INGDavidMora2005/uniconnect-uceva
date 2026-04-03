import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_model.dart';

class RatingService {
  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;
  RatingService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── GUARDAR CALIFICACIÓN ──────────────────────────────────
  Future<String> submitRating(RatingModel rating) async {
    try {
      // 1. Guardar la calificación
      await _db.collection('ratings').add(rating.toMap());

      // 2. Actualizar el rating promedio del usuario calificado
      await _updateUserRating(rating.ratedUserId);

      return 'Calificación enviada exitosamente.';
    } catch (e) {
      return 'Error al enviar la calificación: ${e.toString()}';
    }
  }

  // ── ACTUALIZAR RATING PROMEDIO ────────────────────────────
  Future<void> _updateUserRating(String userId) async {
    try {
      final snapshot = await _db
          .collection('ratings')
          .where('ratedUserId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return;

      final total = snapshot.docs
          .map((d) => (d.data()['stars'] ?? 0).toDouble())
          .reduce((a, b) => a + b);

      final avg = total / snapshot.docs.length;

      await _db.collection('users').doc(userId).update({
        'rating': double.parse(avg.toStringAsFixed(1)),
      });
    } catch (e) {
      // Ignorar error en actualización de rating
    }
  }

  // ── VERIFICAR SI YA CALIFICÓ ──────────────────────────────
  Future<bool> hasRated(String raterId, String routeId) async {
    try {
      final snapshot = await _db
          .collection('ratings')
          .where('raterId', isEqualTo: raterId)
          .where('routeId', isEqualTo: routeId)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}