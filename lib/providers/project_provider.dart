import 'package:flutter/foundation.dart';
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
      print('加载项目失败: $e');
      rethrow;
    }
  }

  Future<void> addProject(Project project) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        AppConstants.tableProjects,
        project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _projects.insert(0, project);
      notifyListeners();
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
      print('更新项目失败: $e');
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
      print('归档项目失败: $e');
      rethrow;
    }
  }

  Future<void> deleteProject(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        AppConstants.tableProjects,
        where: 'id = ?',
        whereArgs: [id],
      );
      _projects.removeWhere((p) => p.id == id);
      notifyListeners();
      // 联动清理子 provider 的内存缓存（DB 端子表由外键 ON DELETE CASCADE 处理）
      _work?.removeByProject(id);
      _borrow?.removeByProject(id);
      _settlement?.removeByProject(id);
      _photo?.removeByProject(id);
    } catch (e) {
      print('删除项目失败: $e');
      rethrow;
    }
  }
}
