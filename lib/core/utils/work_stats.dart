import '../../models/work_record.dart';

/// 工天口径的唯一实现。
///
/// 点工按 `days`、包工按天按 `packageDays`、包工按量按 1 天（有数量即算 1 天），
/// 休息日不计。统计页、记工页月度条、PDF 汇总都必须走这里，
/// 否则会出现「月度统计半天记工算 1 天、项目详情算 0.5 天」这类口径漂移。
double sumWorkDays(Iterable<WorkRecord> records) {
  return records.where((r) => !r.isRest).fold(0.0, (sum, r) {
    switch (r.type) {
      case WorkType.point:
        return sum + r.days;
      case WorkType.packageDay:
        return sum + r.packageDays;
      case WorkType.packageQty:
        return sum + (r.quantity > 0 ? 1.0 : 0.0);
    }
  });
}

/// 工天展示：整数不带小数点（3 → "3"），半天保留一位（2.5 → "2.5"）
String formatDays(double days) =>
    days == days.roundToDouble() ? days.toInt().toString() : days.toStringAsFixed(1);
