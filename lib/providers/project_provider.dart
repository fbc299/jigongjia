import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/project.dart';
import '../providers/work_provider.dart';
import '../providers/borrow_provider.dart';
import '../providers/settlement_provider.dart';
import '../providers/photo_evidence_provider.dart';
import '../core/utils/photo_files.dart';

class ProjectProvider extends ChangeNotifier {
  /// 子数据 provider（项目删除时联动清理其内存缓存）。
  /// 在 main.dart 中通过 [attach] 注入。
  WorkProvider? _work;
  BorrowProvider? _borrow;
  SettlementProvider? _settlement;
  PhotoEvidenceProvider? _photo;

  void attach({
    WorkProvider? work,
    BorrowProvider? borrow,
    SettlementProvider? settlement,
    PhotoEvidenceProvider? photo,
  }) {
    _work = work;
    _borrow = borrow;
    _settlement = settlement;
    _photo = photo;
  }
  /// Selector helper: wrap Selector<ProjectProvider, T> to reduce rebuilds.
  static Widget select<T>({
    required T Function(ProjectProvider) selector,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return Selector<ProjectProvider, T>(
      selector: (_, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }
  List<Project> _projects = [];

  List<Project> get projects => _projects;

  List<Project> get activeProjects =>
      _projects.where((p) => !p.isArchived).toList();

  List<Project> get archivedProjects =>
      _projects.where((p) => p.isArchived).toList();

  Project? getProjectById(String id) {
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadProjects() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        AppConstants.tableProjects,
        orderBy: 'createdAt DESC',
      );
      _projects = maps.map((m) => Project.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('加载项目失败: $e');
      rethrow;
    }
  }

  Future<void> addProject(Project project) async {
    try {
      final db = await DatabaseHelper.instance.database;
      // 【禁止改回 ConflictAlgorithm.replace】projects 是 5 张子表（work_records /
      // borrow_records / settlements / photo_evidence / notes）的父表且均声明
      // ON DELETE CASCADE；SQLite 的 INSERT OR REPLACE 语义是「DELETE 旧行 + INSERT 新行」，
      // 一旦 id 已存在（合并备份 / 云同步回填 / 重试导入 / 外部传入 id）就会把该项目
      // 全部记工、借支、结算、照片、笔记物理删除，且 UI 完全正常、无任何提示。
      // 改用 abort：冲突直接抛异常，宁可不写入也不静默清空历史数据。
      await db.insert(
        AppConstants.tableProjects,
        project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      // 与 DB 的 `ORDER BY createdAt DESC` 保持一致
      _projects..add(project)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } on DatabaseException catch (e) {
      debugPrint('addProject error: $e');
      if (e.isUniqueConstraintError()) {
        throw StateError(
          '项目已存在（${project.name}，id=${project.id}），已取消写入以免覆盖其历史数据',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('addProject error: $e');
      rethrow;
    }
  }

  Future<void> updateProject(Project project) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        AppConstants.tableProjects,
        project.toMap(),
        where: 'id = ?',
        whereArgs: [project.id],
      );
      final index = _projects.indexWhere((p) => p.id == project.id);
      if (index != -1) {
        _projects[index] = project;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('更新项目失败: $e');
      rethrow;
    }
  }

  Future<void> archiveProject(String id) async {
    try {
      final project = getProjectById(id);
      if (project == null) return;
      final archived = project.copyWith(isArchived: true);
      await updateProject(archived);
    } catch (e) {
      debugPrint('归档项目失败: $e');
      rethrow;
    }
  }

  Future<void> deleteProject(String id) async {
    try {
      // 先记下这个项目的照片文件，DB 行删掉后就没法再查了
      final photoPaths =
          _photo?.getPhotosByProject(id).map((p) => p.filePath).toList() ?? const <String>[];
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        AppConstants.tableProjects,
        where: 'id = ?',
        whereArgs: [id],
      );
      // 图片本体不在数据库里，外键级联管不到：必须自己删，否则永久占磁盘
      await deletePhotoFiles(photoPaths);
      _projects.removeWhere((p) => p.id == id);
      notifyListeners();
      // 联动清理子 provider 的内存缓存（DB 端子表由外键 ON DELETE CASCADE 处理）
      _work?.removeByProject(id);
      _borrow?.removeByProject(id);
      _settlement?.removeByProject(id);
      _photo?.removeByProject(id);
    } catch (e) {
      debugPrint('删除项目失败: $e');
      rethrow;
    }
  }
}
