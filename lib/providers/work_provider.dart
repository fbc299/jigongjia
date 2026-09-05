import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/work_record.dart';

class WorkProvider extends ChangeNotifier {
  List<WorkRecord> _records = [];

  List<WorkRecord> get records => _records;

  Future<void> loadRecords() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableWorkRecords,
      orderBy: 'date DESC',
    );
    _records = maps.map((m) => WorkRecord.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addRecord(WorkRecord record) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableWorkRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _records.insert(0, record);
    notifyListeners();
  }

  Future<void> updateRecord(WorkRecord record) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tableWorkRecords,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _records[index] = record;
      notifyListeners();
    }
  }

  Future<void> deleteRecord(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableWorkRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  List<WorkRecord> getRecordsByProject(String projectId) {
    return _records.where((r) => r.projectId == projectId).toList();
  }

  List<WorkRecord> getRecordsByMonth(String projectId, int year, int month) {
    return _records.where((r) {
      return r.projectId == projectId &&
          r.date.year == year &&
          r.date.month == month;
    }).toList();
  }

  List<WorkRecord> getRecordsByDate(String projectId, DateTime date) {
    return _records.where((r) {
      return r.projectId == projectId &&
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day;
    }).toList();
  }
}
