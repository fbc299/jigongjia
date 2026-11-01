import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jigongjia/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../providers/project_provider.dart';
import '../../providers/work_provider.dart';
import '../../providers/borrow_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/photo_evidence_provider.dart';
import '../../models/project.dart';
import '../../models/work_record.dart';
import '../../models/borrow_record.dart';
import '../../models/settlement.dart';
import '../../models/expense.dart';
import '../../models/note.dart';
import '../../models/photo_evidence.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/network_backup.dart';
import '../../core/utils/photo_files.dart';

// ===================== 备份导入（S4：先全量校验 → 自动快照 → 单事务替换 → 失败整体回滚） =====================

/// 导入结果统计：让用户看到真实恢复情况，而不是一律「成功」
class _ImportOutcome {
  const _ImportOutcome({
    required this.projects,
    required this.workRecords,
    required this.borrowRecords,
    required this.settlements,
    required this.expenses,
    required this.notes,
    required this.photos,
    required this.mergedRecords,
    required this.missingPhotoFiles,
    required this.snapshotPath,
  });

  final int projects;
  final int workRecords;
  final int borrowRecords;
  final int settlements;
  final int expenses;
  final int notes;
  final int photos;

  /// 备份里同日重复、导入时被合并掉的记工条数（db v2 有 UNIQUE(projectId, date)）
  final int mergedRecords;

  /// 备份里有记录但本机找不到文件的照片数（备份只存路径，不含图片本体）
  final int missingPhotoFiles;

  /// 导入前自动快照的落盘路径
  final String snapshotPath;

  String describe() {
    final buf = StringBuffer(
      '项目 $projects / 记工 $workRecords / 借支 $borrowRecords / 结算 $settlements / '
      '开支 $expenses / 笔记 $notes / 照片 $photos',
    );
    if (mergedRecords > 0) {
      buf.write('\n· 备份中 $mergedRecords 条同日记工已合并（一天只允许一条）');
    }
    if (missingPhotoFiles > 0) {
      buf.write('\n· $missingPhotoFiles 张照片文件在本机不存在（备份不含图片本体）');
    }
    buf.write('\n· 导入前快照：$snapshotPath');
    return buf.toString();
  }
}

/// 校验通过、可直接落库的备份内容
class _ParsedBackup {
  const _ParsedBackup({
    required this.projects,
    required this.workRecords,
    required this.borrowRecords,
    required this.settlements,
    required this.expenses,
    required this.notes,
    required this.photos,
    required this.mergedRecords,
    required this.missingPhotoFiles,
  });

  final List<Project> projects;
  final List<WorkRecord> workRecords;
  final List<BorrowRecord> borrowRecords;
  final List<Settlement> settlements;
  final List<Expense> expenses;
  final List<Note> notes;
  final List<PhotoEvidence> photos;
  final int mergedRecords;
  final int missingPhotoFiles;
}

/// 同日合并结果：合并后的记录 + 「被合并 id → 主记录 id」映射（照片改挂用）+ 合并条数
class _MergedRecords {
  const _MergedRecords(this.records, this.alias, this.mergedCount);
  final List<WorkRecord> records;
  final Map<String, String> alias;
  final int mergedCount;
}

/// 把「同一项目同一天」的多条记工合并为一条。
/// 口径与 database_helper 的 v2 迁移一致：保留最早一条为主记录（优先非休息日），
/// 其余记录的 days/overtimeHours/packageDays/quantity/totalWage 累加进去，备注去重拼接。
_MergedRecords _mergeSameDayWorkRecords(List<WorkRecord> input) {
  final groups = <String, List<WorkRecord>>{};
  for (final r in input) {
    final day = DateTime(r.date.year, r.date.month, r.date.day);
    groups.putIfAbsent('${r.projectId}|${day.millisecondsSinceEpoch}', () => []).add(r);
  }

  final records = <WorkRecord>[];
  final alias = <String, String>{};
  var mergedCount = 0;

  for (final g in groups.values) {
    final day = DateTime(g.first.date.year, g.first.date.month, g.first.date.day);
    if (g.length == 1) {
      records.add(g.first.copyWith(date: day));
      continue;
    }
    g.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final base = g.firstWhere((r) => !r.isRest, orElse: () => g.first);
    final others = g.where((r) => r.id != base.id).toList();
    final noteSet = <String>{
      if (base.note.isNotEmpty) base.note,
      for (final r in others)
        if (r.note.isNotEmpty) r.note,
    };
    records.add(
      base.copyWith(
        date: day,
        days: base.days + others.fold(0.0, (a, r) => a + r.days),
        overtimeHours: base.overtimeHours + others.fold(0.0, (a, r) => a + r.overtimeHours),
        packageDays: base.packageDays + others.fold(0.0, (a, r) => a + r.packageDays),
        quantity: base.quantity + others.fold(0.0, (a, r) => a + r.quantity),
        totalWage: base.totalWage + others.fold(0.0, (a, r) => a + r.totalWage),
        note: noteSet.join(' / '),
      ),
    );
    for (final r in others) {
      alias[r.id] = base.id;
      mergedCount++;
    }
  }
  return _MergedRecords(records, alias, mergedCount);
}

/// ① 全量解析 + 校验（解析所有记录 + 检查引用完整性）。
/// 任何一条失败都抛 FormatException —— 此时数据库一个字节都没动过。
Future<_ParsedBackup> _parseAndValidateBackup(String jsonStr) async {
  final dynamic root = jsonDecode(jsonStr);
  if (root is! Map) {
    throw const FormatException('备份文件根节点不是 JSON 对象');
  }
  final map = Map<String, dynamic>.from(root);
  final version = (map['version'] as num?)?.toInt() ?? 0;
  if (version < 1) {
    throw FormatException('备份文件版本不兼容（version=$version）');
  }
  if (version > 1) {
    throw FormatException('备份由更新版本的 App 生成（version=$version），请先升级 App 再恢复');
  }

  List<Map<String, dynamic>> rowsOf(String key) {
    final raw = map[key];
    if (raw == null) return const [];
    if (raw is! List) {
      throw FormatException('备份字段 $key 应为数组，实际为 ${raw.runtimeType}');
    }
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e is! Map) {
        throw FormatException('备份字段 $key 第 ${i + 1} 条不是对象');
      }
      out.add(Map<String, dynamic>.from(e));
    }
    return out;
  }

  List<T> parseEach<T>(String key, T Function(Map<String, dynamic>) fromMap) {
    final rows = rowsOf(key);
    final out = <T>[];
    for (var i = 0; i < rows.length; i++) {
      try {
        out.add(fromMap(rows[i]));
      } catch (e) {
        // 逐条定位，替代原来「第 500 条炸掉 → 整批失败且库已清空」
        throw FormatException('备份字段 $key 第 ${i + 1} 条解析失败：$e');
      }
    }
    return out;
  }

  final projects = parseEach('projects', Project.fromMap);
  final workRecordsRaw = parseEach('workRecords', WorkRecord.fromMap);
  final borrowRecords = parseEach('borrowRecords', BorrowRecord.fromMap);
  final settlements = parseEach('settlements', Settlement.fromMap);
  final expenses = parseEach('expenses', Expense.fromMap);
  final notes = parseEach('notes', Note.fromMap);
  final photosRaw = parseEach('photoEvidence', PhotoEvidence.fromMap);

  final projectIds = projects.map((p) => p.id).toSet();
  void requireProject(String table, int index, String projectId) {
    if (!projectIds.contains(projectId)) {
      throw FormatException(
        '备份引用完整性错误：$table 第 ${index + 1} 条引用了不存在的项目（projectId=$projectId）',
      );
    }
  }

  for (var i = 0; i < workRecordsRaw.length; i++) {
    requireProject('workRecords', i, workRecordsRaw[i].projectId);
  }
  for (var i = 0; i < borrowRecords.length; i++) {
    requireProject('borrowRecords', i, borrowRecords[i].projectId);
  }
  for (var i = 0; i < settlements.length; i++) {
    requireProject('settlements', i, settlements[i].projectId);
  }
  for (var i = 0; i < notes.length; i++) {
    final pid = notes[i].projectId;
    if (pid != null) requireProject('notes', i, pid);
  }

  // 同日多条：db v2 的 UNIQUE(projectId, date) 会让整批插入撞约束，
  // 老版本导出的 v1 备份里确实可能存在，合并后再落库（金额累加不丢）。
  final merged = _mergeSameDayWorkRecords(workRecordsRaw);
  final workRecordIds = merged.records.map((r) => r.id).toSet();

  final photos = <PhotoEvidence>[];
  var missingPhotoFiles = 0;
  for (var i = 0; i < photosRaw.length; i++) {
    final p = photosRaw[i];
    requireProject('photoEvidence', i, p.projectId);
    final aliasId = p.workRecordId == null ? null : merged.alias[p.workRecordId];
    final fixed = aliasId == null ? p : p.copyWith(workRecordId: aliasId);
    if (fixed.workRecordId != null && !workRecordIds.contains(fixed.workRecordId)) {
      throw FormatException(
        '备份引用完整性错误：photoEvidence 第 ${i + 1} 条引用了不存在的记工记录（id=${fixed.workRecordId}）',
      );
    }
    // 备份里存的是文件名，先还原成当前设备上的绝对路径再看文件在不在
    final resolvedPath = await resolvePhotoPath(fixed.filePath);
    if (await File(resolvedPath).exists()) {
      var resolvedThumb = '';
      if (fixed.thumbPath.isNotEmpty) {
        final t = await resolvePhotoPath(fixed.thumbPath);
        if (await File(t).exists()) resolvedThumb = t;
      }
      photos.add(fixed.copyWith(filePath: resolvedPath, thumbPath: resolvedThumb));
    } else {
      missingPhotoFiles++; // 备份只存路径不存图片本体，换机必然失效 → 计数后告知用户
    }
  }

  return _ParsedBackup(
    projects: projects,
    workRecords: merged.records,
    borrowRecords: borrowRecords,
    settlements: settlements,
    expenses: expenses,
    notes: notes,
    photos: photos,
    mergedRecords: merged.mergedCount,
    missingPhotoFiles: missingPhotoFiles,
  );
}

/// ② 导入前自动快照：把当前库全量导出为 pre_import_<时间戳>.json（最多保留 5 份）
Future<String> _writePreImportSnapshot() async {
  final db = await DatabaseHelper.instance.database;
  final snapshot = <String, dynamic>{
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'note': '导入备份前自动快照',
    'projects': await db.query(AppConstants.tableProjects),
    'workRecords': await db.query(AppConstants.tableWorkRecords),
    'borrowRecords': await db.query(AppConstants.tableBorrowRecords),
    'settlements': await db.query(AppConstants.tableSettlements),
    'expenses': await db.query(AppConstants.tableExpenses),
    'notes': await db.query(AppConstants.tableNotes),
    'photoEvidence': await db.query(AppConstants.tablePhotoEvidence),
  };

  final dir = await getApplicationDocumentsDirectory();
  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final file = File('${dir.path}/pre_import_$ts.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot));

  // 只保留最近 5 份，避免快照无限堆积
  try {
    final olds = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('pre_import_'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // 文件名带时间戳，字典序即时间序
    for (final f in olds.skip(5)) {
      f.deleteSync();
    }
  } catch (_) {
    // 清理失败不影响导入
  }
  return file.path;
}

/// ③ 单事务替换：先删旧（子表 → 父表），再按父表 → 子表插入。
/// 任一语句抛错 → sqflite 回滚整个事务 → 数据库仍是导入前的样子。
Future<void> _replaceAllData(_ParsedBackup parsed) async {
  await DatabaseHelper.instance.txn((txn) async {
    for (final table in const [
      AppConstants.tablePhotoEvidence,
      AppConstants.tableWorkRecords,
      AppConstants.tableSettlements,
      AppConstants.tableBorrowRecords,
      AppConstants.tableNotes,
      AppConstants.tableExpenses,
      AppConstants.tableProjects,
    ]) {
      await txn.delete(table);
    }

    Future<void> insertAll(String table, List<Map<String, dynamic>> maps) async {
      for (var i = 0; i < maps.length; i++) {
        try {
          await txn.insert(table, maps[i]);
        } catch (e) {
          // 带上表名/行号/记录 id，而不是只给一句 DatabaseException
          throw StateError('导入 $table 第 ${i + 1} 条失败（id=${maps[i]['id']}）：$e');
        }
      }
    }

    await insertAll(AppConstants.tableProjects, parsed.projects.map((p) => p.toMap()).toList());
    await insertAll(AppConstants.tableWorkRecords, parsed.workRecords.map((r) => r.toMap()).toList());
    await insertAll(AppConstants.tableBorrowRecords, parsed.borrowRecords.map((r) => r.toMap()).toList());
    await insertAll(AppConstants.tableSettlements, parsed.settlements.map((s) => s.toMap()).toList());
    await insertAll(AppConstants.tableExpenses, parsed.expenses.map((e) => e.toMap()).toList());
    await insertAll(AppConstants.tableNotes, parsed.notes.map((n) => n.toMap()).toList());
    await insertAll(AppConstants.tablePhotoEvidence, parsed.photos.map((p) => p.toMap()).toList());
  });
}

/// 导入备份总入口：校验 → 快照 → 单事务替换 → 刷新内存缓存。
/// 失败一律抛异常（数据库已回滚），由调用方提示「未改动任何数据」。
Future<_ImportOutcome> _importFromBackupJson(BuildContext context, String jsonStr) async {
  final ctx = context;
  final proj = ctx.read<ProjectProvider>();
  final work = ctx.read<WorkProvider>();
  final borrow = ctx.read<BorrowProvider>();
  final settle = ctx.read<SettlementProvider>();
  final expense = ctx.read<ExpenseProvider>();
  final note = ctx.read<NoteProvider>();
  final photo = ctx.read<PhotoEvidenceProvider>();

  // ① 全量校验：解析失败 / 引用不完整在此抛出，数据库完全未被触碰
  final parsed = await _parseAndValidateBackup(jsonStr);

  // ② 导入前自动快照（写不出来就不导入，保证永远有退路）
  String snapshotPath;
  try {
    snapshotPath = await _writePreImportSnapshot();
  } catch (e) {
    throw StateError('导入前快照写入失败，已取消导入（原数据未改动）：$e');
  }

  // ③ 单事务删旧插新，失败整体回滚
  await _replaceAllData(parsed);

  // ④ 事务已提交：重载各 provider 的内存缓存（导入不再经过去重的逐条 delete/add）
  await proj.loadProjects();
  await work.loadRecords();
  await borrow.loadRecords();
  await settle.loadSettlements();
  await expense.loadExpenses();
  await note.loadNotes();
  await photo.loadPhotos();

  return _ImportOutcome(
    projects: parsed.projects.length,
    workRecords: parsed.workRecords.length,
    borrowRecords: parsed.borrowRecords.length,
    settlements: parsed.settlements.length,
    expenses: parsed.expenses.length,
    notes: parsed.notes.length,
    photos: parsed.photos.length,
    mergedRecords: parsed.mergedRecords,
    missingPhotoFiles: parsed.missingPhotoFiles,
    snapshotPath: snapshotPath,
  );
}

// ===================== Project Management =====================

class ProjectManagementSection extends StatelessWidget {
  const ProjectManagementSection();

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
    final ctx = context;
    final projectProvider = ctx.read<ProjectProvider>();
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dlg) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定要删除"${project.name}"吗？\n相关的记工记录也会被删除，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlg, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await projectProvider.deleteProject(project.id);
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('已删除项目: ${project.name}')),
        );
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('操作失败: $e')),
          );
        }
      }
    }
  }
}

// ===================== Data Management =====================

class DataManagementSection extends StatelessWidget {
  const DataManagementSection();

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
        // 只传文件名，不带设备绝对路径
        'photoEvidence': photoProvider.photos.map((p) => {
              ...p.toMap(),
              'filePath': backupPhotoPath(p.filePath),
              'thumbPath': p.thumbPath.isEmpty ? '' : backupPhotoPath(p.thumbPath),
            }).toList(),
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

      // 分享出去后本机这份明文备份没有留存价值，2 分钟后删掉（给分享目标读取留时间）
      Timer(const Duration(minutes: 2), () async {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      });

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

      // 版本/结构校验统一在 _importFromBackupJson 里做（格式不合法时数据库不会被触碰）
      if (!context.mounted) return;
      final outcome = await _importFromBackupJson(context, jsonStr);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据导入成功\n${outcome.describe()}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败，未改动任何数据：$e'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }
}

// ===================== Network Backup =====================

class NetworkBackupSection extends StatefulWidget {
  const NetworkBackupSection();

  @override
  State<NetworkBackupSection> createState() => _NetworkBackupSectionState();
}

class _NetworkBackupSectionState extends State<NetworkBackupSection> {
  final _service = NetworkBackupService();
  bool _loading = true;
  bool _connected = false;
  List<Map<String, dynamic>> _backups = [];
  Map<String, dynamic>? _cosLink;
  bool _cosBusy = false;

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
      // 预签名链接改为按需生成：进页面不再自动签名，避免长期免鉴权链接躺在屏幕上
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
            color: _connected ? AppTheme.okGreen : Colors.red,
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
        // 腾讯云存储桶预签名下载链接卡片（可复制 + 临期自动刷新）
        _buildCosLinkCard(),
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

  // ─── 腾讯云 COS 预签名下载链接 ───
  /// 只在用户明确点击时签名，有效期 5 分钟（默认曾是 1 小时且自动刷新）。
  /// 这个链接**不需要 token** 就能下载全量明文备份，所以不能自己冒出来。
  Future<void> _fetchCosLink() async {
    if (!_connected || _cosBusy) return;
    setState(() => _cosBusy = true);
    try {
      final r = await _service.getCosLink(expire: 300);
      if (mounted) setState(() => _cosLink = r);
    } catch (_) {
      // 生成失败保持原状
    } finally {
      if (mounted) setState(() => _cosBusy = false);
    }
  }

  void _clearCosLink() {
    if (mounted) setState(() => _cosLink = null);
  }

  Future<void> _copyCosLink() async {
    final url = _cosLink?['url'];
    if (url is! String || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('存储桶下载链接已复制')),
      );
    }
  }

  Widget _buildCosLinkCard() {
    final l = _cosLink;
    final ok = l?['ok'] == true;
    final url = ok ? (l!['url'] as String? ?? '') : '';
    final name = ok ? (l!['name'] as String? ?? '') : '';
    final expiresAt = ok ? (l!['expires_at'] as num?)?.toInt() : null;
    final remainSec =
        expiresAt == null ? 0 : expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remainText = remainSec <= 0
        ? '已过期，点击刷新'
        : '剩余 ${remainSec ~/ 3600}h ${remainSec % 3600 ~/ 60}m ${remainSec % 60}s';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.link, size: 18,
                    color: ok ? AppTheme.brick : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok ? '腾讯云存储桶下载：$name' : '腾讯云存储桶下载',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  ok ? remainText : (_cosBusy ? '生成中…' : '未生成'),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                  tooltip: '刷新链接',
                  onPressed: _connected ? _fetchCosLink : null,
                ),
              ],
            ),
          ),
          if (url.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _connected ? _fetchCosLink : null,
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('生成下载链接（5 分钟有效）'),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 10),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () => _copyCosLink(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          url,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.copy_all, size: 18),
                    tooltip: '复制链接',
                    onPressed: _copyCosLink,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '清除链接',
                    onPressed: _clearCosLink,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  void _showSettings() {
    final outerCtx = context;
    final urlCtrl = TextEditingController(text: _service.serverUrl);
    final tokenCtrl = TextEditingController(text: _service.token);
    showDialog(
      context: outerCtx,
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
            final url = urlCtrl.text.trim();
            // 数据安全：只允许 HTTPS；HTTP 仅限本机回环地址
            final Uri? uri = Uri.tryParse(url);
            final isLoopback = uri?.host == '127.0.0.1' ||
                uri?.host == 'localhost' ||
                uri?.host == '::1';
            if (url.isEmpty ||
                !(uri?.scheme == 'https' ||
                    (uri?.scheme == 'http' && isLoopback))) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('地址须为 HTTPS（本机测试可用 http://127.0.0.1）'),
                ),
              );
              return;
            }
            final dialogCtx = ctx;
            await _service.save(url, tokenCtrl.text.trim());
            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            if (!outerCtx.mounted) return;
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
      final result = await _service.upload(jsonStr, backupName: backupName);
      if (result.serverOk) {
        // 服务端自动维护快照与保留策略（每次备份前自动存 10 份 .vNN 快照）
        _backups = await _service.list();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('备份失败: $e')));
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
      if (!mounted) return; // 导入要读 context 上的 provider，先确认页面还在
      // 直接走统一导入入口：失败会抛出并由下面的 catch 提示「未改动任何数据」，
      // 不再像旧实现那样吞掉异常后仍然弹「恢复成功 ✓」。
      final outcome = await _importFromBackupJson(context, jsonStr);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复成功 ✓\n${outcome.describe()}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复失败，未改动任何数据：$e'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
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

  
}


