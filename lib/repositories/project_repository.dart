import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/project.dart';

class ProjectRepository {
  Future<List<Project>> loadAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableProjects,
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Project.fromMap(m)).toList();
  }

  Future<void> insert(Project project) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableProjects,
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Project project) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tableProjects,
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableProjects,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
