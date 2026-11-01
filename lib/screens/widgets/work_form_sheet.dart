import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/project.dart';
import '../../models/work_record.dart';
import '../../providers/work_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/borrow_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/photo_evidence_provider.dart';
import '../../core/utils/auto_sync_service.dart';
import 'work_type_selector.dart';
import 'time_input_panel.dart';
import 'summary_panel.dart';

/// Bottom sheet style work form for quick entry
class WorkFormSheet extends StatefulWidget {
  final String projectId;
  final Project project;
  final DateTime date;
  final WorkRecord? existingRecord;

  const WorkFormSheet({
    required this.projectId,
    required this.project,
    required this.date,
    this.existingRecord,
  });

  @override
  State<WorkFormSheet> createState() => _WorkFormSheetState();
}

class _WorkFormSheetState extends State<WorkFormSheet> {
  late WorkType _workType;
  SharedPreferences? _prefs;
  bool _isRest = false;
  double _days = 1.0;
  final _overtimeHoursCtrl = TextEditingController();
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
      _overtimeHoursCtrl.text = _fmt(r.overtimeHours);
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
    _overtimeHoursCtrl.dispose();
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
        return _days * _p(_dailyRateCtrl.text) + _p(_overtimeHoursCtrl.text) * _p(_overtimeRateCtrl.text);
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
                overtimeHoursCtrl: _overtimeHoursCtrl,
                dailyRateCtrl: _dailyRateCtrl,
                overtimeRateCtrl: _overtimeRateCtrl,
                onDaysChanged: (d) => setState(() => _days = d),
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
    final ctx = context;
    try {
    final record = WorkRecord(
      id: widget.existingRecord?.id,
      projectId: widget.projectId,
      // 日期归一到当天 0 点：work_records 有 UNIQUE(projectId, date)（S3），
      // 若带时分，同一天的记录会落在不同 date 值上，唯一约束形同虚设。
      date: DateTime(widget.date.year, widget.date.month, widget.date.day),
      type: _workType,
      days: (_workType == WorkType.point && !_isRest) ? _days : 0,
      dailyRate: (_workType == WorkType.point && !_isRest) ? _p(_dailyRateCtrl.text) : 0,
      overtimeHours: (_workType == WorkType.point && !_isRest) ? _p(_overtimeHoursCtrl.text) : 0,
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

    final provider = ctx.read<WorkProvider>();
    if (_isEdit) {
      await provider.updateRecord(record);
    } else {
      await provider.addRecord(record);
    }
    // Save rates for next time（S1：键带 projectId，避免 A 项目单价污染 B 项目）
    final prefs = await _ensurePrefs();
    if (!ctx.mounted) return;
    if (_workType == WorkType.point) {
      prefs.setDouble(_rateKey('daily'), _p(_dailyRateCtrl.text));
      prefs.setDouble(_rateKey('overtime'), _p(_overtimeRateCtrl.text));
    } else if (_workType == WorkType.packageDay) {
      prefs.setDouble(_rateKey('pkgDay'), _p(_packageDayRateCtrl.text));
    } else {
      prefs.setDouble(_rateKey('pkgQty'), _p(_qtyUnitPriceCtrl.text));
      prefs.setString(_rateKey('qtyUnit'), _qtyUnit);
    }
    final project = ctx.read<ProjectProvider>();
    final work = ctx.read<WorkProvider>();
    final borrow = ctx.read<BorrowProvider>();
    final settle = ctx.read<SettlementProvider>();
    final expense = ctx.read<ExpenseProvider>();
    final note = ctx.read<NoteProvider>();
    final photo = ctx.read<PhotoEvidenceProvider>();
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(_isEdit ? '已保存' : '已记录 ✓')),
    );
    Navigator.of(ctx).pop();
    // 记工成功 → 自动同步一次；完成后弹出真实结果（成功/失败），不留假「同步中」
    if (!_isEdit) {
      final synced = await AutoSyncService.syncAfterWorkRecord(
        projects: project,
        work: work,
        borrow: borrow,
        settlement: settle,
        expense: expense,
        note: note,
        photo: photo,
      );
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              synced.isEmpty
                  ? '自动同步失败，可稍后在工具页手动备份'
                  : '已自动同步备份 ✓',
            ),
          ),
        );
      }
    }
    } on StateError catch (e) {
      // provider 已把「同日唯一约束冲突」翻译成中文提示（StateError），直接展示
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  void _delete() {
    final outerCtx = context;
    showDialog(
      context: outerCtx,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: const Text('确定删除这条记录？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              try {
                await outerCtx.read<WorkProvider>().deleteRecord(
                    widget.existingRecord!.id);
              } catch (e) {
                if (outerCtx.mounted) {
                  ScaffoldMessenger.of(outerCtx).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
                return;
              }
              if (!outerCtx.mounted) return;
              Navigator.pop(outerCtx);
              Navigator.pop(outerCtx);
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
      if (!mounted) return;
      // S2：预填是异步的，完成时首帧已经画过了。不 setState 的话输入框里已有单价，
      // 预览金额却还是 0 —— 用户以为在记 0 元，实际落库的是预填的费率。
      setState(() {
        // 只在用户还没输入时填充，避免慢速 IO 回来把手输的值覆盖掉
        void fill(TextEditingController c, double fallback) {
          if (c.text.trim().isEmpty) c.text = _fmt(fallback);
        }

        fill(_dailyRateCtrl, prefs.getDouble(_rateKey('daily')) ?? widget.project.defaultDailyRate);
        fill(_overtimeRateCtrl, prefs.getDouble(_rateKey('overtime')) ?? widget.project.defaultOvertimeRate);
        fill(
          _packageDayRateCtrl,
          prefs.getDouble(_rateKey('pkgDay')) ?? widget.project.defaultPackageDayRate,
        );
        fill(
          _qtyUnitPriceCtrl,
          prefs.getDouble(_rateKey('pkgQty')) ?? widget.project.defaultPackageQtyRate,
        );
        final unit = prefs.getString(_rateKey('qtyUnit'));
        if (unit != null && unit.isNotEmpty && _qtyUnit == '平方') {
          _qtyUnit = unit;
        } else if (widget.project.defaultQtyUnit.isNotEmpty && _qtyUnit == '平方') {
          _qtyUnit = widget.project.defaultQtyUnit;
        }
      });
    } catch (e) {
      debugPrint('加载保存的费率失败: $e');
    }
  }

  /// S1：费率缓存键必须带 projectId 前缀。
  /// 旧实现是全局键（'lastDailyRate' 等），A 项目填过的单价会被 B 项目继承，
  /// 于是预览/落库都用错单价 —— 空项目本该用项目默认价，却拿到了别人项目的价。
  /// 旧的全局键不再读取：无法判断它属于哪个项目，读了就是错价。
  String _rateKey(String name) => 'lastRate_${widget.projectId}_$name';

  String _fmt(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

