import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.status = 'Activa',
  });

  bool get isFull => availableSeats == 0;

  String get priceFormatted =>
      '\$${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      )}';

  // ── Guardar en Firestore ─
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
    'status':         status,
    'createdAt':      FieldValue.serverTimestamp(),
  };

  // ── Leer desde Firestore ───────────────────────────────────
  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RouteModel(
      id:             doc.id,
      origin:         data['origin'] ?? '',
      destination:    data['destination'] ?? '',
      date:           data['date'] ?? '',
      time:           data['time'] ?? '',
      price:          (data['price'] ?? 0).toDouble(),
      availableSeats: data['availableSeats'] ?? 0,
      totalSeats:     data['totalSeats'] ?? 4,
      driverName:     data['driverName'] ?? '',
      driverInitials: data['driverInitials'] ?? '',
      driverRating:   (data['driverRating'] ?? 0.0).toDouble(),
      meetingPoint:   data['meetingPoint'] ?? '',
      note:           data['note'],
      driverId:       data['driverId'],
      status:         data['status'] ?? 'Activa',
    );
  }
}