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
      debugPrint('加载工时记录失败: $e');
      rethrow;
    }
  }

  Future<void> addRecord(WorkRecord record) async {
    try {
      // 日期归一到当天 0 点：work_records 上有 UNIQUE(projectId, date)（db v2），
      // 带时分的时间戳会让「同一天」的两条记录落在不同 date 值上、绕过唯一约束（S3）。
      final normalized = _normalizeDay(record);
      final db = await DatabaseHelper.instance.database;
      // 用 abort 而不是 replace：replace 的 DELETE+INSERT 会绕过同日唯一约束，
      // 把已存在的那条记工静默覆盖掉（金额悄悄变了却没有提示）。
      await db.insert(
        AppConstants.tableWorkRecords,
        normalized.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      // 与 DB 的 `ORDER BY date DESC` 保持一致（补录旧日期时不能总插到最前）
      _records..add(normalized)..sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    } on DatabaseException catch (e) {
      debugPrint('添加工时记录失败: $e');
      if (e.isUniqueConstraintError()) {
        throw StateError('该日期已有记工记录，请直接编辑原记录');
      }
      rethrow;
    } catch (e) {
      debugPrint('添加工时记录失败: $e');
      rethrow;
    }
  }

  /// 丢弃时分秒，只保留当天（本地时区），用于同日唯一约束比较
  static WorkRecord _normalizeDay(WorkRecord r) => r.copyWith(
        date: DateTime(r.date.year, r.date.month, r.date.day),
      );

  Future<void> updateRecord(WorkRecord record) async {
    try {
      final normalized = _normalizeDay(record);
      final db = await DatabaseHelper.instance.database;
      await db.update(
        AppConstants.tableWorkRecords,
        normalized.toMap(),
        where: 'id = ?',
        whereArgs: [normalized.id],
      );
      final index = _records.indexWhere((r) => r.id == normalized.id);
      if (index != -1) {
        _records[index] = normalized;
        notifyListeners();
      } else {
        // 内存里没有这条（别处改过 / 尚未加载）：重新加载，不要假装更新成功
        await loadRecords();
      }
    } on DatabaseException catch (e) {
      debugPrint('更新工时记录失败: $e');
      if (e.isUniqueConstraintError()) {
        throw StateError('该日期已有记工记录，请直接编辑原记录');
      }
      rethrow;
    } catch (e) {
      debugPrint('更新工时记录失败: $e');
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
      debugPrint('删除工时记录失败: $e');
      rethrow;
    }
  }

  List<WorkRecord> getRecordsByProject(String projectId) {
    return _records.where((r) => r.projectId == projectId).toList();
  }

  /// 移除某个项目的所有记录（配合项目删除，清理内存缓存；DB 端由外键级联）
  void removeByProject(String projectId) {
    _records.removeWhere((r) => r.projectId == projectId);
    notifyListeners();
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
