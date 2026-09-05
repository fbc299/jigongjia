import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:jigongjia/models/project.dart';
import 'package:jigongjia/models/work_record.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/project_provider.dart';
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
      label = record.days == 0.5 ? '半' : (record.overtimeHours > 0 ? '加' : '');
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
      if (record.overtimeHours > 0) desc += ' + 加班${record.overtimeHours.toInt()}h';
      desc += ' · ¥${record.dailyRate}/天';
      icon = Icons.engineering;
      color = theme.colorScheme.primary;
    } else if (record.type == WorkType.packageDay) {
      desc = '包工 ${record.packageDays}天 · ¥${record.packageDayRate}/天';
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
              record.isRest ? '—' : '¥${record.totalWage.toStringAsFixed(0)}',
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

  static const _dayOptions = [0.5, 1.0, 1.5, 2.0];
  static const _qtyUnits = ['平方', '米', '立方', '件'];

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
    final theme = Theme.of(context);
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
          // Mode selector
          SegmentedButton<WorkType>(
            segments: const [
              ButtonSegment(value: WorkType.point, label: Text('点工'), icon: Icon(Icons.access_time, size: 18)),
              ButtonSegment(value: WorkType.packageDay, label: Text('包工·天'), icon: Icon(Icons.calendar_view_day, size: 18)),
              ButtonSegment(value: WorkType.packageQty, label: Text('包工·量'), icon: Icon(Icons.straighten, size: 18)),
            ],
            selected: {_workType},
            onSelectionChanged: (s) => setState(() => _workType = s.first),
          ),
          const SizedBox(height: 16),

          // Rest toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_isRest ? '休息日' : '正常上工'),
            value: _isRest,
            onChanged: (v) => setState(() => _isRest = v),
            activeColor: Colors.orange,
          ),

          if (!_isRest) ...[
            const SizedBox(height: 8),
            if (_workType == WorkType.point) _buildPointFields(theme),
            if (_workType == WorkType.packageDay) _buildPkgDayFields(),
            if (_workType == WorkType.packageQty) _buildPkgQtyFields(),
          ],

          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '备注',
              hintText: '工种、内容、天气...',
              prefixIcon: Icon(Icons.notes),
            ),
          ),

          const SizedBox(height: 20),
          // Wage display
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_isRest ? '休息 · 无工资' : '工资合计',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                Text('¥${_wage.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: theme.colorScheme.primary)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_isEdit ? '保存修改' : '记录今天', style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPointFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('工天', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Row(
          children: _dayOptions.map((d) {
            final sel = _days == d;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _days = d),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? theme.colorScheme.primary : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      d == 1.0 ? '全天' : d == 0.5 ? '半天' : '$d天',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<double>(
          value: _overtimeHours,
          decoration: const InputDecoration(labelText: '加班', prefixIcon: Icon(Icons.timelapse)),
          items: const [
            DropdownMenuItem(value: 0.0, child: Text('无加班')),
            DropdownMenuItem(value: 0.5, child: Text('0.5小时')),
            DropdownMenuItem(value: 1.0, child: Text('1小时')),
            DropdownMenuItem(value: 2.0, child: Text('2小时')),
            DropdownMenuItem(value: 3.0, child: Text('3小时')),
            DropdownMenuItem(value: 4.0, child: Text('4小时')),
            DropdownMenuItem(value: 5.0, child: Text('5小时')),
            DropdownMenuItem(value: 6.0, child: Text('6小时')),
            DropdownMenuItem(value: 7.0, child: Text('7小时')),
            DropdownMenuItem(value: 8.0, child: Text('8小时')),
            DropdownMenuItem(value: 9.0, child: Text('9小时')),
            DropdownMenuItem(value: 10.0, child: Text('10小时')),
          ],
          onChanged: (v) => setState(() => _overtimeHours = v ?? 0),
        ),
        const SizedBox(height: 12),
        _numField(_dailyRateCtrl, '日薪', '元/天'),
        const SizedBox(height: 12),
        _numField(_overtimeRateCtrl, '加班薪', '元/时'),
      ],
    );
  }

  Widget _buildPkgDayFields() {
    return Column(
      children: [
        _numField(_packageDaysCtrl, '天数', '天'),
        const SizedBox(height: 12),
        _numField(_packageDayRateCtrl, '日薪', '元/天'),
      ],
    );
  }

  Widget _buildPkgQtyFields() {
    return Column(
      children: [
        _numField(_quantityCtrl, '工程量', _qtyUnit),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _qtyUnit,
          decoration: const InputDecoration(labelText: '单位', prefixIcon: Icon(Icons.category)),
          items: _qtyUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
          onChanged: (v) => setState(() => _qtyUnit = v ?? '平方'),
        ),
        const SizedBox(height: 12),
        _numField(_qtyUnitPriceCtrl, '单价', '元/$_qtyUnit'),
      ],
    );
  }

  Widget _numField(TextEditingController ctrl, String label, String suffix) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Future<void> _save() async {
    final record = WorkRecord(
      id: widget.existingRecord?.id,
      projectId: widget.projectId,
      date: widget.date,
      type: _workType,
      days: _workType == WorkType.point ? _days : 0,
      dailyRate: _workType == WorkType.point ? _p(_dailyRateCtrl.text) : 0,
      overtimeHours: _workType == WorkType.point ? _overtimeHours : 0,
      overtimeRate: _workType == WorkType.point ? _p(_overtimeRateCtrl.text) : 0,
      packageDays: _workType == WorkType.packageDay ? _p(_packageDaysCtrl.text) : 0,
      packageDayRate: _workType == WorkType.packageDay ? _p(_packageDayRateCtrl.text) : 0,
      quantity: _workType == WorkType.packageQty ? _p(_quantityCtrl.text) : 0,
      qtyUnit: _workType == WorkType.packageQty ? _qtyUnit : '平方',
      qtyUnitPrice: _workType == WorkType.packageQty ? _p(_qtyUnitPriceCtrl.text) : 0,
      totalWage: _wage,
      note: _noteCtrl.text.trim(),
      isRest: _isRest,
    );

    final provider = context.read<WorkProvider>();
    if (_isEdit) {
      provider.updateRecord(record);
    } else {
      provider.addRecord(record);
    }
    // Save rates for next time
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    _dailyRateCtrl.text = _fmt(prefs.getDouble('lastDailyRate') ?? widget.project.defaultDailyRate);
    _overtimeRateCtrl.text = _fmt(prefs.getDouble('lastOvertimeRate') ?? widget.project.defaultOvertimeRate);
    _packageDayRateCtrl.text = _fmt(prefs.getDouble('lastPkgDayRate') ?? widget.project.defaultPackageDayRate);
    _qtyUnitPriceCtrl.text = _fmt(prefs.getDouble('lastPkgQtyRate') ?? widget.project.defaultPackageQtyRate);
    _qtyUnit = prefs.getString('lastQtyUnit') ?? (widget.project.defaultQtyUnit.isNotEmpty ? widget.project.defaultQtyUnit : '平方');
  }

  String _fmt(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}
