import '../../models/work_record.dart';

/// 工天口径的唯一实现。
///
/// 规则（**按天合并**，不是逐条相加）：
///   - 点工按 `days`、包工按天按 `packageDays` 累加
///   - 包工按量本身不产生工天：同一天只要有点工/包工按天，就不再计；整天只有计件则记 1 天
///   - 休息日不计
///
/// 为什么必须按天合并：一天可以有多条记录（上午点工 + 下午计件、一天两批货），
/// 逐条相加会把「同一天两条计件」算成 2 工天，月度出勤虚高。
/// 统计页、记工页月度条、PDF 汇总、CSV 导出都必须走这里，否则口径会漂移。
double sumWorkDays(Iterable<WorkRecord> records) {
  final dayDays = <int, double>{}; // 当天已有的「计工天」合计（点工 + 包工按天）
  final qtyOnlyDays = <int>{}; // 当天有计件记录

  for (final r in records) {
    if (r.isRest) continue;
    final key = _dayKey(r.date);
    switch (r.type) {
      case WorkType.point:
        dayDays[key] = (dayDays[key] ?? 0) + r.days;
        break;
      case WorkType.packageDay:
        dayDays[key] = (dayDays[key] ?? 0) + r.packageDays;
        break;
      case WorkType.packageQty:
        if (r.quantity > 0) qtyOnlyDays.add(key);
        break;
    }
  }

  var total = dayDays.values.fold<double>(0, (sum, v) => sum + v);
  // 整天只有计件记录 → 记 1 天；当天已有计工天的记录则不再叠加
  for (final key in qtyOnlyDays) {
    if (!dayDays.containsKey(key)) total += 1.0;
  }
  return total;
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// 工天展示：整数不带小数点（3 → "3"），半天保留一位（2.5 → "2.5"）
String formatDays(double days) =>
    days == days.roundToDouble() ? days.toInt().toString() : days.toStringAsFixed(1);
