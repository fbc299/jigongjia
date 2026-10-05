import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:jigongjia/core/utils/privacy_service.dart';
import 'package:printing/printing.dart';

import '../providers/project_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/work_provider.dart';
import '../providers/borrow_provider.dart';
import '../providers/settlement_provider.dart';
import '../models/work_record.dart';
import '../core/utils/pdf_util.dart';
import 'widgets/stat_card.dart';
import 'widgets/record_tile.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedProjectId;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final projects = projectProvider.activeProjects;

    if (_selectedProjectId == null && projects.isNotEmpty) {
      _selectedProjectId = projects.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
                actions: [
                  ValueListenableBuilder<bool>(
                    valueListenable: PrivacyService().isHidden,
                    builder: (_, hidden, __) => IconButton(
                      icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => PrivacyService().toggle(),
                    ),
                  ),
                ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '考勤表'),
            Tab(text: '记工统计'),
            Tab(text: '记工流水'),
            Tab(text: '未结工资'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(projects),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceTab(),
                _buildStatsTab(),
                _buildFlowTab(),
                _buildUnpaidTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List projects) {
    final monthFormat = DateFormat('yyyy年MM月');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevMonth,
          ),
          Text(
            monthFormat.format(_currentMonth),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedProjectId,
              isDense: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                labelText: '项目',
              ),
              items: projects
                  .map<DropdownMenuItem<String>>(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedProjectId = v;
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 考勤表 Tab =====================

  Widget _buildAttendanceTab() {
    if (_selectedProjectId == null) {
      return const Center(child: Text('请先创建项目'));
    }
    final statsProvider = context.watch<StatsProvider>();
    final attendance = statsProvider.getMonthlyAttendance(
      _selectedProjectId!,
      _currentMonth.year,
      _currentMonth.month,
    );
    final workProvider = context.watch<WorkProvider>();
    final records = workProvider.getRecordsByMonth(
      _selectedProjectId!,
      _currentMonth.year,
      _currentMonth.month,
    );

    final workDays = records.where((r) => !r.isRest).length;
    final overtimeDays = records.where((r) => r.overtimeHours > 0).length;
    final totalOvertimeHours = records.fold<double>(0, (sum, r) => sum + r.overtimeHours);
    final restDays = records.where((r) => r.isRest).length;
    final totalDays = records.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildWeekdayHeader(),
                const SizedBox(height: 4),
                _buildCalendarGrid(attendance, records),
                const SizedBox(height: 16),
                _buildAttendanceLegend(),
                const SizedBox(height: 12),
                _buildAttendanceSummary(
                    workDays, overtimeDays, totalOvertimeHours, restDays, totalDays),
              ],
            ),
          ),
        ),
        _buildExportButton(),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: days
          .map((d) => Expanded(
                child: Center(
                  child: Text(d,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid(Map<DateTime, AttendanceStatus> attendance, List<WorkRecord> records) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday; // 1=Mon
    final totalCells = ((firstWeekday - 1) + daysInMonth);
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayOffset = index - (firstWeekday - 1);
        if (dayOffset < 0 || dayOffset >= daysInMonth) {
          return const SizedBox.shrink();
        }
        final day = dayOffset + 1;
        final dateKey =
            DateTime(_currentMonth.year, _currentMonth.month, day);
        final status = attendance[dateKey];
        final color = _statusColor(status);
        // 查找当天的记录，获取加班时长
        final dayRecord = records.where((r) => r.date.day == day && r.date.month == _currentMonth.month && r.date.year == _currentMonth.year).firstOrNull;
        final overtimeHours = dayRecord?.overtimeHours ?? 0;
        // 出勤日为绿色；加班是出勤日的注解，显示加班小时数但不再把状态改成 overtime
        final label = _statusLabel(status);
        final overtimeNote = status == AttendanceStatus.worked && overtimeHours > 0
            ? '${overtimeHours.toStringAsFixed(overtimeHours == overtimeHours.roundToDouble() ? 0 : 1)}小时'
            : '';

        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color?.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: status != null
                ? Border.all(color: color!, width: 1.5)
                : Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (label.isNotEmpty)
                Text(
                  label,
                  style: TextStyle(fontSize: 9, color: color),
                ),
              if (overtimeNote.isNotEmpty)
                Text(
                  overtimeNote,
                  style: TextStyle(fontSize: 9, color: color),
                ),
            ],
          ),
        );
      },
    );
  }

  Color? _statusColor(AttendanceStatus? status) {
    switch (status) {
      case AttendanceStatus.worked:
        return Colors.green;
      case AttendanceStatus.rest:
        return Colors.grey;
      case AttendanceStatus.overtime:
        return Colors.blue;
      case AttendanceStatus.absent:
        return Colors.red;
      case null:
        return null;
    }
  }

  String _statusLabel(AttendanceStatus? status) {
    switch (status) {
      case AttendanceStatus.worked:
        return '出勤';
      case AttendanceStatus.rest:
        return '休息';
      case AttendanceStatus.overtime:
        return '加班';
      case AttendanceStatus.absent:
        return '缺勤';
      case null:
        return '';
    }
  }

  Widget _buildAttendanceLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(Colors.green, '出勤'),
        const SizedBox(width: 16),
        _legendDot(Colors.blue, '加班'),
        const SizedBox(width: 16),
        _legendDot(Colors.grey, '休息'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAttendanceSummary(
      int workDays, int overtimeDays, double totalOvertimeHours, int restDays, int totalDays) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('出勤', '$workDays天', Colors.green),
            _summaryItem('加班', '${totalOvertimeHours.toStringAsFixed(totalOvertimeHours == totalOvertimeHours.roundToDouble() ? 0 : 1)}小时', Colors.blue),
            _summaryItem('休息', '$restDays天', Colors.grey),
            _summaryItem('总工天', '$totalDays天',
                Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildExportButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _selectedProjectId == null ? null : _exportPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('导出考勤表 PDF'),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectProvider = context.read<ProjectProvider>();
    final workProvider = context.read<WorkProvider>();
    final project =
        projectProvider.getProjectById(_selectedProjectId!);
    if (project == null) return;

    final records = workProvider.getRecordsByMonth(
      _selectedProjectId!,
      _currentMonth.year,
      _currentMonth.month,
    );

    try {
      final pdfBytes = await PdfUtil.generateAttendancePdf(
        project.name,
        _currentMonth.year,
        _currentMonth.month,
        records,
      );
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            '${project.name}_${_currentMonth.year}_${_currentMonth.month}_考勤表.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  // ===================== 记工统计 Tab =====================

  Widget _buildStatsTab() {
    if (_selectedProjectId == null) {
      return const Center(child: Text('请先创建项目'));
    }
    final statsProvider = context.watch<StatsProvider>();
    final monthlyStats = statsProvider.getMonthlyStats(
      _selectedProjectId!,
      _currentMonth.year,
      _currentMonth.month,
    );
    final workProvider = context.watch<WorkProvider>();
    final records = workProvider.getRecordsByMonth(
      _selectedProjectId!,
      _currentMonth.year,
      _currentMonth.month,
    );

    final numberFormat = NumberFormat('#,##0.00');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 36) / 2,
                child: StatCard(
                  icon: Icons.calendar_today,
                  label: '总工天',
                  value: '${monthlyStats.workDays % 1 == 0 ? monthlyStats.workDays.toInt() : monthlyStats.workDays}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 36) / 2,
                child: StatCard(
                  icon: Icons.access_time,
                  label: '加班时长',
                  value: '${monthlyStats.overtimeHours.toStringAsFixed(1)}小时',
                  color: Colors.blue,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 36) / 2,
                child: StatCard(
                  icon: Icons.payments,
                  label: '总收入',
                  value: '¥${numberFormat.format(monthlyStats.totalIncome)}',
                  color: Colors.green,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 36) / 2,
                child: StatCard(
                  icon: Icons.money_off,
                  label: '总借支',
                  value:
                      PrivacyService.format(monthlyStats.borrowAmount, hide: PrivacyService().isHidden.value),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatCard(
            icon: Icons.account_balance,
            label: '未结工资',
            value:
                PrivacyService.format(monthlyStats.unpaidAmount, hide: PrivacyService().isHidden.value),
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 20),
          Text('每日工资',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _buildDailyWageChart(records),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyWageChart(List<WorkRecord> records) {
    if (records.isEmpty) {
      return const Center(child: Text('本月暂无记录'));
    }

    // Build map day -> wage
    final dayWages = <int, double>{};
    for (final r in records) {
      dayWages[r.date.day] = (dayWages[r.date.day] ?? 0) + r.totalWage;
    }

    final lastDay =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
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
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 9),
                );
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
                    child: Text('$day',
                        style: const TextStyle(fontSize: 9)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

  // ===================== 记工流水 Tab =====================

  Widget _buildFlowTab() {
    final workProvider = context.watch<WorkProvider>();
    final borrowProvider = context.watch<BorrowProvider>();
    final settlementProvider = context.watch<SettlementProvider>();

    List<_FlowItem> items = [];

    // Work records
    final workRecords = _selectedProjectId != null
        ? workProvider.getRecordsByProject(_selectedProjectId!)
        : workProvider.records;
    for (final r in workRecords) {
      items.add(_FlowItem(
        date: r.date,
        type: FlowRecordType.work,
        amount: r.totalWage,
        note: r.isRest
            ? '休息'
            : (r.note.isNotEmpty ? r.note : _workTypeLabel(r.type)),
        id: r.id,
      ));
    }

    // Borrow records
    final borrowRecords = _selectedProjectId != null
        ? borrowProvider.getRecordsByProject(_selectedProjectId!)
        : borrowProvider.records;
    for (final r in borrowRecords) {
      items.add(_FlowItem(
        date: r.date,
        type: FlowRecordType.borrow,
        amount: r.amount,
        note: r.note,
        id: r.id,
      ));
    }

    // Settlement records
    final settlements = _selectedProjectId != null
        ? settlementProvider.getSettlementsByProject(_selectedProjectId!)
        : settlementProvider.settlements;
    for (final s in settlements) {
      items.add(_FlowItem(
        date: s.date,
        type: FlowRecordType.settlement,
        amount: s.amount,
        note: s.note,
        id: s.id,
      ));
    }

    items.sort((a, b) => b.date.compareTo(a.date));

    if (items.isEmpty) {
      return const Center(child: Text('暂无记录'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return RecordTile(
          date: item.date,
          recordType: _toRecordType(item.type),
          amount: item.amount,
          note: item.note,
        );
      },
    );
  }

  RecordType _toRecordType(FlowRecordType type) {
    switch (type) {
      case FlowRecordType.work:
        return RecordType.work;
      case FlowRecordType.borrow:
        return RecordType.borrow;
      case FlowRecordType.settlement:
        return RecordType.settlement;
    }
  }

  String _workTypeLabel(WorkType type) {
    switch (type) {
      case WorkType.point:
        return '点工';
      case WorkType.packageDay:
        return '包工(按天)';
      case WorkType.packageQty:
        return '包工(按量)';
    }
  }

  // ===================== 未结工资 Tab =====================

  Widget _buildUnpaidTab() {
    final projectProvider = context.watch<ProjectProvider>();
    final statsProvider = context.watch<StatsProvider>();
    final projects = projectProvider.activeProjects;

    if (projects.isEmpty) {
      return const Center(child: Text('暂无项目'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final summary = statsProvider.getProjectSummary(project.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _unpaidRow('总工资',
                    PrivacyService.format(summary.totalWage, hide: PrivacyService().isHidden.value)),
                _unpaidRow('总借支',
                                    PrivacyService.format(summary.totalBorrowed, hide: PrivacyService().isHidden.value),
                                    valueColor: Colors.orange),
                _unpaidRow('已结算',
                                    PrivacyService.format(summary.totalSettled, hide: PrivacyService().isHidden.value),
                                    valueColor: Colors.green),
                const Divider(),
                _unpaidRow(
                                  '未结工资',
                                  PrivacyService.format(summary.unpaidWage, hide: PrivacyService().isHidden.value),
                                  valueColor: Colors.red,
                                  bold: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _unpaidRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
              fontSize: bold ? 16 : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Internal helpers =====================

enum FlowRecordType { work, borrow, settlement }

class _FlowItem {
  final DateTime date;
  final FlowRecordType type;
  final double amount;
  final String note;
  final String id;

  const _FlowItem({
    required this.date,
    required this.type,
    required this.amount,
    required this.note,
    required this.id,
  });
}
