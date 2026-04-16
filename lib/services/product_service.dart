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

  Stream<List<ProductModel>> getMyProducts(String sellerId) {
    return _db
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
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

  Future<String> updateProduct(ProductModel product) async {
    try {
      await _db.collection('products').doc(product.id).update(product.toMap());
      return 'ok';
    } catch (e) {
      return 'Error al actualizar el producto: $e';
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

  // ── UU-20: CERRAR TRANSACCIÓN ────────────────────────────────────────────
  /// Cambia el estado de un producto entre 'Disponible' y 'Vendido'.
  /// Retorna 'ok' si fue exitoso o un mensaje de error.
  Future<String> updateProductStatus(
    String productId,
    String newStatus,
  ) async {
    try {
      await _db.collection('products').doc(productId).update({
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
      return 'ok';
    } catch (e) {
      return 'Error al actualizar el estado del producto: $e';
    }
  }
}