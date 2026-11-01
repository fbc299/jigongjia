import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/privacy_service.dart';
import '../core/utils/work_record_csv.dart';
import '../core/utils/work_stats.dart';
import '../models/project.dart';
import '../models/work_record.dart';
import '../providers/project_provider.dart';
import '../providers/work_provider.dart';
import 'project_detail_screen.dart';

/// 记录查询页：跨项目搜索 + 日期区间筛选。
///
/// 记工页是「一天一格」的日历，翻历史只能一月月翻。这个页面解决
/// 「上个月在哪个工地干了几天、那笔 800 是啥时候的」这类回溯需求。
class RecordSearchScreen extends StatefulWidget {
  const RecordSearchScreen({super.key});

  @override
  State<RecordSearchScreen> createState() => _RecordSearchScreenState();
}

enum _RangePreset { all, week, month, last30, custom }

extension on _RangePreset {
  String get label => switch (this) {
        _RangePreset.all => '全部',
        _RangePreset.week => '本周',
        _RangePreset.month => '本月',
        _RangePreset.last30 => '近30天',
        _RangePreset.custom => '自定义',
      };
}

class _RecordSearchScreenState extends State<RecordSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  _RangePreset _preset = _RangePreset.all;
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTimeRange? _effectiveRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case _RangePreset.all:
        return null;
      case _RangePreset.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: monday, end: today);
      case _RangePreset.month:
        return DateTimeRange(start: DateTime(today.year, today.month), end: today);
      case _RangePreset.last30:
        return DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today);
      case _RangePreset.custom:
        return _customRange;
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month),
            end: DateTime(now.year, now.month, now.day),
          ),
      helpText: '选择日期区间',
      saveText: '确定',
    );
    if (picked == null) return;
    setState(() {
      _preset = _RangePreset.custom;
      _customRange = picked;
    });
  }

  bool _matches(WorkRecord r, String projectName, DateTimeRange? range) {
    final day = DateTime(r.date.year, r.date.month, r.date.day);
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      if (day.isBefore(start) || day.isAfter(end)) return false;
    }
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final dateText = DateFormat('yyyy-MM-dd').format(r.date);
    final monthText = DateFormat('yyyy-MM').format(r.date);
    return projectName.toLowerCase().contains(q) ||
        r.note.toLowerCase().contains(q) ||
        dateText.contains(q) ||
        monthText.contains(q) ||
        r.totalWage.toStringAsFixed(0).contains(q) ||
        (r.qtyUnit.isNotEmpty && r.qtyUnit.toLowerCase().contains(q));
  }

  String _typeText(WorkRecord r) {
    if (r.isRest) return '休息';
    switch (r.type) {
      case WorkType.point:
        return '点工';
      case WorkType.packageDay:
        return '包工(天)';
      case WorkType.packageQty:
        return '包工(量)';
    }
  }

  List<WorkRecord> _filteredRecords(List<Project> projects, Map<String, String> nameById) {
    final range = _effectiveRange();
    final list = context
        .read<WorkProvider>()
        .records
        .where((r) => _matches(r, nameById[r.projectId] ?? '', range))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> _exportCsv(List<WorkRecord> records, Map<String, String> nameById) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前筛选没有记录，无法导出')),
      );
      return;
    }
    try {
      final path = await WorkRecordCsv.writeToTempFile(
        records: records,
        projectNames: nameById,
      );
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        subject: '格格记工 记录导出',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // watch 让记录变更时自动重算（实际读取在 _filteredRecords 里）
    context.watch<WorkProvider>();
    final projects = context.watch<ProjectProvider>().projects;
    final nameById = <String, String>{for (final p in projects) p.id: p.name};
    final hidden = PrivacyService().isHidden.value;

    final results = _filteredRecords(projects, nameById);

    final totalDays = sumWorkDays(results.where((r) => !r.isRest).toList());
    final totalWage = results.fold<double>(0, (s, r) => s + r.totalWage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('查记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: '导出当前结果为 CSV',
            onPressed: () => _exportCsv(results, nameById),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: '搜项目名、备注、日期或金额',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: '清空',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final p in _RangePreset.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        p == _RangePreset.custom && _customRange != null
                            ? '${DateFormat('MM-dd').format(_customRange!.start)}~${DateFormat('MM-dd').format(_customRange!.end)}'
                            : p.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _preset == p,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        if (p == _RangePreset.custom) {
                          _pickCustomRange();
                        } else {
                          setState(() => _preset = p);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Text(
                  '共 ${results.length} 条',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  '${formatDays(totalDays)} 工天 · ${PrivacyService.format(totalWage, hide: hidden)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.okGreen,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(
                          _query.isEmpty && _preset == _RangePreset.all
                              ? '还没有记工记录'
                              : '没有符合条件的记录',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final r = results[index];
                      final projectName = nameById[r.projectId] ?? '未知项目';
                      final subtitleParts = <String>[
                        _typeText(r),
                        if (!r.isRest && r.type == WorkType.point)
                          '${formatDays(r.days)} 天',
                        if (r.overtimeHours > 0) '加班 ${r.overtimeHours.toStringAsFixed(1)}h',
                        if (r.note.isNotEmpty) r.note,
                      ];
                      return ListTile(
                        dense: true,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                projectName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              PrivacyService.format(r.totalWage, hide: hidden),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: r.isRest ? Colors.grey : AppTheme.okGreen,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd EEE').format(r.date)} · ${subtitleParts.join(' · ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProjectDetailScreen(projectId: r.projectId),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
