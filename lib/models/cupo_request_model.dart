import 'package:cloud_firestore/cloud_firestore.dart';

class CupoRequestModel {
  final String id;
  final String routeId;
  final String passengerId;
  final String passengerName;
  final String driverId;
  final String message;
  final String status; // 'pending', 'accepted', 'rejected'
  final String origin;
  final String destination;
  final String time;
  final DateTime createdAt;

  const CupoRequestModel({
    required this.id,
    required this.routeId,
    required this.passengerId,
    required this.passengerName,
    required this.driverId,
    required this.message,
    required this.status,
    required this.origin,
    required this.destination,
    required this.time,
    required this.createdAt,
  });

  factory CupoRequestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CupoRequestModel(
      id:            doc.id,
      routeId:       d['routeId'] ?? '',
      passengerId:   d['passengerId'] ?? '',
      passengerName: d['passengerName'] ?? '',
      driverId:      d['driverId'] ?? '',
      message:       d['message'] ?? '',
      status:        d['status'] ?? 'pending',
      origin:        d['origin'] ?? '',
      destination:   d['destination'] ?? '',
      time:          d['time'] ?? '',
      createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'routeId':       routeId,
    'passengerId':   passengerId,
    'passengerName': passengerName,
    'driverId':      driverId,
    'message':       message,
    'status':        status,
    'origin':        origin,
    'destination':   destination,
    'time':          time,
    'createdAt':     FieldValue.serverTimestamp(),
  };
}