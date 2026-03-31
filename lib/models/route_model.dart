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
  });

  bool get isFull => availableSeats == 0;

  String get priceFormatted =>
      '\$${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}