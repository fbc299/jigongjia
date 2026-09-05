import 'package:flutter/foundation.dart';
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
  final int workDays;
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

    final workDays = workRecords.length;
    final overtimeHours = workRecords.fold(
      0.0,
      (sum, r) => sum + r.overtimeHours,
    );
    final totalIncome = records.fold(0.0, (sum, r) => sum + r.totalWage);

    final borrowRecords = _borrowProvider.getRecordsByProject(projectId);
    final monthBorrows = borrowRecords.where((r) =>
        r.date.year == year && r.date.month == month);
    final borrowAmount = monthBorrows.fold(0.0, (sum, r) => sum + r.amount);

    // Unpaid = total wage from all project records - total borrowed - total settled
    final allWorkRecords = _workProvider.getRecordsByProject(projectId);
    final totalWageAll = allWorkRecords.fold(0.0, (sum, r) => sum + r.totalWage);
    final totalBorrowedAll = _borrowProvider.getTotalBorrowedByProject(projectId);
    final settlements = _settlementProvider.getSettlementsByProject(projectId);
    final totalSettledAll = settlements.fold(0.0, (sum, s) => sum + s.amount);
    final unpaidAmount = totalWageAll - totalBorrowedAll - totalSettledAll;

    return MonthlyStats(
      workDays: workDays,
      overtimeHours: overtimeHours,
      totalIncome: totalIncome,
      borrowAmount: borrowAmount,
      unpaidAmount: unpaidAmount < 0 ? 0 : unpaidAmount,
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
      } else if (record.overtimeHours > 0) {
        result[dateKey] = AttendanceStatus.overtime;
      } else {
        result[dateKey] = AttendanceStatus.worked;
      }
    }

    return result;
  }
}
