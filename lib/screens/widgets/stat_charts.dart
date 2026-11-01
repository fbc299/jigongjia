import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/work_stats.dart';
import '../../models/work_record.dart';

/// 单月每日工资柱状图（从 stats_screen 拆出）。
class DailyWageChart extends StatelessWidget {
  final List<WorkRecord> records;
  final DateTime month;

  const DailyWageChart({super.key, required this.records, required this.month});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('本月暂无记录'));
    }

    final dayWages = <int, double>{};
    for (final r in records) {
      dayWages[r.date.day] = (dayWages[r.date.day] ?? 0) + r.totalWage;
    }

    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final barGroups = <BarChartGroupData>[];

    for (int day = 1; day <= lastDay; day++) {
      final wage = dayWages[day] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: day,
          barRods: [
            BarChartRodData(
              toY: wage,
              color: wage > 0
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade200,
              width: 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: dayWages.values.isEmpty
            ? 100
            : (dayWages.values.reduce((a, b) => a > b ? a : b) * 1.2),
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(),
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day % 5 == 1 || day == 1 || day == lastDay) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('$day', style: const TextStyle(fontSize: 9)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 100,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

/// 近 N 个月工天/收入趋势柱状图（从 stats_screen 拆出）。
class MonthlyTrendChart extends StatelessWidget {
  /// 升序月份，最后一根是当前月
  final List<DateTime> months;
  /// 与 months 一一对应的数值
  final List<double> values;
  /// true=工天，false=金额
  final bool isDays;
  final DateTime currentMonth;

  const MonthlyTrendChart({
    super.key,
    required this.months,
    required this.values,
    required this.isDays,
    required this.currentMonth,
  });

  @override
  Widget build(BuildContext context) {
    double maxValue = 0;
    for (final v in values) {
      if (v > maxValue) maxValue = v;
    }
    if (maxValue <= 0) {
      return const Center(child: Text('近 6 个月暂无记录'));
    }

    final primary = Theme.of(context).colorScheme.primary;
    final currentKey = DateTime(currentMonth.year, currentMonth.month);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.25,
        barGroups: [
          for (int i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 22,
                  color: months[i] == currentKey ? primary : primary.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                final text = isDays
                    ? formatDays(value)
                    : (value >= 1000
                        ? '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k'
                        : value.toInt().toString());
                return Text(text, style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${months[i].month}月',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: months[i] == currentKey ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final m = months[group.x];
              final v = rod.toY;
              return BarTooltipItem(
                '${m.year}年${m.month}月\n'
                '${isDays ? '${formatDays(v)} 工天' : '¥${NumberFormat('#,##0.00').format(v)}'}',
                const TextStyle(fontSize: 11, color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
