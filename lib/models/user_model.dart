class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String studentCode;
  final String role;
  final String faculty;
  final double rating;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.studentCode,
    required this.role,
    this.faculty = '',
    this.rating = 0.0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id:          map['id'] ?? '',
    fullName:    map['fullName'] ?? '',
    email:       map['email'] ?? '',
    studentCode: map['studentCode'] ?? '',
    role:        map['role'] ?? '',
    faculty:     map['faculty'] ?? '',
    rating:      (map['rating'] ?? 0.0).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'id':          id,
    'fullName':    fullName,
    'email':       email,
    'studentCode': studentCode,
    'role':        role,
    'faculty':     faculty,
    'rating':      rating,
  };
}