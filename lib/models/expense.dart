import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Expense {
  final String id;
  final double amount;
  final String category;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  Expense({
    String? id,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'date': date.millisecondsSinceEpoch,
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      note: map['note'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  Expense copyWith({
    double? amount,
    String? category,
    DateTime? date,
    String? note,
  }) {
    return Expense(
      id: id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'Expense(id: $id, amount: $amount, category: $category)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Expense && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
