import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cupo_service.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  /// Callback opcional: se llama cuando el usuario toca
  /// una notificación de tipo 'rate_trip'.
  final void Function(Map<String, dynamic> data)? onRateTrip;

  const NotificationsScreen({super.key, this.onRateTrip});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'Todas';
  final _filters = ['Todas', 'Rutas', 'Sistema'];

  static const _green      = Color(0xFF1A5C40);
  static const _accentGreen = Color(0xFF2D9E6B);

  String? _uid;
  final Set<String> _processingDocs = {};

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Stream<QuerySnapshot> get _stream {
    if (_uid == null || _uid!.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: _uid)
        .snapshots();
  }

  String _typeToFilter(String type) {
    if (type == 'cupo_request' ||
        type == 'cupo_accepted' ||
        type == 'cupo_rejected' ||
        type == 'rate_trip') {
      return 'Rutas';
    }
    return 'Sistema';
  }

  Future<void> _markRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'read': true});
  }

  Future<void> _deleteAllNotifications() async {
    if (_uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Borrar notificaciones',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Seguro que quieres borrar todas las notificaciones? Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7C74)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7C74))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Borrar todo',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await NotificationService().deleteAllNotifications(_uid!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notificaciones eliminadas'),
        backgroundColor: Color(0xFF1A5C40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _uid!.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión')),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F1),
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Notificaciones',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          actions: [
            IconButton(
              onPressed: _deleteAllNotifications,
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: Colors.white),
              tooltip: 'Borrar todas',
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Filtros ──────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: _filters.map((f) {
                  final active = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color:
                              active ? _accentGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? _accentGreen
                                : const Color(0xFFCDD5D0),
                          ),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : const Color(0xFF6B7C74),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              'Error: ${snap.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: _accentGreen),
                    );
                  }

                  final all = snap.data?.docs ?? [];

                  final sorted = List.of(all)
                    ..sort((a, b) {
                      final aTs = (a.data() as Map)['createdAt']
                          as Timestamp?;
                      final bTs = (b.data() as Map)['createdAt']
                          as Timestamp?;
                      if (aTs == null && bTs == null) return 0;
                      if (aTs == null) return 1;
                      if (bTs == null) return -1;
                      return bTs.compareTo(aTs);
                    });

                  final docs = sorted.where((d) {
                    if (_filter == 'Todas') return true;
                    final type = (d.data() as Map)['type'] ?? '';
                    return _typeToFilter(type) == _filter;
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Sin notificaciones',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc  = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final type = data['type'] ?? '';
                      final isRead     = data['read'] ?? false;
                      final isProcessing =
                          _processingDocs.contains(doc.id);

                      return _NotifCard(
                        data: data,
                        docId: doc.id,
                        isProcessing: isProcessing,
                        // Tap en notificación rate_trip → abrir CalificarScreen
                        onRead: type == 'rate_trip'
                            ? () {
                                _markRead(doc.id);
                                widget.onRateTrip?.call(data);
                              }
                            : (type == 'cupo_request' && !isRead)
                                ? null
                                : () => _markRead(doc.id),
                        onRespond: (type == 'cupo_request' &&
                                !isRead &&
                                !isProcessing)
                            ? (accepted) async {
                                setState(
                                    () => _processingDocs.add(doc.id));

                                final requestId =
                                    data['requestId'] ?? '';
                                final routeId   = data['routeId'] ?? '';
                                final passengerId =
                                    data['passengerId'] ?? '';
                                final passengerName =
                                    data['passengerName'] ?? '';
                                final origin      = data['origin'] ?? '';
                                final destination =
                                    data['destination'] ?? '';

                                if (requestId.isEmpty ||
                                    routeId.isEmpty ||
                                    passengerId.isEmpty) {
                                  setState(() =>
                                      _processingDocs.remove(doc.id));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Faltan datos para responder la solicitud'),
                                  ));
                                  return;
                                }

                                try {
                                  await CupoService().respondToRequest(
                                    requestId:     requestId,
                                    routeId:       routeId,
                                    passengerId:   passengerId,
                                    passengerName: passengerName,
                                    origin:        origin,
                                    destination:   destination,
                                    accepted:      accepted,
                                  );
                                  await _markRead(doc.id);
                                  if (!context.mounted) return;
                                  setState(() =>
                                      _processingDocs.remove(doc.id));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(accepted
                                        ? '✅ Aceptación de ruta exitosa'
                                        : 'Solicitud rechazada correctamente'),
                                    backgroundColor: accepted
                                        ? const Color(0xFF1A5C40)
                                        : Colors.redAccent,
                                  ));
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setState(() =>
                                      _processingDocs.remove(doc.id));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(
                                        'Error al responder solicitud: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ));
                                }
                              }
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _NotifCard ────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isProcessing;
  final VoidCallback? onRead;
  final Future<void> Function(bool accepted)? onRespond;

  const _NotifCard({
    required this.data,
    required this.docId,
    required this.isProcessing,
    required this.onRead,
    required this.onRespond,
  });

  static const _accentGreen = Color(0xFF2D9E6B);

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    final date = (ts as Timestamp).toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} días';
  }

  Widget _icon(String type) {
    switch (type) {
      case 'cupo_request':
        return const Text('🚗', style: TextStyle(fontSize: 26));
      case 'cupo_accepted':
        return const Text('✅', style: TextStyle(fontSize: 26));
      case 'cupo_rejected':
        return const Text('❌', style: TextStyle(fontSize: 26));
      case 'rate_trip':
        return const Text('⭐', style: TextStyle(fontSize: 26));
      default:
        return const Text('🔔', style: TextStyle(fontSize: 26));
    }
  }

  @override
  Widget build(BuildContext context) {
    final type      = data['type'] ?? '';
    final isRead    = data['read'] ?? false;
    final unread    = !isRead;
    final showActions =
        type == 'cupo_request' && unread && onRespond != null;
    // Las notificaciones rate_trip son tapeables para calificar
    final isRateTrip   = type == 'rate_trip';
    final isTappable   = isRateTrip || onRead != null;

    return GestureDetector(
      onTap: isTappable ? onRead : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unread
                ? _accentGreen.withOpacity(0.3)
                : const Color(0xFFE8EDE9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: _icon(type)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['title'] ?? '',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: unread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data['body'] ?? '',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7C74),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _timeAgo(data['createdAt']),
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFFAFB8B3)),
                  ),
                  // Botón inline para rate_trip
                  if (isRateTrip && unread) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: onRead,
                        icon: const Icon(Icons.star_rounded,
                            size: 15, color: Colors.white),
                        label: const Text(
                          'Calificar viaje',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  // Botones aceptar/rechazar para cupo_request
                  if (showActions) ...[
                    const SizedBox(height: 10),
                    if (isProcessing)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _accentGreen),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => onRespond!(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(
                                    color: Colors.redAccent),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              child: const Text('Rechazar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => onRespond!(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              child: const Text('Aceptar'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}