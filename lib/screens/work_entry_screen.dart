import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:jigongjia/models/project.dart';
import 'package:jigongjia/models/work_record.dart';
import 'package:jigongjia/core/utils/privacy_service.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/stats_provider.dart';
import 'package:jigongjia/screens/widgets/work_type_selector.dart';
import 'package:jigongjia/screens/widgets/time_input_panel.dart';
import 'package:jigongjia/screens/widgets/summary_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Calendar-style work entry page
/// Shows a monthly calendar, tap any day to add/edit work record
class WorkEntryScreen extends StatefulWidget {
  final String projectId;
  final Project project;
  final DateTime? initialDate;

  const WorkEntryScreen({
    super.key,
    required this.projectId,
    required this.project,
    this.initialDate,
  });

  @override
  State<WorkEntryScreen> createState() => _WorkEntryScreenState();
}

class _WorkEntryScreenState extends State<WorkEntryScreen> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        title: _buildProjectSelector(context),
        backgroundColor: const Color(0xFFF8F6F2),
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: PrivacyService().isHidden,
            builder: (_, hidden, __) => IconButton(
              icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
              onPressed: () => PrivacyService().toggle(),
            ),
          ),
        ],
      ),
      body: Consumer<WorkProvider>(
        builder: (context, workProv, _) {
          final records = workProv.getRecordsByProject(widget.projectId);
          final recordMap = <String, WorkRecord>{};
          for (final r in records) {
            final key = '${r.date.year}-${r.date.month}-${r.date.day}';
            recordMap[key] = r;
          }

          return Column(
            children: [
              // Month navigation
              _buildMonthNav(theme),
              // 当月统计面板
              _MonthlyStatsPanel(
                projectId: widget.projectId,
                year: _currentMonth.year,
                month: _currentMonth.month,
              ),
              const SizedBox(height: 8),
              // Weekday headers
              _buildWeekdayHeaders(theme),
              const SizedBox(height: 4),
              // Calendar grid
              Expanded(
                child: _buildCalendarGrid(theme, recordMap),
              ),
              // Selected day detail
              _buildSelectedDayPanel(theme, recordMap),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openWorkForm(_selectedDate),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProjectSelector(BuildContext context) {
    final projects = context.watch<ProjectProvider>().activeProjects;
    // Find current project in list
    final current = projects.where((p) => p.id == widget.projectId).toList();
    final displayProject = current.isNotEmpty ? current.first : widget.project;

    return DropdownButton<String>(
      value: displayProject.id,
      underline: const SizedBox(),
      isDense: true,
      icon: const Icon(Icons.unfold_more, size: 20),
      items: projects.map((p) {
        return DropdownMenuItem(
          value: p.id,
          child: Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        );
      }).toList(),
      onChanged: (newId) {
        if (newId != null && newId != widget.projectId) {
          final newProject = projects.firstWhere((p) => p.id == newId);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => WorkEntryScreen(
                projectId: newId,
                project: newProject,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildMonthNav(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
              });
            },
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _currentMonth,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  _currentMonth = DateTime(picked.year, picked.month);
                  _selectedDate = picked;
                });
              }
            },
            child: Text(
              DateFormat('yyyy年M月').format(_currentMonth),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders(ThemeData theme) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: days.map((d) {
          final isWeekend = d == '六' || d == '日';
          return Expanded(
            child: Center(
              child: Text(
                d,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isWeekend ? Colors.red[300] : Colors.grey[600],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme, Map<String, WorkRecord> recordMap) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    // Monday = 1, Sunday = 7
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalDays = lastDay.day;
    final totalCells = startOffset + totalDays;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 0.85,
        ),
        itemCount: rows * 7,
        itemBuilder: (context, index) {
          if (index < startOffset || index >= startOffset + totalDays) {
            return const SizedBox();
          }

          final day = index - startOffset + 1;
          final date = DateTime(_currentMonth.year, _currentMonth.month, day);
          final key = '${date.year}-${date.month}-${date.day}';
          final record = recordMap[key];
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
          final isToday = date.year == DateTime.now().year &&
              date.month == DateTime.now().month &&
              date.day == DateTime.now().day;
          final isWeekend = date.weekday == 6 || date.weekday == 7;

          return GestureDetector(
            onTap: () {
              if (record != null) {
                // Has record → open edit form directly
                _openWorkForm(date, existingRecord: record);
              } else {
                setState(() => _selectedDate = date);
              }
            },
            onDoubleTap: record == null ? () => _openWorkForm(date) : null,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : (record != null ? Colors.white : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? theme.colorScheme.primary
                      : (isSelected
                          ? theme.colorScheme.primary.withOpacity(0.4)
                          : Colors.grey.withOpacity(0.08)),
                  width: isToday ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isWeekend
                          ? Colors.red[400]
                          : (isSelected
                              ? theme.colorScheme.primary
                              : Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Status indicator
                  if (record != null)
                    _buildRecordIndicator(record, theme)
                  else
                    const SizedBox(height: 14),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordIndicator(WorkRecord record, ThemeData theme) {
    if (record.isRest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('休', style: TextStyle(fontSize: 9, color: Colors.orange)),
      );
    }

    Color color;
    String label;
    if (record.type == WorkType.point) {
      color = theme.colorScheme.primary;
      label = record.days == 0.5 ? '半' : (record.overtimeHours > 0 ? '${record.overtimeHours.toStringAsFixed(record.overtimeHours == record.overtimeHours.roundToDouble() ? 0 : 1)}小时' : '');
    } else if (record.type == WorkType.packageDay) {
      color = Colors.teal;
      label = '包';
    } else {
      color = Colors.indigo;
      label = '量';
    }

    return Column(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        if (label.isNotEmpty)
          Text(label, style: TextStyle(fontSize: 9, color: color)),
      ],
    );
  }

  Widget _buildSelectedDayPanel(ThemeData theme, Map<String, WorkRecord> recordMap) {
    final key = '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    final record = recordMap[key];
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][_selectedDate.weekday - 1];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: record == null
          ? _buildEmptyDay(theme, weekday)
          : _buildRecordDetail(record, theme, weekday),
    );
  }

  Widget _buildEmptyDay(ThemeData theme, String weekday) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedDate.month}月${_selectedDate.day}日 星期$weekday',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '点击 + 记录今天的工作',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _openWorkForm(_selectedDate),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('记工'),
        ),
      ],
    );
  }

  Widget _buildRecordDetail(WorkRecord record, ThemeData theme, String weekday) {
    String desc;
    IconData icon;
    Color color;

    if (record.isRest) {
      desc = '休息日';
      icon = Icons.hotel;
      color = Colors.orange;
    } else if (record.type == WorkType.point) {
      desc = '${record.days}天';
      if (record.overtimeHours > 0) desc += ' + 加班${record.overtimeHours.toStringAsFixed(record.overtimeHours == record.overtimeHours.roundToDouble() ? 0 : 1)}小时';
      desc += ' · ${PrivacyService.format(record.dailyRate, hide: PrivacyService().isHidden.value)}/天';
      icon = Icons.engineering;
      color = theme.colorScheme.primary;
    } else if (record.type == WorkType.packageDay) {
      desc = '包工 ${record.packageDays}天 · ${PrivacyService.format(record.packageDayRate, hide: PrivacyService().isHidden.value)}/天';
      icon = Icons.calendar_view_day;
      color = Colors.teal;
    } else {
      desc = '包工 ${record.quantity}${record.qtyUnit} · ¥${record.qtyUnitPrice}/${record.qtyUnit}';
      icon = Icons.straighten;
      color = Colors.indigo;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${_selectedDate.month}月${_selectedDate.day}日 星期$weekday',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 16, color: color),
                ],
              ),
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              if (record.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    record.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.isRest ? '—' : PrivacyService.format(record.totalWage, hide: PrivacyService().isHidden.value),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: record.isRest ? Colors.grey[400] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _openWorkForm(_selectedDate, existingRecord: record),
              child: Text(
                '编辑',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openWorkForm(DateTime date, {WorkRecord? existingRecord}) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => _WorkFormSheet(
          projectId: widget.projectId,
          project: widget.project,
          date: date,
          existingRecord: existingRecord,
        ),
      ),
    )
        .then((_) {
      // Force rebuild to refresh calendar markers
      setState(() {});
    });
  }
}

/// Bottom sheet style work form for quick entry
class _WorkFormSheet extends StatefulWidget {
  final String projectId;
  final Project project;
  final DateTime date;
  final WorkRecord? existingRecord;

  const _WorkFormSheet({
    required this.projectId,
    required this.project,
    required this.date,
    this.existingRecord,
  });

  @override
  State<_WorkFormSheet> createState() => _WorkFormSheetState();
}

class _WorkFormSheetState extends State<_WorkFormSheet> {
  late WorkType _workType;
  SharedPreferences? _prefs;
  bool _isRest = false;
  double _days = 1.0;
  double _overtimeHours = 0.0;
  final _dailyRateCtrl = TextEditingController();
  final _overtimeRateCtrl = TextEditingController();
  final _packageDaysCtrl = TextEditingController();
  final _packageDayRateCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  String _qtyUnit = '平方';
  final _qtyUnitPriceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  bool get _isEdit => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRecord;
    if (r != null) {
      _workType = r.type;
      _isRest = r.isRest;
      _days = r.days;
      _overtimeHours = r.overtimeHours;
      _dailyRateCtrl.text = _fmt(r.dailyRate);
      _overtimeRateCtrl.text = _fmt(r.overtimeRate);
      _packageDaysCtrl.text = _fmt(r.packageDays);
      _packageDayRateCtrl.text = _fmt(r.packageDayRate);
      _quantityCtrl.text = _fmt(r.quantity);
      _qtyUnit = r.qtyUnit.isNotEmpty ? r.qtyUnit : '平方';
      _qtyUnitPriceCtrl.text = _fmt(r.qtyUnitPrice);
      _noteCtrl.text = r.note;
    } else {
      _workType = WorkType.point;
      _packageDaysCtrl.text = '1';
      _loadSavedRates();
    }
  }

  @override
  void dispose() {
    _dailyRateCtrl.dispose();
    _overtimeRateCtrl.dispose();
    _packageDaysCtrl.dispose();
    _packageDayRateCtrl.dispose();
    _quantityCtrl.dispose();
    _qtyUnitPriceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double _p(String s) => double.tryParse(s.trim()) ?? 0;

  double get _wage {
    if (_isRest) return 0;
    switch (_workType) {
      case WorkType.point:
        return _days * _p(_dailyRateCtrl.text) + _overtimeHours * _p(_overtimeRateCtrl.text);
      case WorkType.packageDay:
        return _p(_packageDaysCtrl.text) * _p(_packageDayRateCtrl.text);
      case WorkType.packageQty:
        return _p(_quantityCtrl.text) * _p(_qtyUnitPriceCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][widget.date.weekday - 1];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.date.month}月${widget.date.day}日 周$weekday'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Work type selector + rest toggle
          WorkTypeSelector(
            workType: _workType,
            isRest: _isRest,
            onWorkTypeChanged: (t) => setState(() => _workType = t),
            onRestChanged: (v) => setState(() => _isRest = v),
          ),

          if (!_isRest) ...[
            const SizedBox(height: 8),
            if (_workType == WorkType.point)
              TimeInputPanel(
                days: _days,
                overtimeHours: _overtimeHours,
                dailyRateCtrl: _dailyRateCtrl,
                overtimeRateCtrl: _overtimeRateCtrl,
                onDaysChanged: (d) => setState(() => _days = d),
                onOvertimeHoursChanged: (v) => setState(() => _overtimeHours = v),
                onAnyFieldChanged: () => setState(() {}),
              ),
            if (_workType == WorkType.packageDay)
              PackageDayInputPanel(
                packageDaysCtrl: _packageDaysCtrl,
                packageDayRateCtrl: _packageDayRateCtrl,
                onAnyFieldChanged: () => setState(() {}),
              ),
            if (_workType == WorkType.packageQty)
              PackageQtyInputPanel(
                quantityCtrl: _quantityCtrl,
                qtyUnit: _qtyUnit,
                qtyUnitPriceCtrl: _qtyUnitPriceCtrl,
                onQtyUnitChanged: (v) => setState(() => _qtyUnit = v),
                onAnyFieldChanged: () => setState(() {}),
              ),
          ],

          // Note + Wage display + Save
          SummaryPanel(
            isRest: _isRest,
            isEdit: _isEdit,
            wage: _wage,
            noteCtrl: _noteCtrl,
            onSave: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    try {
    final record = WorkRecord(
      id: widget.existingRecord?.id,
      projectId: widget.projectId,
      date: widget.date,
      type: _workType,
      days: (_workType == WorkType.point && !_isRest) ? _days : 0,
      dailyRate: (_workType == WorkType.point && !_isRest) ? _p(_dailyRateCtrl.text) : 0,
      overtimeHours: (_workType == WorkType.point && !_isRest) ? _overtimeHours : 0,
      overtimeRate: (_workType == WorkType.point && !_isRest) ? _p(_overtimeRateCtrl.text) : 0,
      packageDays: (_workType == WorkType.packageDay && !_isRest) ? _p(_packageDaysCtrl.text) : 0,
      packageDayRate: (_workType == WorkType.packageDay && !_isRest) ? _p(_packageDayRateCtrl.text) : 0,
      quantity: (_workType == WorkType.packageQty && !_isRest) ? _p(_quantityCtrl.text) : 0,
      qtyUnit: _workType == WorkType.packageQty ? _qtyUnit : '平方',
      qtyUnitPrice: (_workType == WorkType.packageQty && !_isRest) ? _p(_qtyUnitPriceCtrl.text) : 0,
      totalWage: _wage,
      note: _noteCtrl.text.trim(),
      isRest: _isRest,
    );

    final provider = context.read<WorkProvider>();
    if (_isEdit) {
      await provider.updateRecord(record);
    } else {
      await provider.addRecord(record);
    }
    // Save rates for next time
    final prefs = await _ensurePrefs();
    if (_workType == WorkType.point) {
      prefs.setDouble('lastDailyRate', _p(_dailyRateCtrl.text));
      prefs.setDouble('lastOvertimeRate', _p(_overtimeRateCtrl.text));
    } else if (_workType == WorkType.packageDay) {
      prefs.setDouble('lastPkgDayRate', _p(_packageDayRateCtrl.text));
    } else {
      prefs.setDouble('lastPkgQtyRate', _p(_qtyUnitPriceCtrl.text));
      prefs.setString('lastQtyUnit', _qtyUnit);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEdit ? '已保存' : '已记录 ✓')),
    );
    Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: const Text('确定删除这条记录？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              context.read<WorkProvider>().deleteRecord(widget.existingRecord!.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSavedRates() async {
    try {
      final prefs = await _ensurePrefs();
      _dailyRateCtrl.text = _fmt(prefs.getDouble('lastDailyRate') ?? widget.project.defaultDailyRate);
      _overtimeRateCtrl.text = _fmt(prefs.getDouble('lastOvertimeRate') ?? widget.project.defaultOvertimeRate);
      _packageDayRateCtrl.text = _fmt(prefs.getDouble('lastPkgDayRate') ?? widget.project.defaultPackageDayRate);
      _qtyUnitPriceCtrl.text = _fmt(prefs.getDouble('lastPkgQtyRate') ?? widget.project.defaultPackageQtyRate);
      _qtyUnit = prefs.getString('lastQtyUnit') ?? (widget.project.defaultQtyUnit.isNotEmpty ? widget.project.defaultQtyUnit : '平方');
    } catch (e) {
      print('加载保存的费率失败: $e');
    }
  }

  String _fmt(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

/// 记工页顶部当月统计面板：出勤 / 加班 / 收入 / 未结工资
class _MonthlyStatsPanel extends StatelessWidget {
  final String projectId;
  final int year;
  final int month;

  const _MonthlyStatsPanel({
    required this.projectId,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<StatsProvider>(
      builder: (context, stats, _) {
        final s = stats.getMonthlyStats(projectId, year, month);
        final monthLabel = '$month月';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bar_chart, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('$monthLabel 统计',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatCell(
                      label: '出勤',
                      value: '${s.workDays % 1 == 0 ? s.workDays.toInt() : s.workDays}天',
                      color: Colors.green),
                  _StatCell(
                      label: '加班',
                      value: '${s.overtimeHours.toStringAsFixed(s.overtimeHours == s.overtimeHours.roundToDouble() ? 0 : 1)}小时',
                      color: Colors.blue),
                  _StatCell(
                      label: '收入',
                      value: PrivacyService.format(s.totalIncome, hide: PrivacyService().isHidden.value),
                      color: Colors.green.shade700),
                  _StatCell(
                      label: '未结',
                      value: PrivacyService.format(s.unpaidAmount, hide: PrivacyService().isHidden.value),
                      color: s.unpaidAmount > 0 ? Colors.red.shade700 : Colors.grey.shade600),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
