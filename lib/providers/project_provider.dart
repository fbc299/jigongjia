import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/project.dart';

class ProjectProvider extends ChangeNotifier {
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
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableProjects,
      orderBy: 'createdAt DESC',
    );
    _projects = maps.map((m) => Project.fromMap(m)).toList();
    notifyListeners();
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
  }

  Future<void> archiveProject(String id) async {
    final project = getProjectById(id);
    if (project == null) return;
    final archived = project.copyWith(isArchived: true);
    await updateProject(archived);
  }

  Future<void> deleteProject(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableProjects,
      where: 'id = ?',
      whereArgs: [id],
    );
    _projects.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
