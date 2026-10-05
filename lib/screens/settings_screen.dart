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
import '../providers/photo_evidence_provider.dart';
import '../models/project.dart';
import '../models/work_record.dart';
import '../models/borrow_record.dart';
import '../models/settlement.dart';
import '../models/expense.dart';
import '../models/note.dart';
import '../models/photo_evidence.dart';
import '../core/utils/network_backup.dart';
import '../core/account/account_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _buildSectionHeader(context, '账号管理'),
          const _AccountManagementSection(),
          const Divider(height: 1),
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

// ===================== Shared import helper =====================

Future<void> _importFromBackupJson(BuildContext context, String jsonStr) async {
  final backup = json.decode(jsonStr) as Map<String, dynamic>;
  final ctx = context;
  final proj = ctx.read<ProjectProvider>();
  final work = ctx.read<WorkProvider>();
  final borrow = ctx.read<BorrowProvider>();
  final settle = ctx.read<SettlementProvider>();
  final expense = ctx.read<ExpenseProvider>();
  final note = ctx.read<NoteProvider>();
  final photo = ctx.read<PhotoEvidenceProvider>();

  for (final p in List.from(proj.projects)) await proj.deleteProject(p.id);
  for (final r in List.from(work.records)) await work.deleteRecord(r.id);
  for (final r in List.from(borrow.records)) await borrow.deleteRecord(r.id);
  for (final s in List.from(settle.settlements)) await settle.deleteSettlement(s.id);
  for (final e in List.from(expense.expenses)) await expense.deleteExpense(e.id);
  for (final n in List.from(note.notes)) await note.deleteNote(n.id);
  for (final p in List.from(photo.photos)) await photo.deletePhoto(p.id);

  for (final m in (backup['projects'] as List? ?? [])) await proj.addProject(Project.fromMap(m));
  for (final m in (backup['workRecords'] as List? ?? [])) await work.addRecord(WorkRecord.fromMap(m));
  for (final m in (backup['borrowRecords'] as List? ?? [])) await borrow.addRecord(BorrowRecord.fromMap(m));
  for (final m in (backup['settlements'] as List? ?? [])) await settle.addSettlement(Settlement.fromMap(m));
  for (final m in (backup['expenses'] as List? ?? [])) await expense.addExpense(Expense.fromMap(m));
  for (final m in (backup['notes'] as List? ?? [])) await note.addNote(Note.fromMap(m));
  for (final m in (backup['photoEvidence'] as List? ?? [])) {
    final p = PhotoEvidence.fromMap(m);
    if (await File(p.filePath).exists()) await photo.addPhoto(p);
  }
}

// ===================== Account Management =====================

class _AccountManagementSection extends StatefulWidget {
  const _AccountManagementSection();

  @override
  State<_AccountManagementSection> createState() =>
      _AccountManagementSectionState();
}

class _AccountManagementSectionState extends State<_AccountManagementSection> {
  @override
  Widget build(BuildContext context) {
    final current = AccountService().currentUsername;
    if (current == null) {
      return const ListTile(
        leading: Icon(Icons.person_outline),
        title: Text('未登录'),
        subtitle: Text('在启动页可注册/登录'),
      );
    }
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle),
          title: Text(current),
          subtitle: const Text('数据独立存储于该账号'),
        ),
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: const Text('切换账号'),
          subtitle: const Text('在本机已注册的账号间切换'),
          onTap: () => _showSwitchSheet(current),
        ),
        ListTile(
          leading: Icon(Icons.logout, color: errorColor),
          title: Text('退出登录', style: TextStyle(color: errorColor)),
          subtitle: const Text('回到无账号共享数据模式'),
          onTap: _showLogoutConfirm,
        ),
      ],
    );
  }

  /// 账号切换后重载 7 个 provider 的内存缓存，使其指向当前账号的数据库。
  Future<void> _reloadAllData() async {
    await context.read<WorkProvider>().reloadAll();
    await context.read<BorrowProvider>().reloadAll();
    await context.read<SettlementProvider>().reloadAll();
    await context.read<ExpenseProvider>().reloadAll();
    await context.read<NoteProvider>().reloadAll();
    await context.read<PhotoEvidenceProvider>().reloadAll();
    await context.read<ProjectProvider>().reloadAll();
  }

  Future<void> _showSwitchSheet(String current) async {
    List<Account> accounts;
    try {
      accounts = await AccountService().load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      return;
    }
    if (!mounted) return;
    final others = accounts.where((a) => a.username != current).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无其他已注册账号')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '切换账号',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...others.map(
              (a) => ListTile(
                leading: const Icon(Icons.account_circle),
                title: Text(a.username),
                onTap: () => Navigator.pop(ctx, a.username),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    try {
      await AccountService().switchAccount(selected);
      await _reloadAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到 $selected')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _showLogoutConfirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后回到无账号共享数据模式，账号数据保留在设备与云端。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AccountService().logout();
      await _reloadAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已退出到共享数据模式')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
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
    try {
      await context
          .read<ProjectProvider>()
          .updateProject(project.copyWith(isArchived: false));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已恢复项目: \${project.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
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
      try {
        await context.read<ProjectProvider>().deleteProject(project.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除项目: \${project.name}')),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败: $e')),
          );
        }
      }
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
      final photoProvider = context.read<PhotoEvidenceProvider>();

      final backup = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'projects': projectProvider.projects.map((p) => p.toMap()).toList(),
        'workRecords': workProvider.records.map((r) => r.toMap()).toList(),
        'borrowRecords': borrowProvider.records.map((r) => r.toMap()).toList(),
        'settlements': settlementProvider.settlements.map((s) => s.toMap()).toList(),
        'expenses': expenseProvider.expenses.map((e) => e.toMap()).toList(),
        'notes': noteProvider.notes.map((n) => n.toMap()).toList(),
        'photoEvidence': photoProvider.photos.map((p) => p.toMap()).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      final projectNames = projectProvider.projects.map((p) => p.name).join('+');
      final fileName = '${projectNames}_$date.json';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '格格记工数据备份',
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

      await _importFromBackupJson(context, jsonStr);

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('云端备份', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                  tooltip: '刷新',
                  onPressed: _refreshList,
                ),
              ],
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
      final projects = context.read<ProjectProvider>().projects;
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      final projectNames = projects.map((p) => p.name).join('+');
      final backupName = '${projectNames}_$date.json';

      final jsonStr = _buildBackupJson();
      await _service.upload(jsonStr, backupName: backupName);
      // Upload succeeded — now delete old backups, keep only the latest
      final list = await _service.list();
      if (list.length > 1) {
        // Sort by name (timestamp-based) descending, skip the first (newest)
        list.sort((a, b) => (b['name'] ?? '').compareTo(a['name'] ?? ''));
        for (var i = 1; i < list.length; i++) {
          try { await _service.delete(list[i]['name']); } catch (_) {}
        }
      }
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

  Future<void> _refreshList() async {
    try {
      final list = await _service.list();
      if (mounted) setState(() => _backups = list);
    } catch (_) {}
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
      'photoEvidence': ctx.read<PhotoEvidenceProvider>().photos.map((p) => p.toMap()).toList(),
    });
  }

  Future<void> _importFromJson(String jsonStr) async {
    try {
      await _importFromBackupJson(context, jsonStr);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
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
          subtitle: Text('v1.1.8'),
        ),
        ListTile(
          leading: Icon(Icons.code),
          title: Text('开发者'),
          subtitle: Text('格格记工'),
        ),
        ListTile(
          leading: Icon(Icons.description_outlined),
          title: Text('应用介绍'),
          subtitle: Text('格格记工 - 工人记工记账助手，轻松管理工地考勤、工资、借支和结算'),
        ),
      ],
    );
  }
}
