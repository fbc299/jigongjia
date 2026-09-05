import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Project {
  final String id;
  final String name;
  final DateTime createdAt;
  final bool isArchived;
  final double defaultDailyRate;
  final double defaultOvertimeRate;
  final double defaultPackageDayRate;
  final double defaultPackageQtyRate;
  final String defaultQtyUnit;

  Project({
    String? id,
    required this.name,
    DateTime? createdAt,
    this.isArchived = false,
    this.defaultDailyRate = 300.0,
    this.defaultOvertimeRate = 50.0,
    this.defaultPackageDayRate = 0.0,
    this.defaultPackageQtyRate = 0.0,
    this.defaultQtyUnit = '平方',
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isArchived': isArchived ? 1 : 0,
      'defaultDailyRate': defaultDailyRate,
      'defaultOvertimeRate': defaultOvertimeRate,
      'defaultPackageDayRate': defaultPackageDayRate,
      'defaultPackageQtyRate': defaultPackageQtyRate,
      'defaultQtyUnit': defaultQtyUnit,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      isArchived: (map['isArchived'] as int) == 1,
      defaultDailyRate: (map['defaultDailyRate'] as num).toDouble(),
      defaultOvertimeRate: (map['defaultOvertimeRate'] as num).toDouble(),
      defaultPackageDayRate: (map['defaultPackageDayRate'] as num).toDouble(),
      defaultPackageQtyRate: (map['defaultPackageQtyRate'] as num).toDouble(),
      defaultQtyUnit: map['defaultQtyUnit'] as String,
    );
  }

  Project copyWith({
    String? name,
    bool? isArchived,
    double? defaultDailyRate,
    double? defaultOvertimeRate,
    double? defaultPackageDayRate,
    double? defaultPackageQtyRate,
    String? defaultQtyUnit,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      isArchived: isArchived ?? this.isArchived,
      defaultDailyRate: defaultDailyRate ?? this.defaultDailyRate,
      defaultOvertimeRate: defaultOvertimeRate ?? this.defaultOvertimeRate,
      defaultPackageDayRate: defaultPackageDayRate ?? this.defaultPackageDayRate,
      defaultPackageQtyRate: defaultPackageQtyRate ?? this.defaultPackageQtyRate,
      defaultQtyUnit: defaultQtyUnit ?? this.defaultQtyUnit,
    );
  }

  @override
  String toString() => 'Project(id: $id, name: $name, archived: $isArchived)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Project && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
