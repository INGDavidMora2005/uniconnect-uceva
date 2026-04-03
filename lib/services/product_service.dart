import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final _db = FirebaseFirestore.instance;

  Stream<List<ProductModel>> getProducts() {
    return _db
        .collection('products')
        .where('status', isEqualTo: 'Disponible')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });
          return list;
        });
  }

  Future<String> publishProduct(ProductModel product) async {
    try {
      await _db.collection('products').add(product.toMap());
      return 'ok';
    } catch (e) {
      return 'Error al publicar el producto: $e';
    }
  }

  Future<String> deleteProduct(String productId) async {
    try {
      await _db.collection('products').doc(productId).delete();
      return 'ok';
    } catch (e) {
      return 'Error al eliminar el producto: $e';
    }
  }
}