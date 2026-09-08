import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../models/work_record.dart';

class PdfUtil {
  PdfUtil._();

  static Future<Uint8List> generateAttendancePdf(
    String projectName,
    int year,
    int month,
    List<WorkRecord> records,
  ) async {
    try {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy年MM月');

    // Build attendance map: day -> WorkRecord
    final recordMap = <int, WorkRecord>{};
    for (final r in records) {
      if (r.date.year == year && r.date.month == month) {
        recordMap[r.date.day] = r;
      }
    }

    // Calculate summary
    final workRecords = records.where((r) => !r.isRest).toList();
    final totalWorkDays = workRecords.length;
    final totalOvertimeHours = workRecords.fold(
      0.0,
      (sum, r) => sum + r.overtimeHours,
    );
    final totalIncome = records.fold(0.0, (sum, r) => sum + r.totalWage);

    // Calendar setup
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday; // 1=Mon, 7=Sun

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              projectName,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${dateFormat.format(firstDay)} 考勤表',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            '第 ${context.pageNumber} / ${context.pagesCount} 页',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          // Calendar header row
          _buildCalendarHeader(),
          pw.SizedBox(height: 4),
          // Calendar grid
          _buildCalendarGrid(
            firstWeekday: firstWeekday,
            daysInMonth: daysInMonth,
            recordMap: recordMap,
          ),
          pw.SizedBox(height: 24),
          // Legend
          _buildLegend(),
          pw.SizedBox(height: 16),
          // Summary
          _buildSummary(totalWorkDays, totalOvertimeHours, totalIncome),
          pw.SizedBox(height: 16),
          // Detail table
          _buildDetailTable(records),
        ],
      ),
    );

    return pdf.save();
    } catch (e) {
      print('生成PDF失败: $e');
      rethrow;
    }
  }

  static pw.Widget _buildCalendarHeader() {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return pw.Row(
      children: weekdays.map((day) {
        return pw.Expanded(
          child: pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Text(
              day,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildCalendarGrid({
    required int firstWeekday,
    required int daysInMonth,
    required Map<int, WorkRecord> recordMap,
  }) {
    final rows = <pw.Widget>[];
    int currentDay = 1;
    bool started = false;

    for (int week = 0; week < 6; week++) {
      if (currentDay > daysInMonth) break;

      final cells = <pw.Widget>[];
      for (int weekday = 1; weekday <= 7; weekday++) {
        if (!started && weekday == firstWeekday) {
          started = true;
        }

        if (!started || currentDay > daysInMonth) {
          cells.add(pw.Expanded(
            child: pw.Container(
              height: 42,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
            ),
          ));
        } else {
          final record = recordMap[currentDay];
          final cellColor = _getCellColor(record);
          final statusText = _getStatusText(record);

          cells.add(pw.Expanded(
            child: pw.Container(
              height: 42,
              decoration: pw.BoxDecoration(
                color: cellColor,
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              padding: const pw.EdgeInsets.all(2),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    '$currentDay',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (statusText.isNotEmpty)
                    pw.Text(
                      statusText,
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey800,
                      ),
                    ),
                ],
              ),
            ),
          ));
          currentDay++;
        }
      }

      rows.add(pw.Row(children: cells));
    }

    return pw.Column(children: rows);
  }

  static PdfColor? _getCellColor(WorkRecord? record) {
    if (record == null) return null;
    if (record.isRest) return PdfColors.blue100;
    if (record.overtimeHours > 0) return PdfColors.orange100;
    return PdfColors.green100;
  }

  static String _getStatusText(WorkRecord? record) {
    if (record == null) return '';
    if (record.isRest) return '休';
    if (record.overtimeHours > 0) return '加班';
    return '✓';
  }

  static pw.Widget _buildLegend() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        _legendItem(PdfColors.green100, '出勤'),
        pw.SizedBox(width: 16),
        _legendItem(PdfColors.orange100, '加班'),
        pw.SizedBox(width: 16),
        _legendItem(PdfColors.blue100, '休息'),
      ],
    );
  }

  static pw.Widget _legendItem(PdfColor color, String label) {
    return pw.Row(
      children: [
        pw.Container(
          width: 14,
          height: 14,
          decoration: pw.BoxDecoration(
            color: color,
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static pw.Widget _buildSummary(
    int workDays,
    double overtimeHours,
    double totalIncome,
  ) {
    final numberFormat = NumberFormat('#,##0.00');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '月度汇总',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('出勤天数', '$workDays 天'),
              _summaryItem('加班时长', '${overtimeHours.toStringAsFixed(1)} 小时'),
              _summaryItem('总收入', '¥${numberFormat.format(totalIncome)}'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildDetailTable(List<WorkRecord> records) {
    if (records.isEmpty) {
      return pw.Container();
    }

    final sortedRecords = List<WorkRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));
    final dateFormat = DateFormat('MM/dd');
    final numberFormat = NumberFormat('#,##0.00');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '详细记录',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          cellAlignment: pw.Alignment.center,
          headerAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
          },
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(2),
          },
          headers: ['日期', '类型', '工时/数量', '工资', '备注'],
          data: sortedRecords.map((r) {
            final typeLabel = r.isRest
                ? '休息'
                : r.type == WorkType.point
                    ? '点工'
                    : r.type == WorkType.packageDay
                        ? '包工(天)'
                        : '包工(量)';

            String workInfo;
            if (r.isRest) {
              workInfo = '-';
            } else if (r.type == WorkType.point) {
              workInfo = '${r.days}天';
              if (r.overtimeHours > 0) {
                workInfo += ' +${r.overtimeHours}h加班';
              }
            } else if (r.type == WorkType.packageDay) {
              workInfo = '${r.packageDays}天';
            } else {
              workInfo = '${r.quantity}${r.qtyUnit}';
            }

            return [
              dateFormat.format(r.date),
              typeLabel,
              workInfo,
              '¥${numberFormat.format(r.totalWage)}',
              r.note.isEmpty ? '-' : r.note,
            ];
          }).toList(),
        ),
      ],
    );
  }
}
