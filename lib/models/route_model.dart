import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Constantes de estado ───────────────────────────────────────
// Úsalas siempre en lugar de strings literales para evitar typos.
class RouteStatus {
  static const String activa      = 'Activa';
  static const String disponible  = 'Disponible';
  static const String enCurso     = 'En curso';
  static const String llena       = 'Llena';
  static const String finalizada  = 'Finalizada';
}

class RouteModel {
  final String id;
  final String origin;
  final String destination;
  final String date;
  final String time;
  final double price;
  final int availableSeats;
  final int totalSeats;
  final String driverName;
  final String driverInitials;
  final double driverRating;
  final String meetingPoint;
  final String? note;
  final String? driverId;
  final String status;

  const RouteModel({
    required this.id,
    required this.origin,
    required this.destination,
    required this.date,
    required this.time,
    required this.price,
    required this.availableSeats,
    required this.totalSeats,
    required this.driverName,
    required this.driverInitials,
    required this.driverRating,
    required this.meetingPoint,
    this.note,
    this.driverId,
    this.status = RouteStatus.activa,
  });

  // ── Helpers de estado ────────────────────────────────────────

  bool get isFull => availableSeats <= 0;

  /// Etiqueta legible para el badge de estado.
  String get statusLabel {
    if (isFull && status == RouteStatus.activa) return 'Llena';
    switch (status) {
      case RouteStatus.enCurso:
        return 'En curso';
      case RouteStatus.finalizada:
        return 'Finalizada';
      case RouteStatus.llena:
        return 'Llena';
      case RouteStatus.disponible:
        return 'Disponible';
      case RouteStatus.activa:
      default:
        return 'Disponible';
    }
  }

  /// Color del badge de estado.
  Color get statusColor {
    if (isFull && status == RouteStatus.activa) return const Color(0xFFE53E3E);
    switch (status) {
      case RouteStatus.enCurso:
        return const Color(0xFF3182CE);   // azul
      case RouteStatus.finalizada:
        return const Color(0xFF718096);   // gris
      case RouteStatus.llena:
        return const Color(0xFFE53E3E);   // rojo
      case RouteStatus.disponible:
      case RouteStatus.activa:
      default:
        return const Color(0xFF38A169);   // verde
    }
  }

  /// Color de fondo del badge (versión suave).
  Color get statusBackgroundColor => statusColor.withOpacity(0.12);

  // ── Precio formateado ────────────────────────────────────────
  String get priceFormatted =>
      '\$${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      )}';

  // ── Serialización ────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'origin':         origin,
    'destination':    destination,
    'date':           date,
    'time':           time,
    'price':          price,
    'availableSeats': availableSeats,
    'totalSeats':     totalSeats,
    'driverName':     driverName,
    'driverInitials': driverInitials,
    'driverRating':   driverRating,
    'meetingPoint':   meetingPoint,
    'note':           note ?? '',
    'driverId':       driverId ?? '',
    // Si todos los cupos están ocupados, guardar como Llena automáticamente
    'status':         isFull ? RouteStatus.llena : status,
    'createdAt':      FieldValue.serverTimestamp(),
  };

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final seats = data['availableSeats'] ?? 0;
    // Sincronizar status con cupos: si no hay cupos, forzar Llena
    String statusFromDb = data['status'] ?? RouteStatus.activa;
    if (seats <= 0 &&
        statusFromDb != RouteStatus.enCurso &&
        statusFromDb != RouteStatus.finalizada) {
      statusFromDb = RouteStatus.llena;
    }
    return RouteModel(
      id:             doc.id,
      origin:         data['origin'] ?? '',
      destination:    data['destination'] ?? '',
      date:           data['date'] ?? '',
      time:           data['time'] ?? '',
      price:          (data['price'] ?? 0).toDouble(),
      availableSeats: seats as int,
      totalSeats:     data['totalSeats'] ?? 4,
      driverName:     data['driverName'] ?? '',
      driverInitials: data['driverInitials'] ?? '',
      driverRating:   (data['driverRating'] ?? 0.0).toDouble(),
      meetingPoint:   data['meetingPoint'] ?? '',
      note:           data['note'],
      driverId:       data['driverId'],
      status:         statusFromDb,
    );
  }

  /// Crea una copia con campos modificados.
  RouteModel copyWith({
    String? id,
    String? origin,
    String? destination,
    String? date,
    String? time,
    double? price,
    int? availableSeats,
    int? totalSeats,
    String? driverName,
    String? driverInitials,
    double? driverRating,
    String? meetingPoint,
    String? note,
    String? driverId,
    String? status,
  }) {
    return RouteModel(
      id:             id ?? this.id,
      origin:         origin ?? this.origin,
      destination:    destination ?? this.destination,
      date:           date ?? this.date,
      time:           time ?? this.time,
      price:          price ?? this.price,
      availableSeats: availableSeats ?? this.availableSeats,
      totalSeats:     totalSeats ?? this.totalSeats,
      driverName:     driverName ?? this.driverName,
      driverInitials: driverInitials ?? this.driverInitials,
      driverRating:   driverRating ?? this.driverRating,
      meetingPoint:   meetingPoint ?? this.meetingPoint,
      note:           note ?? this.note,
      driverId:       driverId ?? this.driverId,
      status:         status ?? this.status,
    );
  }
}