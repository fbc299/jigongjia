import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/borrow_record.dart';

class BorrowRecordRepository {
  /// Load all borrow records ordered by date descending.
  Future<List<BorrowRecord>> loadAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableBorrowRecords,
      orderBy: 'date DESC',
    );
    return maps.map((m) => BorrowRecord.fromMap(m)).toList();
  }

  /// Insert a borrow record.
  Future<void> insert(BorrowRecord record) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableBorrowRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a borrow record.
  Future<void> update(BorrowRecord record) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tableBorrowRecords,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// Delete a borrow record by id.
  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableBorrowRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
