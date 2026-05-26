import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/report_model.dart';
import '../services/moderation_service.dart';
import '../theme/app_theme.dart';

class ModerationPanelScreen extends StatefulWidget {
  const ModerationPanelScreen({super.key});
  @override
  State<ModerationPanelScreen> createState() => _ModerationPanelScreenState();
}

class _ModerationPanelScreenState extends State<ModerationPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ModerationService _service = ModerationService();

  static const _adminEmail = 'admin.00@uceva.edu.co';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkAdminAccess(); // ← AGREGAR
  }

  void _checkAdminAccess() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final email = currentUser?.email?.toLowerCase() ?? '';
    if (email != _adminEmail) {
      // No es admin → expulsar inmediatamente
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Panel de Moderación',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Todos'),
            Tab(text: 'Revisados'),
            Tab(text: 'Suspendidos'),
            Tab(text: 'Chats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsTab('pending'),
          _buildReportsTab(null),
          _buildReportsTab('reviewed'),
          _buildSuspendedTab(),
          _buildChatsTab(),
        ],
      ),
    );
  }

  Widget _buildReportsTab(String? statusFilter) {
    return StreamBuilder<List<ReportModel>>(
      stream: _service.getReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentGreen),
          );
        }
        final reports = snapshot.data ?? [];
        List<ReportModel> filteredReports;
        if (statusFilter == 'pending') {
          filteredReports = reports
              .where((r) => r.status == ReportStatus.pending)
              .toList();
          return _buildReportList(
            filteredReports,
            'No hay reportes pendientes',
            'No hay reportes pendientes en el sistema.',
          );
        } else if (statusFilter == 'reviewed') {
          filteredReports = reports
              .where(
                (r) =>
                    r.status == ReportStatus.reviewed ||
                    r.status == ReportStatus.reviewedNoAction,
              )
              .toList();
          return _buildReportList(
            filteredReports,
            'No hay reportes revisados',
            'No hay reportes revisados.',
          );
        } else {
          filteredReports = reports;
          return _buildReportList(
            filteredReports,
            'No hay reportes',
            'No hay reportes en el sistema.',
          );
        }
      },
    );
  }

  Widget _buildReportList(
    List<ReportModel> reports,
    String emptyTitle,
    String emptySubtitle,
  ) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.borderDefault,
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              emptySubtitle,
              style: const TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: reports.length,
      itemBuilder: (context, index) => _ReportCard(report: reports[index]),
    );
  }

  Widget _buildSuspendedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('suspended', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentGreen),
          );
        }
        final users = snapshot.data?.docs ?? [];
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 64,
                  color: AppColors.borderDefault,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay usuarios suspendidos',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            final userName = userData['fullName'] ?? 'Usuario';
            final userEmail = userData['email'] ?? '';
            final suspendedAt = userData['suspendedAt'];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.accentGreen,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  userEmail,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                                if (suspendedAt != null)
                                  Text(
                                    'Suspendido el: ${_formatDateTime(suspendedAt)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                await ModerationService().unsuspendUser(userId);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Cuenta de $userName reactivada correctamente.',
                                      ),
                                      backgroundColor: AppColors.accentGreen,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.person_outline, size: 18),
                            label: const Text('Reactivar'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentGreen),
          );
        }
        final chats = snapshot.data?.docs ?? [];
        if (chats.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: AppColors.borderDefault),
                SizedBox(height: 16),
                Text(
                  'No hay chats registrados',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final data = chats[index].data() as Map<String, dynamic>;
            final chatId = chats[index].id;
            final driverName = data['driverName'] ?? 'Conductor';
            final passengerName = data['passengerName'] ?? 'Pasajero';
            final origin = data['origin'] ?? '';
            final destination = data['destination'] ?? '';
            final isClosed = data['isClosed'] ?? false;
            final routeId = data['routeId'] as String? ?? '';

            return FutureBuilder<DocumentSnapshot?>(
              future: routeId.isNotEmpty
                  ? FirebaseFirestore.instance
                      .collection('routes')
                      .doc(routeId)
                      .get()
                  : Future.value(null as DocumentSnapshot?),
              builder: (context, routeSnap) {
                String chatStatus = 'Activo';
                Color statusColor = AppColors.accentGreen;
                Color statusBg = const Color(0xFFE8F5E9);
                Color barColor = AppColors.accentGreen;

                if (isClosed) {
                  chatStatus = 'Cerrado';
                  statusColor = Colors.grey;
                  statusBg = Colors.grey.shade200;
                  barColor = Colors.grey;
                } else if (routeSnap.hasData &&
                    routeSnap.data != null &&
                    routeSnap.data!.exists) {
                  final routeData = routeSnap.data!.data()
                      as Map<String, dynamic>?;
                  final routeStatus =
                      routeData?['status'] as String? ?? '';
                  if (routeStatus == 'Completada' ||
                      routeStatus == 'completada') {
                    chatStatus = 'Finalizado';
                    statusColor = Colors.orange.shade700;
                    statusBg = Colors.orange.shade50;
                    barColor = Colors.orange.shade700;
                  }
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Barra lateral de color según estado
                      Container(
                        width: 4,
                        height: 90,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(16),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ruta y estado
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$origin → $destination',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      chatStatus,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Participantes
                              Row(
                                children: [
                                  const Icon(Icons.drive_eta,
                                      size: 13,
                                      color: AppColors.textLight),
                                  const SizedBox(width: 4),
                                  Text(
                                    driverName,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMedium),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.person_outline,
                                      size: 13,
                                      color: AppColors.textLight),
                                  const SizedBox(width: 4),
                                  Text(
                                    passengerName,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMedium),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Botón ver historial
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _openChatHistory(
                                    context,
                                    chatId,
                                    '$driverName & $passengerName',
                                    '$origin → $destination',
                                    data['driverId'] ?? '',
                                    data['passengerId'] ?? '',
                                    driverName,
                                    passengerName,
                                  ),
                                  icon: const Icon(Icons.history, size: 16),
                                  label: const Text('Ver historial'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        AppColors.accentGreen,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openChatHistory(
    BuildContext context,
    String chatId,
    String participants,
    String routeInfo,
    String driverId,
    String passengerId,
    String driverName,
    String passengerName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => _ChatHistorySheet(
          chatId: chatId,
          participants: participants,
          routeInfo: routeInfo,
          driverId: driverId,
          passengerId: passengerId,
          driverName: driverName,
          passengerName: passengerName,
        ),
      ),
    );
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = timestamp.toDate();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}

class _ReportCard extends StatefulWidget {
  final ReportModel report;
  const _ReportCard({required this.report});
  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _loading = false;

  Color _getLeftBorderColor() {
    switch (widget.report.status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.reviewed:
        return Colors.green;
      case ReportStatus.reviewedNoAction:
        return Colors.grey;
    }
  }

  Color _getTypeBackgroundColor() =>
      widget.report.type == ReportType.publication
      ? const Color(0xFFE3F2FD)
      : const Color(0xFFFFF3E0);
  Color _getTypeTextColor() => widget.report.type == ReportType.publication
      ? const Color(0xFF1565C0)
      : const Color(0xFFE65100);
  Color _getStatusBackgroundColor() {
    switch (widget.report.status) {
      case ReportStatus.pending:
        return const Color(0xFFFFF8E1);
      case ReportStatus.reviewed:
        return const Color(0xFFE8F5E9);
      case ReportStatus.reviewedNoAction:
        return const Color(0xFFF5F5F5);
    }
  }

  Color _getStatusTextColor() {
    switch (widget.report.status) {
      case ReportStatus.pending:
        return const Color(0xFFF57F17);
      case ReportStatus.reviewed:
        return const Color(0xFF2E7D32);
      case ReportStatus.reviewedNoAction:
        return const Color(0xFF616161);
    }
  }

  String _getStatusLabel() {
    switch (widget.report.status) {
      case ReportStatus.pending:
        return 'Pendiente';
      case ReportStatus.reviewed:
        return 'Revisado';
      case ReportStatus.reviewedNoAction:
        return 'Descartado';
    }
  }

  String _truncateId(String id) =>
      id.length > 16 ? '${id.substring(0, 16)}...' : id;

  Future<void> _showActionDialog() async {
    final isPublication = widget.report.type == ReportType.publication;
    final isRoute = widget.report.targetName.contains('→');
    bool isUserSuspended = false;
    if (!isPublication) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.report.targetId)
          .get();
      isUserSuspended = userDoc.data()?['suspended'] ?? false;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                width: 36,
                height: 4,
                child: Divider(color: AppColors.borderDefault, thickness: 2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Acciones de moderación',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.report.targetName,
              style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
            ),
            const Divider(height: 24),
            if (widget.report.status == ReportStatus.pending && isPublication)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Eliminar publicacion',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
                contentPadding: EdgeInsets.zero,
              ),
            if (widget.report.status == ReportStatus.pending && isPublication)
              ListTile(
                leading: const Icon(
                  Icons.person_off_outlined,
                  color: Colors.orange,
                ),
                title: Text(
                  isRoute ? 'Suspender conductor' : 'Suspender vendedor',
                  style: const TextStyle(color: AppColors.textDark),
                ),
                onTap: () => Navigator.pop(context, 'suspendVendor'),
                contentPadding: EdgeInsets.zero,
              ),
            if (widget.report.status == ReportStatus.pending &&
                !isPublication &&
                !isUserSuspended)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: const Text(
                  'Suspender usuario',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () => Navigator.pop(context, 'suspend'),
                contentPadding: EdgeInsets.zero,
              ),
            if (widget.report.status == ReportStatus.pending &&
                !isPublication &&
                isUserSuspended)
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.accentGreen,
                ),
                title: const Text(
                  'Reactivar cuenta',
                  style: TextStyle(color: AppColors.accentGreen),
                ),
                onTap: () => Navigator.pop(context, 'unsuspend'),
                contentPadding: EdgeInsets.zero,
              ),
            // Ver chat como evidencia (si el reporte es de usuario)
            if (!isPublication)
              ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.accentGreen,
                ),
                title: const Text('Ver chat como evidencia'),
                subtitle:
                    const Text('Buscar chats donde participó este usuario'),
                onTap: () async {
                  Navigator.pop(context);
                  // Buscar chats donde el usuario reportado participó
                  final chatsSnap = await FirebaseFirestore.instance
                      .collection('chats')
                      .where('driverId',
                          isEqualTo: widget.report.targetId)
                      .get();
                  final chatsSnap2 = await FirebaseFirestore.instance
                      .collection('chats')
                      .where('passengerId',
                          isEqualTo: widget.report.targetId)
                      .get();

                  final allChats = [
                    ...chatsSnap.docs,
                    ...chatsSnap2.docs
                  ];

                  if (allChats.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'No hay chats asociados a este usuario'),
                        ),
                      );
                    }
                    return;
                  }

                  // Mostrar lista de chats del usuario reportado
                  if (context.mounted) {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      builder: (_) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Chats de ${widget.report.targetName}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: allChats.length,
                              itemBuilder: (context, i) {
                                final data = allChats[i].data();
                                final chatId = allChats[i].id;
                                final origin = data['origin'] ?? '';
                                final destination =
                                    data['destination'] ?? '';
                                final dName =
                                    data['driverName'] ?? '';
                                final pName =
                                    data['passengerName'] ?? '';
                                final dId = data['driverId'] ?? '';
                                  final pId = data['passengerId'] ?? '';
                                  return ListTile(
                                  leading: const Icon(
                                      Icons.chat_bubble_outline,
                                      color: AppColors.accentGreen),
                                  title: Text('$origin → $destination'),
                                  subtitle: Text('$dName & $pName'),
                                  trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14),
                                  onTap: () {
                                    Navigator.pop(context);
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      shape:
                                          const RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.vertical(
                                                top: Radius.circular(
                                                    20)),
                                      ),
                                      builder: (_) =>
                                          _ChatHistorySheet(
                                        chatId: chatId,
                                        participants:
                                            '$dName & $pName',
                                        routeInfo:
                                            '$origin → $destination',
                                        driverId: dId,
                                        passengerId: pId,
                                        driverName: dName,
                                        passengerName: pName,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  }
                },
              ),
            if (widget.report.status != ReportStatus.reviewedNoAction)
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.accentGreen,
                ),
                title: const Text(
                  'Descartar reporte',
                  style: TextStyle(color: AppColors.textDark),
                ),
                onTap: () => Navigator.pop(context, 'dismiss'),
                contentPadding: EdgeInsets.zero,
              ),
            if (widget.report.status != ReportStatus.reviewedNoAction)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: AppColors.textMedium,
                ),
                title: const Text(
                  'Eliminar reporte',
                  style: TextStyle(color: AppColors.textDark),
                ),
                onTap: () => Navigator.pop(context, 'deleteReport'),
                contentPadding: EdgeInsets.zero,
              ),
            if (widget.report.status == ReportStatus.reviewedNoAction)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Reporte ya revisado',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textMedium),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() => _loading = true);
    String? snackMessage;

    try {
      if (result == 'delete') {
        final confirm = await _confirmDialog(
          isRoute ? '¿Eliminar esta ruta?' : '¿Eliminar esta publicacion?',
          isRoute
              ? 'La ruta será eliminada y el conductor será notificado.'
              : 'El producto será eliminado y el vendedor será notificado.',
        );
        if (confirm == true) {
          if (isRoute) {
            await ModerationService().deleteRouteFromReport(
              widget.report.id,
              widget.report.targetId,
              widget.report.reason,
            );
          } else {
            await ModerationService().deletePublicationFromReport(
              widget.report.id,
              widget.report.targetId,
              widget.report.reason,
            );
          }
          snackMessage = isRoute ? 'Ruta eliminada.' : 'Publicación eliminada.';
        }
      } else if (result == 'suspend') {
        final confirm = await _confirmDialog(
          'Suspender este usuario?',
          'El usuario no podra acceder a la app.',
        );
        if (confirm == true) {
          await ModerationService().suspendUser(
            widget.report.id,
            widget.report.targetId,
            widget.report.targetName,
          );
          snackMessage = 'Usuario suspendido.';
        }
      } else if (result == 'suspendVendor') {
        final isRoute = widget.report.targetName.contains('→');
        final confirm = await _confirmDialog(
          isRoute ? '¿Suspender al conductor?' : '¿Suspender al vendedor?',
          isRoute
              ? 'El conductor no podrá acceder a la app.'
              : 'El vendedor no podrá acceder a la app.',
        );
        if (confirm == true) {
          String userId = '';
          String userName = '';
          if (isRoute) {
            final routeDoc = await FirebaseFirestore.instance
                .collection('routes')
                .doc(widget.report.targetId)
                .get();
            userId = routeDoc.data()?['driverId'] ?? '';
            userName = routeDoc.data()?['driverName'] ?? 'el conductor';
          } else {
            final productDoc = await FirebaseFirestore.instance
                .collection('products')
                .doc(widget.report.targetId)
                .get();
            userId = productDoc.data()?['sellerId'] ?? '';
            userName = productDoc.data()?['sellerName'] ?? 'el vendedor';
          }
          if (userId.isEmpty) throw Exception('No se encontró el usuario.');
          await ModerationService().suspendUser(
            widget.report.id,
            userId,
            userName,
          );
          snackMessage = isRoute
              ? 'Conductor suspendido.'
              : 'Vendedor suspendido.';
        }
      } else if (result == 'unsuspend') {
        final confirm = await _confirmDialog(
          'Reactivar esta cuenta?',
          'El usuario podra volver a acceder.',
        );
        if (confirm == true) {
          await ModerationService().unsuspendUser(widget.report.targetId);
          snackMessage = 'Cuenta reactivada.';
        }
      } else if (result == 'dismiss') {
        await ModerationService().dismissReport(widget.report.id);
        snackMessage = 'Reporte descartado.';
      } else if (result == 'deleteReport') {
        await ModerationService().deleteReport(widget.report.id);
        snackMessage = 'Reporte eliminado.';
      }

      if (snackMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackMessage),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _confirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: Text(content, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getWarningCount(String targetId) async {
    return ModerationService().getPendingReportsCountForUser(targetId);
  }

  @override
  Widget build(BuildContext context) {
    final isPublication = widget.report.type == ReportType.publication;

    return FutureBuilder<int>(
      future: _getWarningCount(widget.report.targetId),
      builder: (context, snapshot) {
        final warningCount = snapshot.data ?? 0;
        final showWarning = warningCount >= 2;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 220,
                decoration: BoxDecoration(
                  color: _getLeftBorderColor(),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    if (showWarning)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              warningCount == 1
                                  ? '1 reporte sobre este usuario'
                                  : '$warningCount reportes sobre este usuario',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getTypeBackgroundColor(),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPublication ? 'Publicacion' : 'Usuario',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getTypeTextColor(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusBackgroundColor(),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getStatusLabel(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusTextColor(),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (_loading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: _showActionDialog,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.accentGreen,
                                child: Text(
                                  widget.report.targetName.isNotEmpty
                                      ? widget.report.targetName[0]
                                            .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.report.targetName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'ID: ${_truncateId(widget.report.targetId)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundApp,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MOTIVO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textLight,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.report.reason,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(
                            height: 1,
                            color: AppColors.borderDefault,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 14,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Reportado por ${widget.report.reportedByName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatDate(widget.report.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _ChatHistorySheet extends StatelessWidget {
  final String chatId;
  final String participants;
  final String routeInfo;
  final String driverId;
  final String driverName;
  final String passengerId;
  final String passengerName;

  const _ChatHistorySheet({
    required this.chatId,
    required this.participants,
    required this.routeInfo,
    required this.driverId,
    required this.passengerId,
    required this.driverName,
    required this.passengerName,
  });

  String _senderName(String senderId) {
    if (senderId == driverId) return driverName;
    if (senderId == passengerId) return passengerName;
    return senderId;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Historial de chat',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(routeInfo,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMedium)),
                Text(participants,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('sentAt', descending: false)
                  .snapshots(),
              builder: (context, msgSnap) {
                if (msgSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = msgSnap.data?.docs ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Sin mensajes',
                        style: TextStyle(color: AppColors.textLight)),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg =
                        messages[i].data() as Map<String, dynamic>;
                    final text = msg['text'] as String? ?? '';
                    final senderId = msg['senderId'] as String? ?? '';
                    final sentAt = msg['sentAt'];
                    final senderName = _senderName(senderId);
                    String timeStr = '';
                    if (sentAt is Timestamp) {
                      final date = sentAt.toDate();
                      timeStr =
                          '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundApp,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor:
                                        senderId == driverId
                                            ? AppColors.accentGreen
                                            : AppColors.primaryGreen,
                                    child: Text(
                                      senderName.isNotEmpty
                                          ? senderName[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    senderName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
