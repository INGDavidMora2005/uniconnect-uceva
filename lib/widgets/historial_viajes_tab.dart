import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HistorialViajesTab extends StatefulWidget {
  final String uid;

  const HistorialViajesTab({Key? key, required this.uid}) : super(key: key);

  @override
  State<HistorialViajesTab> createState() => _HistorialViajesTabState();
}

class _HistorialViajesTabState extends State<HistorialViajesTab> {
  static const int _pageSize = 20;
  final List<_ViajeItem> _viajes = [];
  bool _isLoading = false;
  bool _hasError = false;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocConductor;
  DocumentSnapshot? _lastDocPasajero;
  bool _hasMoreConductor = true;
  bool _hasMorePasajero = true;

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
        _fetchConductorPage(),
        _fetchPasajeroPage(),
      ]);

      if (!mounted) return;

      final combined = <_ViajeItem>[
        ...results[0].items,
        ...results[1].items,
      ];
      combined.sort((a, b) => _compareTimestamp(b.createdAt, a.createdAt));

      setState(() {
        _viajes
          ..clear()
          ..addAll(combined);
        _lastDocConductor = results[0].lastDoc;
        _lastDocPasajero = results[1].lastDoc;
        _hasMoreConductor = results[0].hasMore;
        _hasMorePasajero = results[1].hasMore;
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
      final conductorFuture = _hasMoreConductor
          ? _fetchConductorPage(startAfter: _lastDocConductor)
          : Future.value(_FetchResult<_ViajeItem>.empty());
      final pasajeroFuture = _hasMorePasajero
          ? _fetchPasajeroPage(startAfter: _lastDocPasajero)
          : Future.value(_FetchResult<_ViajeItem>.empty());

      final results = await Future.wait<_FetchResult<_ViajeItem>>([
        conductorFuture,
        pasajeroFuture,
      ]);

      if (!mounted) return;

      final newItems = <_ViajeItem>[
        ...results[0].items,
        ...results[1].items,
      ];

      setState(() {
        _viajes.addAll(newItems);
        _viajes.sort((a, b) => _compareTimestamp(b.createdAt, a.createdAt));
        _lastDocConductor = results[0].lastDoc ?? _lastDocConductor;
        _lastDocPasajero = results[1].lastDoc ?? _lastDocPasajero;
        _hasMoreConductor = results[0].hasMore;
        _hasMorePasajero = results[1].hasMore;
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

  Future<_FetchResult<_ViajeItem>> _fetchConductorPage({DocumentSnapshot? startAfter}) async {
    Query query = FirebaseFirestore.instance
        .collection('routes')
        .where('driverId', isEqualTo: widget.uid)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => _ViajeItem.fromDoc(doc, isDriver: true))
        .toList();
    return _FetchResult(
      items: items,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == _pageSize,
    );
  }

  Future<_FetchResult<_ViajeItem>> _fetchPasajeroPage({DocumentSnapshot? startAfter}) async {
    Query query = FirebaseFirestore.instance
        .collection('cupo_requests')
        .where('passengerId', isEqualTo: widget.uid)
        .where('status', isEqualTo: 'accepted')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => _ViajeItem.fromDoc(doc, isDriver: false))
        .toList();
    return _FetchResult(
      items: items,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == _pageSize,
    );
  }

  bool get _hasMore => _hasMoreConductor || _hasMorePasajero;

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _viajes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentGreen),
      );
    }

    if (_hasError) {
      return Center(
        child: Text(
          'Error al cargar viajes. Intente nuevamente.',
          style: TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }

    if (_viajes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 56, color: AppColors.borderDefault),
            const SizedBox(height: 12),
            Text(
              'No tienes viajes registrados',
              style: TextStyle(color: AppColors.textMedium, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Aquí aparecerán tus rutas como conductor y pasajero.',
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
      itemCount: _viajes.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _viajes.length) {
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

        final item = _viajes[index];
        final data = item.data;
        final isConductor = item.isDriver;
        final origin = (data['origin'] ?? '').toString();
        final destination = (data['destination'] ?? '').toString();
        final date = (data['date'] ?? '').toString();
        final time = (data['time'] ?? '').toString();
        final driverRating = (data['driverRating'] as num?)?.toDouble() ?? 0;

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
                    isConductor ? Icons.directions_car : Icons.person_outline,
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
                          color: AppColors.accentGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isConductor ? 'Conductor' : 'Pasajero',
                          style: TextStyle(
                            color: AppColors.accentGreen,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$origin → $destination',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date.isNotEmpty && time.isNotEmpty
                            ? '$date · $time'
                            : date.isNotEmpty
                                ? date
                                : time,
                        style: TextStyle(
                          color: AppColors.textMedium,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConductor && driverRating > 0
                            ? '⭐ $driverRating'
                            : '⭐ Sin calificar',
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

class _ViajeItem {
  final Map<String, dynamic> data;
  final bool isDriver;
  final Timestamp? createdAt;

  _ViajeItem({required this.data, required this.isDriver, this.createdAt});

  factory _ViajeItem.fromDoc(DocumentSnapshot doc, {required bool isDriver}) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return _ViajeItem(
      data: data,
      isDriver: isDriver,
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