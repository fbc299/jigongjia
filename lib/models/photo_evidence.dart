import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class PhotoEvidence {
  final String id;
  final String projectId;
  final String? workRecordId;
  final String filePath;
  final String projectName;
  final DateTime timestamp;
  final DateTime createdAt;

  PhotoEvidence({
    String? id,
    required this.projectId,
    this.workRecordId,
    required this.filePath,
    required this.projectName,
    required this.timestamp,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'workRecordId': workRecordId,
      'filePath': filePath,
      'projectName': projectName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PhotoEvidence.fromMap(Map<String, dynamic> map) {
    return PhotoEvidence(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      workRecordId: map['workRecordId'] as String?,
      filePath: map['filePath'] as String,
      projectName: map['projectName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  PhotoEvidence copyWith({
    String? projectId,
    String? workRecordId,
    String? filePath,
    String? projectName,
    DateTime? timestamp,
  }) {
    return PhotoEvidence(
      id: id,
      projectId: projectId ?? this.projectId,
      workRecordId: workRecordId ?? this.workRecordId,
      filePath: filePath ?? this.filePath,
      projectName: projectName ?? this.projectName,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'PhotoEvidence(id: $id, projectName: $projectName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PhotoEvidence && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
