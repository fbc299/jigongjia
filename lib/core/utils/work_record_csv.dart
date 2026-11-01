import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/work_record.dart';
import 'work_stats.dart';

/// 记工记录导出为 CSV（工头/家里人用 Excel 看）。
///
/// 用 UTF-8 BOM 开头，否则 Windows Excel 打开中文会乱码；
/// 字段里含逗号/换行/引号时按 RFC 4180 加引号转义。
class WorkRecordCsv {
  static const _bom = '\uFEFF';

  static String build({
    required List<WorkRecord> records,
    required Map<String, String> projectNames,
  }) {
    final buffer = StringBuffer(_bom);
    buffer.writeln('日期,项目,类型,工天,加班(小时),金额(元),备注');

    for (final r in records) {
      final cells = <String>[
        DateFormat('yyyy-MM-dd').format(r.date),
        projectNames[r.projectId] ?? '未知项目',
        _typeText(r),
        r.isRest ? '0' : _num(r.type == WorkType.point ? r.days : (r.type == WorkType.packageDay ? r.packageDays : r.quantity)),
        _num(r.overtimeHours),
        r.totalWage.toStringAsFixed(2),
        r.note,
      ];
      buffer.writeln(cells.map(_escape).join(','));
    }

    // 与统计页/PDF 同一口径（半天算 0.5，包工按量当天算 1）
    final totalDays = sumWorkDays(records.where((r) => !r.isRest).toList());
    final totalWage = records.fold<double>(0, (sum, r) => sum + r.totalWage);
    buffer.writeln('合计,,,${_num(totalDays)},,${totalWage.toStringAsFixed(2)},共 ${records.length} 条');

    return buffer.toString();
  }

  /// 写临时文件，返回路径（分享用）。
  static Future<String> writeToTempFile({
    required List<WorkRecord> records,
    required Map<String, String> projectNames,
  }) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/格格记工_记录_$stamp.csv');
    await file.writeAsString(build(records: records, projectNames: projectNames), flush: true);
    return file.path;
  }

  static String _typeText(WorkRecord r) {
    if (r.isRest) return '休息';
    switch (r.type) {
      case WorkType.point:
        return '点工';
      case WorkType.packageDay:
        return '包工(天)';
      case WorkType.packageQty:
        return '包工(${r.qtyUnit})';
    }
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static String _escape(String raw) {
    if (raw.contains(',') || raw.contains('"') || raw.contains('\n') || raw.contains('\r')) {
      return '"${raw.replaceAll('"', '""')}"';
    }
    return raw;
  }
}
