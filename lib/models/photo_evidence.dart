import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class PhotoEvidence {
  final String id;
  final String projectId;
  final String? workRecordId;
  final String filePath;
  /// 列表用的缩略图路径（400px）。老数据为空串时回退到原图。
  final String thumbPath;
  final String projectName;
  final DateTime timestamp;
  final DateTime createdAt;

  PhotoEvidence({
    String? id,
    required this.projectId,
    this.workRecordId,
    required this.filePath,
    this.thumbPath = '',
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
      'thumbPath': thumbPath,
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
      thumbPath: (map['thumbPath'] as String?) ?? '',
      projectName: map['projectName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  PhotoEvidence copyWith({
    String? projectId,
    String? workRecordId,
    String? filePath,
    String? thumbPath,
    String? projectName,
    DateTime? timestamp,
  }) {
    return PhotoEvidence(
      id: id,
      projectId: projectId ?? this.projectId,
      workRecordId: workRecordId ?? this.workRecordId,
      filePath: filePath ?? this.filePath,
      thumbPath: thumbPath ?? this.thumbPath,
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
