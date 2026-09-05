import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/borrow_record.dart';

class BorrowProvider extends ChangeNotifier {
  List<BorrowRecord> _records = [];

  List<BorrowRecord> get records => _records;

  Future<void> loadRecords() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableBorrowRecords,
      orderBy: 'date DESC',
    );
    _records = maps.map((m) => BorrowRecord.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addRecord(BorrowRecord record) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableBorrowRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _records.insert(0, record);
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableBorrowRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  List<BorrowRecord> getRecordsByProject(String projectId) {
    return _records.where((r) => r.projectId == projectId).toList();
  }

  double getTotalBorrowedByProject(String projectId) {
    return _records
        .where((r) => r.projectId == projectId)
        .fold(0.0, (sum, r) => sum + r.amount);
  }
}
