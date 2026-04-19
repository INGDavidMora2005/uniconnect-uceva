import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Todos'),
            Tab(text: 'Revisados'),
          ],
        ),
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: _service.getReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGreen),
            );
          }

          final reports = snapshot.data ?? [];
          final pendingReports = reports
              .where((r) => r.status == ReportStatus.pending)
              .toList();
          final reviewedReports = reports
              .where(
                (r) =>
                    r.status == ReportStatus.reviewed ||
                    r.status == ReportStatus.reviewedNoAction,
              )
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildReportList(pendingReports, 'No hay reportes pendientes'),
              _buildReportList(reports, 'No hay reportes'),
              _buildReportList(reviewedReports, 'No hay reportes revisados'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportList(List<ReportModel> reports, String emptyMessage) {
    if (reports.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textLight, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return _ReportCard(report: report);
      },
    );
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

  Future<void> _showActionDialog() async {
    final isPublication = widget.report.type == ReportType.publication;
    final isPending = widget.report.status == ReportStatus.pending;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Acciones deModeración',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPending && isPublication)
              _actionTile(
                'Eliminar publicación',
                Icons.delete_outline,
                Colors.redAccent,
                () => Navigator.pop(context, 'delete'),
              ),
            if (isPending)
              _actionTile(
                'Suspender usuario',
                Icons.block,
                Colors.redAccent,
                () => Navigator.pop(context, 'suspend'),
              ),
            if (isPending)
              _actionTile(
                'Descartar reporte',
                Icons.close,
                AppColors.textLight,
                () => Navigator.pop(context, 'dismiss'),
              ),
            if (!isPending)
              const Text(
                'Reporte ya revisado',
                style: TextStyle(color: AppColors.textLight),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() => _loading = true);

    try {
      if (result == 'delete') {
        final confirm = await _confirmDialog(
          '¿Eliminar esta publicación?',
          'El producto será eliminado y el vendedor será notificado.',
        );
        if (confirm == true) {
          await ModerationService().deletePublicationFromReport(
            widget.report.id,
            widget.report.targetId,
            widget.report.reason,
          );
        }
      } else if (result == 'suspend') {
        final confirm = await _confirmDialog(
          '¿Suspender este usuario?',
          'El usuario no podrá acceder a la app y será notificado.',
        );
        if (confirm == true) {
          debugPrint('suspendiendo userId: ${widget.report.targetId}');
          await ModerationService().suspendUser(
            widget.report.id,
            widget.report.targetId,
            widget.report.targetName,
          );
        }
      } else if (result == 'dismiss') {
        await ModerationService().dismissReport(widget.report.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acción realizada'),
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
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: onTap,
    );
  }

  Future<int> _getWarningCount(String targetId) async {
    return ModerationService().getPendingReportsCountForUser(targetId);
  }

  @override
  Widget build(BuildContext context) {
    final isPublication = widget.report.type == ReportType.publication;
    final isUser = widget.report.type == ReportType.user;

    return FutureBuilder<int>(
      future: _getWarningCount(widget.report.targetId),
      builder: (context, snapshot) {
        final warningCount = snapshot.data ?? 0;
        final showWarning = warningCount >= 2;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
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
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Usuario con reportes pendientes',
                        style: TextStyle(
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
                            color: isPublication
                                ? AppColors.accentGreen.withOpacity(0.1)
                                : AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPublication ? 'Publicación' : 'Usuario',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPublication
                                  ? AppColors.accentGreen
                                  : AppColors.primaryGreen,
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
                            color: widget.report.status == ReportStatus.pending
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.report.status == ReportStatus.pending
                                ? 'Pendiente'
                                : widget.report.status == ReportStatus.reviewed
                                ? 'Revisado'
                                : 'Descartado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  widget.report.status == ReportStatus.pending
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_loading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                                ? widget.report.targetName[0].toUpperCase()
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
                              ),
                              Text(
                                'ID: ${widget.report.targetId}',
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
                              fontSize: 10,
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
                          ),
                        ],
                      ),
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
                        Text(
                          'Reportado por ${widget.report.reportedByName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        const Spacer(),
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
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
