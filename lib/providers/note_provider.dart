import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/account/account_service.dart';
import '../core/constants/app_constants.dart';
import '../models/note.dart';

class NoteProvider extends ChangeNotifier {
  /// Selector helper: wrap Selector<NoteProvider, T> to reduce rebuilds.
  static Widget select<T>({
    required T Function(NoteProvider) selector,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return Selector<NoteProvider, T>(
      selector: (_, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }
  List<Note> _notes = [];

  List<Note> get notes => _notes;

  Future<void> loadNotes() async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
      final maps = await db.query(
        AppConstants.tableNotes,
        orderBy: 'updatedAt DESC',
      );
      _notes = maps.map((m) => Note.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      print('加载笔记失败: $e');
      rethrow;
    }
  }

  /// 账号切换后重载：清空内存缓存并重新从当前账号库读取。
  Future<void> reloadAll() async {
    _notes.clear();
    await loadNotes();
  }

  Future<void> addNote(Note note) async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
      await db.insert(
        AppConstants.tableNotes,
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _notes.insert(0, note);
      notifyListeners();
    } catch (e) {
      print('添加笔记失败: $e');
      rethrow;
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
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
    } catch (e) {
      print('更新笔记失败: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
      await db.delete(
        AppConstants.tableNotes,
        where: 'id = ?',
        whereArgs: [id],
      );
      _notes.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (e) {
      print('删除笔记失败: $e');
      rethrow;
    }
  }

  List<Note> getNotesByProject(String projectId) {
    return _notes.where((n) => n.projectId == projectId).toList();
  }

  /// 移除某个项目的所有记录（配合项目删除，清理内存缓存）
  void removeByProject(String projectId) {
    _notes.removeWhere((n) => n.projectId == projectId);
    notifyListeners();
  }
}
