import 'package:flutter/material.dart';

import 'widgets/work_form_sheet.dart';

import 'record_search_screen.dart';
import 'package:jigongjia/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:jigongjia/models/project.dart';
import 'package:jigongjia/models/work_record.dart';
import 'package:jigongjia/core/utils/privacy_service.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/stats_provider.dart';

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

  bool _isFuture(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 归一化到天再比较: DateTime.now() 带时分, 直接比较会把「今天」误判为未到
    final dDay = DateTime(d.year, d.month, d.day);
    return dDay.isAfter(today);
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
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '查记录',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecordSearchScreen()),
            ),
          ),
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

          return ValueListenableBuilder<bool>(
            valueListenable: PrivacyService().isHidden,
            builder: (context, hidden, _) => Column(
            children: [
              // Month navigation
              _buildMonthNav(theme),
              const SizedBox(height: 4),
              // Monthly statistics panel
              _buildMonthStats(theme, hidden),
              const SizedBox(height: 8),
              // Weekday headers
              _buildWeekdayHeaders(theme),
              const SizedBox(height: 4),
              // Calendar grid
              Expanded(
                child: _buildCalendarGrid(theme, recordMap),
              ),
              // Selected day detail
              _buildSelectedDayPanel(theme, recordMap, hidden),
            ],
            ),
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

  /// 当月统计条：出勤/加班/当月工资/未结工资
  Widget _buildMonthStats(ThemeData theme, bool hidden) {
    return Consumer<StatsProvider>(
      builder: (context, statsProv, _) {
        final s = statsProv.getMonthlyStats(
          widget.projectId,
          _currentMonth.year,
          _currentMonth.month,
        );
        final ovt = s.overtimeHours;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _statCell('出勤', '${s.workDays}天', theme),
              _statCell('加班', ovt > 0 ? '${ovt.toStringAsFixed(ovt == ovt.roundToDouble() ? 0 : 1)}h' : '0', theme),
              _statCell('当月工资', PrivacyService.format(s.totalIncome, hide: hidden), theme),
              _statCell('未结工资', PrivacyService.format(s.unpaidAmount, hide: hidden), theme),
            ],
          ),
        );
      },
    );
  }

  Widget _statCell(String label, String value, ThemeData theme) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
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
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : (record != null ? Colors.white : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? theme.colorScheme.primary
                      : (isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.4)
                          : Colors.grey.withValues(alpha: 0.08)),
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
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('休', style: TextStyle(fontSize: 9, color: Colors.orange)),
      );
    }

    Color color;
    String attText;
    double ovt = record.overtimeHours;
    if (record.type == WorkType.point) {
      color = theme.colorScheme.primary;
      attText = '${record.days.toStringAsFixed(record.days == record.days.roundToDouble() ? 0 : 1)}天';
    } else if (record.type == WorkType.packageDay) {
      color = AppTheme.warnAmber;
      attText = record.packageDays > 0
          ? '${record.packageDays.toStringAsFixed(record.packageDays == record.packageDays.roundToDouble() ? 0 : 1)}天·包'
          : '包';
    } else {
      color = AppTheme.clay;
      attText = record.quantity > 0 ? '${record.quantity}·量' : '量';
    }
    final ovtText = ovt > 0
        ? ovt.toStringAsFixed(ovt == ovt.roundToDouble() ? 0 : 1)
        : '';

    return Column(
      children: [
        Text(attText, style: TextStyle(fontSize: 9, color: color)),
        if (ovtText.isNotEmpty)
          Text('${ovtText}h', style: TextStyle(fontSize: 9, color: AppTheme.warnAmber)),
      ],
    );
  }

  Widget _buildSelectedDayPanel(ThemeData theme, Map<String, WorkRecord> recordMap, bool hidden) {
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: record == null
          ? _buildEmptyDay(theme, weekday)
          : _buildRecordDetail(record, theme, weekday, hidden),
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

  Widget _buildRecordDetail(WorkRecord record, ThemeData theme, String weekday, bool hidden) {
    String desc;
    IconData icon;
    Color color;

    if (record.isRest) {
      desc = '休息日';
      icon = Icons.hotel;
      color = Colors.orange;
    } else if (record.type == WorkType.point) {
      desc = '${record.days}天';
      if (record.overtimeHours > 0) desc += ' + 加班${record.overtimeHours.toStringAsFixed(record.overtimeHours == record.overtimeHours.roundToDouble() ? 0 : 1)}h';
      desc += ' · ${PrivacyService.format(record.dailyRate, hide: hidden)}/天';
      icon = Icons.engineering;
      color = theme.colorScheme.primary;
    } else if (record.type == WorkType.packageDay) {
      desc = '包工 ${record.packageDays}天 · ${PrivacyService.format(record.packageDayRate, hide: hidden)}/天';
      icon = Icons.calendar_view_day;
      color = AppTheme.warnAmber;
    } else {
      desc = '包工 ${record.quantity}${record.qtyUnit} · ¥${record.qtyUnitPrice}/${record.qtyUnit}';
      icon = Icons.straighten;
      color = AppTheme.clay;
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
              record.isRest ? '—' : PrivacyService.format(record.totalWage, hide: hidden),
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

  /// 防止连点 FAB/「记工」按钮一次弹出多个表单（同日唯一约束下第二个保存必然冲突）
  bool _formOpening = false;

  Future<void> _openWorkForm(DateTime date, {WorkRecord? existingRecord}) async {
    // 未到日期禁止编辑
    if (_isFuture(date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未到日期，暂不能记工')),
      );
      return;
    }
    // 连点保护：避免同一秒弹出两个表单，各存一条同日记录
    if (_formOpening) return;

    var target = existingRecord;
    // S3: 新增前用 getRecordsByDate 判重（此前全项目 0 调用）。同一天只允许一条记工，
    // 已存在则直接转为编辑，否则再叠一条会让工资翻倍，而日历只显示一条、界面看不出错。
    if (target == null) {
      final sameDay = context
          .read<WorkProvider>()
          .getRecordsByDate(widget.projectId, date);
      if (sameDay.isNotEmpty) {
        target = sameDay.first;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当天已有记工记录，已转为编辑该记录')),
        );
      }
    }

    _formOpening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkFormSheet(
            projectId: widget.projectId,
            project: widget.project,
            date: date,
            existingRecord: target,
          ),
        ),
      );
    } finally {
      _formOpening = false;
      // Force rebuild to refresh calendar markers
      if (mounted) setState(() {});
    }
  }
}
