import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../core/utils/work_stats.dart';

import 'work_provider.dart';
import 'borrow_provider.dart';
import 'settlement_provider.dart';

// 工天口径统一在 work_stats.dart，这里 re-export 方便既有的 stats_provider 引用方
// （stats_screen / work_entry_screen）继续拿到 sumWorkDays / formatDays。
export '../core/utils/work_stats.dart';

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
  ) {
    // StatsProvider 自己算不出变化，必须跟随三个数据源通知，
    // 否则 Consumer/watch<StatsProvider> 的界面永远不刷新（只在碰巧父级重建时才对）。
    _workProvider.addListener(notifyListeners);
    _borrowProvider.addListener(notifyListeners);
    _settlementProvider.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _workProvider.removeListener(notifyListeners);
    _borrowProvider.removeListener(notifyListeners);
    _settlementProvider.removeListener(notifyListeners);
    super.dispose();
  }

  ProjectSummary getProjectSummary(String projectId) {
    final workRecords = _workProvider.getRecordsByProject(projectId);
    // 工天统一口径（点工 days / 包工 packageDays / 包工按量 1 天），与月度统计共用
    final totalDays = sumWorkDays(workRecords);
    final totalWage = workRecords.fold(0.0, (sum, r) => sum + r.totalWage);
    final totalBorrowed = _borrowProvider.getTotalBorrowedByProject(projectId);

    final settlements = _settlementProvider.getSettlementsByProject(projectId);
    final totalSettled = settlements.fold(0.0, (sum, s) => sum + s.amount);

    return ProjectSummary(
      totalDays: totalDays,
      totalWage: totalWage,
      totalBorrowed: totalBorrowed,
      totalSettled: totalSettled,
      unpaidWage: _rawUnpaid(projectId),
    );
  }

  /// 未结工资原始口径（不截断）：全时段总工资 - 总借支 - 总已结算。
  /// 统一在 getProjectSummary 与 getMonthlyStats 间复用，避免两处实现漂移。
  double _rawUnpaid(String projectId) {
    final totalWageAll =
        _workProvider.getRecordsByProject(projectId).fold(
            0.0, (sum, r) => sum + r.totalWage);
    final totalBorrowedAll =
        _borrowProvider.getTotalBorrowedByProject(projectId);
    final totalSettledAll =
        _settlementProvider.getSettlementsByProject(projectId).fold(
            0.0, (sum, s) => sum + s.amount);
    return totalWageAll - totalBorrowedAll - totalSettledAll;
  }

  MonthlyStats getMonthlyStats(
    String projectId,
    int year,
    int month,
  ) {
    final records = _workProvider.getRecordsByMonth(projectId, year, month);
    final workRecords = records.where((r) => !r.isRest).toList();

    final workDays = sumWorkDays(workRecords);
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
    final unpaidAmount = _rawUnpaid(projectId);

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
