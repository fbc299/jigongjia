import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class BorrowRecord {
  final String id;
  final String projectId;
  final double amount;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  BorrowRecord({
    String? id,
    required this.projectId,
    required this.amount,
    required this.date,
    this.note = '',
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory BorrowRecord.fromMap(Map<String, dynamic> map) {
    return BorrowRecord(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      note: map['note'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  BorrowRecord copyWith({
    String? projectId,
    double? amount,
    DateTime? date,
    String? note,
  }) {
    return BorrowRecord(
      id: id,
      projectId: projectId ?? this.projectId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'BorrowRecord(id: $id, amount: $amount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BorrowRecord && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
