import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Future<List<ProductModel>> getMyProductsOnce(String sellerId) async {
    final snap = await _db
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
        .get();
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
  }

  Future<List<ProductModel>> getAllProductsOnce() async {
    final snap = await _db.collection('products').get();
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

  Future<String> updateProductStatus(String productId, String newStatus) async {
    try {
      final productDoc = _db.collection('products').doc(productId);
      final productSnap = await productDoc.get();

      if (!productSnap.exists) {
        return 'Producto no encontrado.';
      }

      final data = productSnap.data()!;
      final currentStatus = data['status'] as String?;
      final sellerId = data['sellerId'] as String?;

      if (currentStatus != 'Vendido' &&
          newStatus == 'Vendido' &&
          sellerId != null) {
        await _db.runTransaction((transaction) async {
          transaction.update(_db.collection('users').doc(sellerId), {
            'bazarPurchases': FieldValue.increment(1),
          });
          transaction.update(productDoc, {
            'status': newStatus,
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        await productDoc.update({
          'status': newStatus,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      return 'ok';
    } catch (e) {
      return 'Error al actualizar el estado del producto: $e';
    }
  }

  Future<String> duplicateProduct(ProductModel product) async {
    try {
      final sellerDoc = await _db
          .collection('users')
          .doc(product.sellerId)
          .get();
      final sellerData = sellerDoc.data() ?? {};
      final currentRating = (sellerData['rating'] ?? product.sellerRating)
          .toDouble();
      final currentPhone = sellerData['phone'] ?? product.sellerPhone;

      final newProduct = ProductModel(
        id: '',
        name: product.name,
        description: product.description,
        price: product.price,
        category: product.category,
        contactMethod: product.contactMethod,
        imageUrls: product.imageUrls,
        sellerId: product.sellerId,
        sellerName: product.sellerName,
        sellerInitials: product.sellerInitials,
        sellerRating: currentRating,
        sellerCareer: product.sellerCareer,
        sellerPhone: currentPhone,
        status: 'Disponible',
        createdAt: DateTime.now(),
      );

      await _db.collection('products').add(newProduct.toMap());
      return 'ok';
    } catch (e) {
      return 'Error al duplicar el producto: ${e.toString()}';
    }
  }
}
