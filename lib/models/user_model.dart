import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String studentCode;
  final String role;
  final String faculty;
  final String description;
  final double rating;
  final int tripsCompleted;
  final int bazarPurchases;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.studentCode,
    required this.role,
    this.faculty = '',
    this.description = '',
    this.rating = 0.0,
    this.tripsCompleted = 0,
    this.bazarPurchases = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] ?? '',
        fullName: map['fullName'] ?? '',
        email: map['email'] ?? '',
        studentCode: map['studentCode'] ?? '',
        role: map['role'] ?? '',
        faculty: map['faculty'] ?? '',
        description: map['description'] ?? '',
        rating: (map['rating'] ?? 0.0).toDouble(),
        tripsCompleted: map['tripsCompleted'] ?? 0,
        bazarPurchases: map['bazarPurchases'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'studentCode': studentCode,
        'role': role,
        'faculty': faculty,
        'description': description,
        'rating': rating,
        'tripsCompleted': tripsCompleted,
        'bazarPurchases': bazarPurchases,
        'createdAt': FieldValue.serverTimestamp(),
      };

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  String get firstName {
    return fullName.trim().split(' ').first;
  }
}