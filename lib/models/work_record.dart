import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum WorkType {
  point,       // 点工
  packageDay,  // 包工(按天)
  packageQty,  // 包工(按量)
}

class WorkRecord {
  final String id;
  final String projectId;
  final DateTime date;
  final WorkType type;
  final double days;
  final double dailyRate;
  final double overtimeHours;
  final double overtimeRate;
  final double packageDays;
  final double packageDayRate;
  final double quantity;
  final String qtyUnit;
  final double qtyUnitPrice;
  final double totalWage;
  final String note;
  final bool isRest;
  final DateTime createdAt;

  WorkRecord({
    String? id,
    required this.projectId,
    required this.date,
    this.type = WorkType.point,
    this.days = 0.0,
    this.dailyRate = 300.0,
    this.overtimeHours = 0.0,
    this.overtimeRate = 0.0,
    this.packageDays = 0.0,
    this.packageDayRate = 0.0,
    this.quantity = 0.0,
    this.qtyUnit = '平方',
    this.qtyUnitPrice = 0.0,
    double? totalWage,
    this.note = '',
    this.isRest = false,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        totalWage = totalWage ?? 0.0,
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'date': date.millisecondsSinceEpoch,
      'type': type.name,
      'days': days,
      'dailyRate': dailyRate,
      'overtimeHours': overtimeHours,
      'overtimeRate': overtimeRate,
      'packageDays': packageDays,
      'packageDayRate': packageDayRate,
      'quantity': quantity,
      'qtyUnit': qtyUnit,
      'qtyUnitPrice': qtyUnitPrice,
      'totalWage': totalWage,
      'note': note,
      'isRest': isRest ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory WorkRecord.fromMap(Map<String, dynamic> map) {
    return WorkRecord(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      type: WorkType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => WorkType.point,
      ),
      days: (map['days'] as num).toDouble(),
      dailyRate: (map['dailyRate'] as num?)?.toDouble() ?? 300.0,
      overtimeHours: (map['overtimeHours'] as num).toDouble(),
      overtimeRate: (map['overtimeRate'] as num).toDouble(),
      packageDays: (map['packageDays'] as num).toDouble(),
      packageDayRate: (map['packageDayRate'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      qtyUnit: map['qtyUnit'] as String? ?? '平方',
      qtyUnitPrice: (map['qtyUnitPrice'] as num).toDouble(),
      totalWage: (map['totalWage'] as num).toDouble(),
      note: map['note'] as String? ?? '',
      isRest: (map['isRest'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  WorkRecord copyWith({
    String? projectId,
    DateTime? date,
    WorkType? type,
    double? days,
    double? dailyRate,
    double? overtimeHours,
    double? overtimeRate,
    double? packageDays,
    double? packageDayRate,
    double? quantity,
    String? qtyUnit,
    double? qtyUnitPrice,
    double? totalWage,
    String? note,
    bool? isRest,
  }) {
    return WorkRecord(
      id: id,
      projectId: projectId ?? this.projectId,
      date: date ?? this.date,
      type: type ?? this.type,
      days: days ?? this.days,
      dailyRate: dailyRate ?? this.dailyRate,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      overtimeRate: overtimeRate ?? this.overtimeRate,
      packageDays: packageDays ?? this.packageDays,
      packageDayRate: packageDayRate ?? this.packageDayRate,
      quantity: quantity ?? this.quantity,
      qtyUnit: qtyUnit ?? this.qtyUnit,
      qtyUnitPrice: qtyUnitPrice ?? this.qtyUnitPrice,
      totalWage: totalWage ?? this.totalWage,
      note: note ?? this.note,
      isRest: isRest ?? this.isRest,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'WorkRecord(id: $id, date: ${date.toIso8601String()}, type: ${type.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WorkRecord && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
