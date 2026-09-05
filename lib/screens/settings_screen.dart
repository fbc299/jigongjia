import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../providers/project_provider.dart';
import '../providers/work_provider.dart';
import '../providers/borrow_provider.dart';
import '../providers/settlement_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/note_provider.dart';
import '../models/project.dart';
import '../models/work_record.dart';
import '../models/borrow_record.dart';
import '../models/settlement.dart';
import '../models/expense.dart';
import '../models/note.dart';
import '../core/utils/network_backup.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _buildSectionHeader(context, '项目管理'),
          const _ProjectManagementSection(),
          const Divider(height: 1),
          _buildSectionHeader(context, '数据管理'),
          const _DataManagementSection(),
          const Divider(height: 1),
          _buildSectionHeader(context, '腾讯云COS备份'),
          const _NetworkBackupSection(),
          const Divider(height: 1),
          _buildSectionHeader(context, '关于'),
          const _AboutSection(),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

// ===================== Project Management =====================

class _ProjectManagementSection extends StatelessWidget {
  const _ProjectManagementSection();

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final archived = projectProvider.archivedProjects;

    if (archived.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text('没有已归档的项目'),
      );
    }

    return Column(
      children: archived.map((project) {
        return ListTile(
          leading: const Icon(Icons.archive_outlined),
          title: Text(project.name),
          subtitle: Text(
            '创建于 ${DateFormat('yyyy-MM-dd').format(project.createdAt)}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.unarchive, size: 20),
                tooltip: '恢复',
                onPressed: () => _restoreProject(context, project),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.error),
                tooltip: '删除',
                onPressed: () => _deleteProject(context, project),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _restoreProject(BuildContext context, Project project) async {
    await context
        .read<ProjectProvider>()
        .updateProject(project.copyWith(isArchived: false));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复项目: ${project.name}')),
      );
    }
  }

  Future<void> _deleteProject(BuildContext context, Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定要删除"${project.name}"吗？\n相关的记工记录也会被删除，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<ProjectProvider>().deleteProject(project.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除项目: ${project.name}')),
      );
    }
  }
}

// ===================== Data Management =====================

class _DataManagementSection extends StatelessWidget {
  const _DataManagementSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('导出备份'),
          subtitle: const Text('将所有数据导出为 JSON 文件'),
          onTap: () => _exportBackup(context),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('导入备份'),
          subtitle: const Text('从 JSON 文件恢复数据'),
          onTap: () => _importBackup(context),
        ),
      ],
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final projectProvider = context.read<ProjectProvider>();
      final workProvider = context.read<WorkProvider>();
      final borrowProvider = context.read<BorrowProvider>();
      final settlementProvider = context.read<SettlementProvider>();
      final expenseProvider = context.read<ExpenseProvider>();
      final noteProvider = context.read<NoteProvider>();

      final backup = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'projects': projectProvider.projects.map((p) => p.toMap()).toList(),
        'workRecords': workProvider.records.map((r) => r.toMap()).toList(),
        'borrowRecords': borrowProvider.records.map((r) => r.toMap()).toList(),
        'settlements': settlementProvider.settlements.map((s) => s.toMap()).toList(),
        'expenses': expenseProvider.expenses.map((e) => e.toMap()).toList(),
        'notes': noteProvider.notes.map((n) => n.toMap()).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'jigongjia_backup_$timestamp.json';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '吉工家数据备份',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('备份已生成')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入备份'),
        content: const Text('导入将覆盖当前所有数据，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      final file = File(filePath);
      final jsonStr = await file.readAsString();
      final backup = jsonDecode(jsonStr) as Map<String, dynamic>;

      final version = backup['version'] as int? ?? 0;
      if (version < 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份文件格式不兼容')),
          );
        }
        return;
      }

      final projectProvider = context.read<ProjectProvider>();
      final workProvider = context.read<WorkProvider>();
      final borrowProvider = context.read<BorrowProvider>();
      final settlementProvider = context.read<SettlementProvider>();
      final expenseProvider = context.read<ExpenseProvider>();
      final noteProvider = context.read<NoteProvider>();

      // Delete existing data
      for (final p in List.from(projectProvider.projects)) {
        await projectProvider.deleteProject(p.id);
      }
      for (final r in List.from(workProvider.records)) {
        await workProvider.deleteRecord(r.id);
      }
      for (final r in List.from(borrowProvider.records)) {
        await borrowProvider.deleteRecord(r.id);
      }
      for (final s in List.from(settlementProvider.settlements)) {
        await settlementProvider.deleteSettlement(s.id);
      }
      for (final e in List.from(expenseProvider.expenses)) {
        await expenseProvider.deleteExpense(e.id);
      }
      for (final n in List.from(noteProvider.notes)) {
        await noteProvider.deleteNote(n.id);
      }

      // Import new data
      for (final m in (backup['projects'] as List? ?? [])) {
        await projectProvider.addProject(Project.fromMap(m as Map<String, dynamic>));
      }
      for (final m in (backup['workRecords'] as List? ?? [])) {
        await workProvider.addRecord(WorkRecord.fromMap(m as Map<String, dynamic>));
      }
      for (final m in (backup['borrowRecords'] as List? ?? [])) {
        await borrowProvider.addRecord(BorrowRecord.fromMap(m as Map<String, dynamic>));
      }
      for (final m in (backup['settlements'] as List? ?? [])) {
        await settlementProvider.addSettlement(Settlement.fromMap(m as Map<String, dynamic>));
      }
      for (final m in (backup['expenses'] as List? ?? [])) {
        await expenseProvider.addExpense(Expense.fromMap(m as Map<String, dynamic>));
      }
      for (final m in (backup['notes'] as List? ?? [])) {
        await noteProvider.addNote(Note.fromMap(m as Map<String, dynamic>));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据导入成功')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }
}

// ===================== Network Backup =====================

class _NetworkBackupSection extends StatefulWidget {
  const _NetworkBackupSection();

  @override
  State<_NetworkBackupSection> createState() => _NetworkBackupSectionState();
}

class _NetworkBackupSectionState extends State<_NetworkBackupSection> {
  final _service = NetworkBackupService();
  bool _loading = true;
  bool _connected = false;
  List<Map<String, dynamic>> _backups = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.load();
    final ok = await _service.ping();
    if (ok) {
      try { _backups = await _service.list(); } catch (_) {}
    }
    if (mounted) setState(() { _loading = false; _connected = ok; });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading && _connected) {
      _service.list().then((list) {
        if (mounted) setState(() => _backups = list);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );

    return Column(
      children: [
        ListTile(
          leading: Icon(
            _connected ? Icons.cloud_done : Icons.cloud_off,
            color: _connected ? Colors.green : Colors.red,
          ),
          title: Text(_connected ? '已连接备份服务器' : '未连接'),
          subtitle: Text(_service.serverUrl),
          trailing: TextButton(onPressed: _showSettings, child: const Text('设置')),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_upload),
          title: const Text('上传备份'),
          subtitle: Text(_connected ? '当前共 ${_backups.length} 个备份' : '请先连接服务器'),
          onTap: _connected ? _upload : null,
        ),
        if (_backups.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('云端备份', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ),
          ),
          ..._backups.map((b) => ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(b['name'] ?? '未知'),
            subtitle: Text(_formatSize(b['size'] ?? 0)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.download, size: 20), tooltip: '恢复',
                  onPressed: () => _restore(b['name'])),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), tooltip: '删除',
                  onPressed: () => _deleteObj(b['name'])),
              ],
            ),
          )),
        ],
      ],
    );
  }

  String _formatSize(dynamic bytes) {
    final b = bytes is int ? bytes : int.tryParse('$bytes') ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  void _showSettings() {
    final urlCtrl = TextEditingController(text: _service.serverUrl);
    final tokenCtrl = TextEditingController(text: _service.token);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备份服务器设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: '服务器地址')),
            const SizedBox(height: 12),
            TextField(controller: tokenCtrl, decoration: const InputDecoration(labelText: 'Token'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            await _service.save(urlCtrl.text.trim(), tokenCtrl.text.trim());
            Navigator.pop(ctx);
            setState(() => _loading = true);
            _init();
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  Future<void> _upload() async {
    setState(() => _loading = true);
    try {
      // Delete old backups first (keep only latest)
      for (final b in _backups) {
        try { await _service.delete(b['name']); } catch (_) {}
      }
      final jsonStr = _buildBackupJson();
      await _service.upload(jsonStr);
      _backups = await _service.list();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('备份上传成功 ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _restore(String? name) async {
    if (name == null) return;
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复备份'),
        content: Text('从服务器恢复 "$name"，覆盖当前数据？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('恢复')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      // Refresh list to check if file still exists
      _backups = await _service.list();
      final exists = _backups.any((b) => b['name'] == name);
      if (!exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该备份已被替换，请从最新备份恢复')),
          );
        }
        if (mounted) setState(() => _loading = false);
        return;
      }
      final jsonStr = await _service.download(name);
      await _importFromJson(jsonStr);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('恢复成功 ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('恢复失败: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteObj(String? name) async {
    if (name == null) return;
    try {
      await _service.delete(name);
      _backups = await _service.list();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  String _buildBackupJson() {
    final ctx = context;
    return json.encode({
      'version': 1, 'exportedAt': DateTime.now().toIso8601String(),
      'projects': ctx.read<ProjectProvider>().projects.map((p) => p.toMap()).toList(),
      'workRecords': ctx.read<WorkProvider>().records.map((r) => r.toMap()).toList(),
      'borrowRecords': ctx.read<BorrowProvider>().records.map((r) => r.toMap()).toList(),
      'settlements': ctx.read<SettlementProvider>().settlements.map((s) => s.toMap()).toList(),
      'expenses': ctx.read<ExpenseProvider>().expenses.map((e) => e.toMap()).toList(),
      'notes': ctx.read<NoteProvider>().notes.map((n) => n.toMap()).toList(),
    });
  }

  Future<void> _importFromJson(String jsonStr) async {
    final backup = json.decode(jsonStr) as Map<String, dynamic>;
    final ctx = context;
    final proj = ctx.read<ProjectProvider>();
    final work = ctx.read<WorkProvider>();
    final borrow = ctx.read<BorrowProvider>();
    final settle = ctx.read<SettlementProvider>();
    final expense = ctx.read<ExpenseProvider>();
    final note = ctx.read<NoteProvider>();

    for (final p in List.from(proj.projects)) await proj.deleteProject(p.id);
    for (final r in List.from(work.records)) await work.deleteRecord(r.id);
    for (final r in List.from(borrow.records)) await borrow.deleteRecord(r.id);
    for (final s in List.from(settle.settlements)) await settle.deleteSettlement(s.id);
    for (final e in List.from(expense.expenses)) await expense.deleteExpense(e.id);
    for (final n in List.from(note.notes)) await note.deleteNote(n.id);

    for (final m in (backup['projects'] as List? ?? [])) await proj.addProject(Project.fromMap(m));
    for (final m in (backup['workRecords'] as List? ?? [])) await work.addRecord(WorkRecord.fromMap(m));
    for (final m in (backup['borrowRecords'] as List? ?? [])) await borrow.addRecord(BorrowRecord.fromMap(m));
    for (final m in (backup['settlements'] as List? ?? [])) await settle.addSettlement(Settlement.fromMap(m));
    for (final m in (backup['expenses'] as List? ?? [])) await expense.addExpense(Expense.fromMap(m));
    for (final m in (backup['notes'] as List? ?? [])) await note.addNote(Note.fromMap(m));
  }
}

// ===================== About =====================

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('版本'),
          subtitle: const Text('v1.1.0'),
        ),
        ListTile(
          leading: Icon(Icons.code),
          title: Text('开发者'),
          subtitle: Text('吉工家团队'),
        ),
        ListTile(
          leading: Icon(Icons.description_outlined),
          title: Text('应用介绍'),
          subtitle: Text('吉工家 - 工人记工记账助手，轻松管理工地考勤、工资、借支和结算'),
        ),
      ],
    );
  }
}
