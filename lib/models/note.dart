import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Note {
  final String id;
  final String? projectId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    String? id,
    this.projectId,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      projectId: map['projectId'] as String?,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  Note copyWith({
    String? projectId,
    String? content,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      projectId: projectId ?? this.projectId,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() => 'Note(id: $id, content: ${content.length > 20 ? '${content.substring(0, 20)}...' : content})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Note && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
