import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum SettlementType {
  partial,  // 部分结算
  full,     // 全部结算
}

class Settlement {
  final String id;
  final String projectId;
  final double amount;
  final DateTime date;
  final SettlementType type;
  final String note;
  final DateTime createdAt;

  Settlement({
    String? id,
    required this.projectId,
    required this.amount,
    required this.date,
    this.type = SettlementType.partial,
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
      'type': type.name,
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      type: SettlementType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SettlementType.partial,
      ),
      note: map['note'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  Settlement copyWith({
    String? projectId,
    double? amount,
    DateTime? date,
    SettlementType? type,
    String? note,
  }) {
    return Settlement(
      id: id,
      projectId: projectId ?? this.projectId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'Settlement(id: $id, amount: $amount, type: ${type.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Settlement && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
