import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../models/work_record.dart';
import 'work_provider.dart';
import 'borrow_provider.dart';
import 'settlement_provider.dart';

enum AttendanceStatus {
  worked,   // 出勤
  rest,     // 休息
  overtime, // 加班
  absent,   // 缺勤
}

class ProjectSummary {
  final double totalDays;
  final double totalWage;
  final double totalBorrowed;
  final double totalSettled;
  final double unpaidWage;

  const ProjectSummary({
    required this.totalDays,
    required this.totalWage,
    required this.totalBorrowed,
    required this.totalSettled,
    required this.unpaidWage,
  });
}

class MonthlyStats {
  final double workDays;
  final double overtimeHours;
  final double totalIncome;
  final double borrowAmount;
  final double unpaidAmount;

  const MonthlyStats({
    required this.workDays,
    required this.overtimeHours,
    required this.totalIncome,
    required this.borrowAmount,
    required this.unpaidAmount,
  });
}

class StatsProvider extends ChangeNotifier {
  /// Selector helper: wrap Selector<StatsProvider, T> to reduce rebuilds.
  static Widget select<T>({
    required T Function(StatsProvider) selector,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return Selector<StatsProvider, T>(
      selector: (_, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }

  final WorkProvider _workProvider;
  final BorrowProvider _borrowProvider;
  final SettlementProvider _settlementProvider;

  StatsProvider(
    this._workProvider,
    this._borrowProvider,
    this._settlementProvider,
  );

  ProjectSummary getProjectSummary(String projectId) {
    final workRecords = _workProvider.getRecordsByProject(projectId);
    final totalDays = workRecords
        .where((r) => !r.isRest)
        .fold(0.0, (sum, r) {
      switch (r.type) {
        case WorkType.point:
          return sum + r.days;
        case WorkType.packageDay:
          return sum + r.packageDays;
        case WorkType.packageQty:
          return sum + (r.quantity > 0 ? 1.0 : 0.0);
      }
    });

    final totalWage = workRecords.fold(0.0, (sum, r) => sum + r.totalWage);
    final totalBorrowed = _borrowProvider.getTotalBorrowedByProject(projectId);

    final settlements = _settlementProvider.getSettlementsByProject(projectId);
    final totalSettled = settlements.fold(0.0, (sum, s) => sum + s.amount);

    return ProjectSummary(
      totalDays: totalDays,
      totalWage: totalWage,
      totalBorrowed: totalBorrowed,
      totalSettled: totalSettled,
      unpaidWage: totalWage - totalBorrowed - totalSettled,
    );
  }

  MonthlyStats getMonthlyStats(
    String projectId,
    int year,
    int month,
  ) {
    final records = _workProvider.getRecordsByMonth(projectId, year, month);
    final workRecords = records.where((r) => !r.isRest).toList();

    final workDays = workRecords.fold(0.0, (sum, r) {
      switch (r.type) {
        case WorkType.point:
          return sum + r.days;
        case WorkType.packageDay:
          return sum + r.packageDays;
        case WorkType.packageQty:
          return sum + (r.quantity > 0 ? 1.0 : 0.0);
      }
    });
    final overtimeHours = workRecords.fold(
      0.0,
      (sum, r) => sum + r.overtimeHours,
    );
    final totalIncome = records.fold(0.0, (sum, r) => sum + r.totalWage);

    final borrowRecords = _borrowProvider.getRecordsByProject(projectId);
    final monthBorrows = borrowRecords.where((r) =>
        r.date.year == year && r.date.month == month);
    final borrowAmount = monthBorrows.fold(0.0, (sum, r) => sum + r.amount);

    // 未结 = 当月工资 - 当月借支 - 当月结算（当月口径，与面板其它指标一致）
    final settlementRecords = _settlementProvider.getSettlementsByProject(projectId);
    final monthSettlements = settlementRecords.where((s) =>
        s.date.year == year && s.date.month == month);
    final settlementAmount = monthSettlements.fold(0.0, (sum, s) => sum + s.amount);
    final unpaidAmount = totalIncome - borrowAmount - settlementAmount;

    return MonthlyStats(
      workDays: workDays,
      overtimeHours: overtimeHours,
      totalIncome: totalIncome,
      borrowAmount: borrowAmount,
      unpaidAmount: unpaidAmount,
    );
  }

  Map<DateTime, AttendanceStatus> getMonthlyAttendance(
    String projectId,
    int year,
    int month,
  ) {
    final records = _workProvider.getRecordsByMonth(projectId, year, month);
    final result = <DateTime, AttendanceStatus>{};

    for (final record in records) {
      final dateKey = DateTime(year, month, record.date.day);
      if (record.isRest) {
        result[dateKey] = AttendanceStatus.rest;
      } else {
        // 加班是出勤日的注解，不单独作为状态；有加班的出勤日仍归为出勤(worked)
        result[dateKey] = AttendanceStatus.worked;
      }
    }

    return result;
  }
}
