import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/work_record.dart';

class WorkProvider extends ChangeNotifier {
  /// Selector helper: wrap Selector<WorkProvider, T> to reduce rebuilds.
  static Widget select<T>({
    required T Function(WorkProvider) selector,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return Selector<WorkProvider, T>(
      selector: (_, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }
  List<WorkRecord> _records = [];

  List<WorkRecord> get records => _records;

  Future<void> loadRecords() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        AppConstants.tableWorkRecords,
        orderBy: 'date DESC',
      );
      _records = maps.map((m) => WorkRecord.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      print('加载工时记录失败: $e');
      rethrow;
    }
  }

  Future<void> addRecord(WorkRecord record) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        AppConstants.tableWorkRecords,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _records.insert(0, record);
      notifyListeners();
    } catch (e) {
      print('添加工时记录失败: $e');
      rethrow;
    }
  }

  Future<void> updateRecord(WorkRecord record) async {
    try {
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
    } catch (e) {
      print('更新工时记录失败: $e');
      rethrow;
    }
  }

  Future<void> deleteRecord(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        AppConstants.tableWorkRecords,
        where: 'id = ?',
        whereArgs: [id],
      );
      _records.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      print('删除工时记录失败: $e');
      rethrow;
    }
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
