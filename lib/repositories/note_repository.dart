import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/note.dart';

class NoteRepository {
  Future<List<Note>> loadAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableNotes,
      orderBy: 'updatedAt DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  Future<void> insert(Note note) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableNotes,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Note note) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tableNotes,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableNotes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
