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
    );
  }
}