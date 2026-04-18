import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String routeId;
  final String raterId;
  final String raterName;
  final String raterInitials;
  final String ratedUserId;
  final double stars;
  final List<String> tags;
  final String comment;
  final String routeDescription;

  // ── UU-20: campos adicionales para calificaciones del bazar ──────────────
  /// Tipo de calificación: 'ruta' (por defecto) o 'bazar'
  final String ratingType;

  /// ID del producto vendido (solo aplica cuando ratingType == 'bazar')
  final String? productId;

  /// Nombre del producto (solo aplica cuando ratingType == 'bazar')
  final String? productName;

  const RatingModel({
    required this.id,
    required this.routeId,
    required this.raterId,
    required this.raterName,
    required this.raterInitials,
    required this.ratedUserId,
    required this.stars,
    required this.tags,
    required this.comment,
    required this.routeDescription,
    this.ratingType = 'ruta',
    this.productId,
    this.productName,
  });

  Map<String, dynamic> toMap() => {
    'routeId':          routeId,
    'raterId':          raterId,
    'raterName':        raterName,
    'raterInitials':    raterInitials,
    'ratedUserId':      ratedUserId,
    'stars':            stars,
    'tags':             tags,
    'comment':          comment,
    'routeDescription': routeDescription,
    'ratingType':       ratingType,
    if (productId != null) 'productId': productId,
    if (productName != null) 'productName': productName,
    'createdAt':        FieldValue.serverTimestamp(),
  };

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RatingModel(
      id:               doc.id,
      routeId:          data['routeId'] ?? '',
      raterId:          data['raterId'] ?? '',
      raterName:        data['raterName'] ?? '',
      raterInitials:    data['raterInitials'] ?? '',
      ratedUserId:      data['ratedUserId'] ?? '',
      stars:            (data['stars'] ?? 0).toDouble(),
      tags:             List<String>.from(data['tags'] ?? []),
      comment:          data['comment'] ?? '',
      routeDescription: data['routeDescription'] ?? '',
      ratingType:       data['ratingType'] ?? 'ruta',
      productId:        data['productId'],
      productName:      data['productName'],
    );
  }
}