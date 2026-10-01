import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/borrow_record.dart';

class BorrowProvider extends ChangeNotifier {
  /// Selector helper: wrap Selector<BorrowProvider, T> to reduce rebuilds.
  static Widget select<T>({
    required T Function(BorrowProvider) selector,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return Selector<BorrowProvider, T>(
      selector: (_, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }
  List<BorrowRecord> _records = [];

  List<BorrowRecord> get records => _records;

  Future<void> loadRecords() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        AppConstants.tableBorrowRecords,
        orderBy: 'date DESC',
      );
      _records = maps.map((m) => BorrowRecord.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      print('加载借支记录失败: $e');
      rethrow;
    }
  }

  Future<void> addRecord(BorrowRecord record) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        AppConstants.tableBorrowRecords,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _records.insert(0, record);
      notifyListeners();
    } catch (e) {
      print('添加借支记录失败: $e');
      rethrow;
    }
  }

  Future<void> deleteRecord(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        AppConstants.tableBorrowRecords,
        where: 'id = ?',
        whereArgs: [id],
      );
      _records.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      print('删除借支记录失败: $e');
      rethrow;
    }
  }

  Future<void> updateRecord(BorrowRecord record) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        AppConstants.tableBorrowRecords,
        record.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
      final idx = _records.indexWhere((r) => r.id == record.id);
      if (idx >= 0) _records[idx] = record;
      notifyListeners();
    } catch (e) {
      print('更新借支记录失败: $e');
      rethrow;
    }
  }

  List<BorrowRecord> getRecordsByProject(String projectId) {
    return _records.where((r) => r.projectId == projectId).toList();
  }

  /// 移除某个项目的所有记录（配合项目删除，清理内存缓存）
  void removeByProject(String projectId) {
    _records.removeWhere((r) => r.projectId == projectId);
    notifyListeners();
  }

  double getTotalBorrowedByProject(String projectId) {
    return _records
        .where((r) => r.projectId == projectId)
        .fold(0.0, (sum, r) => sum + r.amount);
  }
}
