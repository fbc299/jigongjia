import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/note.dart';

class NoteProvider extends ChangeNotifier {
  List<Note> _notes = [];

  List<Note> get notes => _notes;

  Future<void> loadNotes() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableNotes,
      orderBy: 'updatedAt DESC',
    );
    _notes = maps.map((m) => Note.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addNote(Note note) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableNotes,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notes.insert(0, note);
    notifyListeners();
  }

  Future<void> updateNote(Note note) async {
    final db = await DatabaseHelper.instance.database;
    final updated = note.copyWith(updatedAt: DateTime.now());
    await db.update(
      AppConstants.tableNotes,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteNote(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableNotes,
      where: 'id = ?',
      whereArgs: [id],
    );
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  List<Note> getNotesByProject(String projectId) {
    return _notes.where((n) => n.projectId == projectId).toList();
  }
}
