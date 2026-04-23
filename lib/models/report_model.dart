enum ReportType { publication, user }

enum ReportStatus { pending, reviewed, reviewedNoAction }

class ReportModel {
  final String id;
  final ReportType type;
  final String targetId;
  final String targetName;
  final String reportedByUserId;
  final String reportedByName;
  final String reason;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    required this.type,
    required this.targetId,
    required this.targetName,
    required this.reportedByUserId,
    required this.reportedByName,
    required this.reason,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map) => ReportModel(
    id: map['id'] ?? '',
    type: map['type'] == 'user' ? ReportType.user : ReportType.publication,
    targetId: map['targetId'] ?? '',
    targetName: map['targetName'] ?? '',
    reportedByUserId: map['reportedByUserId'] ?? '',
    reportedByName: map['reportedByName'] ?? '',
    reason: map['reason'] ?? '',
    description: map['description'],
    status: _parseStatus(map['status']),
    createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
  );

  static ReportStatus _parseStatus(String? status) {
    if (status == 'reviewed') return ReportStatus.reviewed;
    if (status == 'reviewedNoAction') return ReportStatus.reviewedNoAction;
    return ReportStatus.pending;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type == ReportType.user ? 'user' : 'publication',
    'targetId': targetId,
    'targetName': targetName,
    'reportedByUserId': reportedByUserId,
    'reportedByName': reportedByName,
    'reason': reason,
    'description': description,
    'status': status == ReportStatus.reviewed
        ? 'reviewed'
        : status == ReportStatus.reviewedNoAction
        ? 'reviewedNoAction'
        : 'pending',
    'createdAt': createdAt,
  };

  ReportModel copyWith({
    String? id,
    ReportType? type,
    String? targetId,
    String? targetName,
    String? reportedByUserId,
    String? reportedByName,
    String? reason,
    String? description,
    ReportStatus? status,
    DateTime? createdAt,
  }) => ReportModel(
    id: id ?? this.id,
    type: type ?? this.type,
    targetId: targetId ?? this.targetId,
    targetName: targetName ?? this.targetName,
    reportedByUserId: reportedByUserId ?? this.reportedByUserId,
    reportedByName: reportedByName ?? this.reportedByName,
    reason: reason ?? this.reason,
    description: description ?? this.description,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
}
