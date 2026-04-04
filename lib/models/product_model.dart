import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String condition;
  final String contactMethod;
  final List<String> imageUrls;
  final String sellerId;
  final String sellerName;
  final String sellerInitials;
  final double sellerRating;
  final String sellerCareer;
  final String status;
  final DateTime? createdAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.condition,
    required this.contactMethod,
    required this.imageUrls,
    required this.sellerId,
    required this.sellerName,
    required this.sellerInitials,
    required this.sellerRating,
    required this.sellerCareer,
    this.status = 'Disponible',
    this.createdAt,
  });

  String get priceFormatted =>
      '\$${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      )}';

  Map<String, dynamic> toMap() => {
    'name':           name,
    'description':    description,
    'price':          price,
    'condition':      condition,
    'contactMethod':  contactMethod,
    'imageUrls':      imageUrls,
    'sellerId':       sellerId,
    'sellerName':     sellerName,
    'sellerInitials': sellerInitials,
    'sellerRating':   sellerRating,
    'sellerCareer':   sellerCareer,
    'status':         status,
    'createdAt':      FieldValue.serverTimestamp(),
  };

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id:             doc.id,
      name:           data['name'] ?? '',
      description:    data['description'] ?? '',
      price:          (data['price'] ?? 0).toDouble(),
      condition:      data['condition'] ?? '',
      contactMethod:  data['contactMethod'] ?? 'Whatsapp',
      imageUrls:      List<String>.from(data['imageUrls'] ?? []),
      sellerId:       data['sellerId'] ?? '',
      sellerName:     data['sellerName'] ?? '',
      sellerInitials: data['sellerInitials'] ?? '',
      sellerRating:   (data['sellerRating'] ?? 0.0).toDouble(),
      sellerCareer:   data['sellerCareer'] ?? '',
      status:         data['status'] ?? 'Disponible',
      createdAt:      (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}