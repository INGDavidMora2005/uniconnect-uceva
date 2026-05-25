import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HistorialBazarTab extends StatefulWidget {
  final String uid;

  const HistorialBazarTab({Key? key, required this.uid}) : super(key: key);

  @override
  State<HistorialBazarTab> createState() => _HistorialBazarTabState();
}

class _HistorialBazarTabState extends State<HistorialBazarTab> {
  static const int _pageSize = 20;
  final List<_TransaccionItem> _transacciones = [];
  bool _isLoading = false;
  bool _hasError = false;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocVentas;
  DocumentSnapshot? _lastDocCompras;
  bool _hasMoreVentas = true;
  bool _hasMoreCompras = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final results = await Future.wait([
        _fetchVentasPage(),
        _fetchComprasPage(),
      ]);

      if (!mounted) return;

      final combined = <_TransaccionItem>[
        ...results[0].items,
        ...results[1].items,
      ];
      combined.sort((a, b) => _compareTimestamp(b.createdAt, a.createdAt));

      setState(() {
        _transacciones
          ..clear()
          ..addAll(combined);
        _lastDocVentas = results[0].lastDoc;
        _lastDocCompras = results[1].lastDoc;
        _hasMoreVentas = results[0].hasMore;
        _hasMoreCompras = results[1].hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

Future<void> _loadMoreData() async {
    if (!mounted || _isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _hasError = false;
    });

    try {
      final ventasFuture = _hasMoreVentas
          ? _fetchVentasPage(startAfter: _lastDocVentas)
          : Future.value(_FetchResult<_TransaccionItem>.empty());
      final comprasFuture = _hasMoreCompras
          ? _fetchComprasPage(startAfter: _lastDocCompras)
          : Future.value(_FetchResult<_TransaccionItem>.empty());

      final results = await Future.wait<_FetchResult<_TransaccionItem>>([
        ventasFuture,
        comprasFuture,
      ]);

      if (!mounted) return;

      final newItems = <_TransaccionItem>[
        ...results[0].items,
        ...results[1].items,
      ];

      setState(() {
        _transacciones.addAll(newItems);
        _transacciones.sort((a, b) => _compareTimestamp(b.createdAt, a.createdAt));
        _lastDocVentas = results[0].lastDoc ?? _lastDocVentas;
        _lastDocCompras = results[1].lastDoc ?? _lastDocCompras;
        _hasMoreVentas = results[0].hasMore;
        _hasMoreCompras = results[1].hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _hasError = true;
      });
    }
  }

  Future<_FetchResult<_TransaccionItem>> _fetchVentasPage({DocumentSnapshot? startAfter}) async {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: widget.uid)
        .where('status', isEqualTo: 'Vendido')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => _TransaccionItem.fromDoc(doc, uid: widget.uid))
        .toList();
    return _FetchResult(
      items: items,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == _pageSize,
    );
  }

  Future<_FetchResult<_TransaccionItem>> _fetchComprasPage({DocumentSnapshot? startAfter}) async {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('buyerId', isEqualTo: widget.uid)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => _TransaccionItem.fromDoc(doc, uid: widget.uid))
        .toList();
    return _FetchResult(
      items: items,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == _pageSize,
    );
  }

  bool get _hasMore => _hasMoreVentas || _hasMoreCompras;

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _transacciones.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentGreen),
      );
    }

    if (_hasError) {
      return Center(
        child: Text(
          'Error al cargar transacciones. Intente nuevamente.',
          style: TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }

    if (_transacciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 56, color: AppColors.borderDefault),
            const SizedBox(height: 12),
            Text(
              'No tienes transacciones en el bazar',
              style: TextStyle(color: AppColors.textMedium, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Aquí aparecerán tus compras y ventas.',
              style: TextStyle(color: AppColors.textLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transacciones.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _transacciones.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: OutlinedButton(
                onPressed: _isLoadingMore ? null : _loadMoreData,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentGreen,
                  side: const BorderSide(color: AppColors.accentGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cargar más'),
              ),
            ),
          );
        }

        final item = _transacciones[index];
        final data = item.data;
        final isVenta = item.isVenta;
        final productName = (data['name'] ?? data['title'] ?? data['productName'] ?? 'Producto sin nombre').toString();
        final status = (data['status'] ?? 'Disponible').toString();
        final fecha = item.createdAt != null
          ? item.createdAt!.toDate().toString().split(' ')[0]
          : '';
        final buyerName = (data['buyerName'] ?? 'No disponible').toString();
        final sellerName = (data['sellerName'] ?? '-').toString();

        return Card(
          color: AppColors.backgroundWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.borderDefault, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accentGreen.withValues(alpha: 0.12),
                  child: Icon(
                    isVenta ? Icons.sell_outlined : Icons.shopping_bag_outlined,
                    color: AppColors.accentGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isVenta
                              ? AppColors.accentGreen.withValues(alpha: 0.12)
                              : const Color(0xFF3182CE).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isVenta ? 'Venta' : 'Compra',
                          style: TextStyle(
                            color: isVenta
                                ? AppColors.accentGreen
                                : const Color(0xFF3182CE),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        productName,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'Vendido'
                              ? AppColors.accentGreen.withValues(alpha: 0.12)
                              : AppColors.borderDefault.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: status == 'Vendido'
                                ? AppColors.accentGreen
                                : AppColors.textMedium,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fecha,
                        style: TextStyle(
                          color: AppColors.textMedium,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVenta
                            ? 'Comprador: $buyerName'
                            : 'Vendedor: $sellerName',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransaccionItem {
  final Map<String, dynamic> data;
  final bool isVenta;
  final Timestamp? createdAt;

  _TransaccionItem({required this.data, required this.isVenta, this.createdAt});

  factory _TransaccionItem.fromDoc(DocumentSnapshot doc, {required String uid}) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final sellerId = data['sellerId'];
    final isVenta = sellerId == uid;
    return _TransaccionItem(
      data: data,
      isVenta: isVenta,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

class _FetchResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const _FetchResult({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });

  factory _FetchResult.empty() => const _FetchResult(
        items: [],
        lastDoc: null,
        hasMore: false,
      );
}

int _compareTimestamp(Timestamp? a, Timestamp? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}