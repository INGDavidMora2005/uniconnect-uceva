import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String routeId;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final String driverName;
  final String origin;
  final String destination;
  final bool isClosed;
  final DateTime? closedAt;
  final DateTime createdAt;
  final bool adminVisible; // siempre true

  const ChatModel({
    required this.id,
    required this.routeId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    required this.driverName,
    required this.origin,
    required this.destination,
    this.isClosed = false,
    this.closedAt,
    required this.createdAt,
    this.adminVisible = true,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id:            doc.id,
      routeId:       d['routeId'] ?? '',
      driverId:      d['driverId'] ?? '',
      passengerId:   d['passengerId'] ?? '',
      passengerName: d['passengerName'] ?? '',
      driverName:    d['driverName'] ?? '',
      origin:        d['origin'] ?? '',
      destination:   d['destination'] ?? '',
      isClosed:      d['isClosed'] ?? false,
      closedAt:      (d['closedAt'] as Timestamp?)?.toDate(),
      createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      adminVisible:  d['adminVisible'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'routeId':         routeId,
    'driverId':        driverId,
    'passengerId':     passengerId,
    'passengerName':   passengerName,
    'driverName':      driverName,
    'origin':          origin,
    'destination':     destination,
    'isClosed':        isClosed,
    'closedAt':        closedAt,
    'createdAt':       FieldValue.serverTimestamp(),
    'adminVisible':    adminVisible,
  };
}

class MessageModel {
  final String id;
  final String senderId;
  final String text; // máx 500 chars
  final DateTime sentAt;
  final String status; // 'sent' | 'received' | 'read'

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.status = 'sent',
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id:        doc.id,
      senderId:  d['senderId'] ?? '',
      text:      d['text'] ?? '',
      sentAt:    (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status:    d['status'] ?? 'sent',
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId':  senderId,
    'text':      text,
    'sentAt':    FieldValue.serverTimestamp(),
    'status':    status,
  };
}