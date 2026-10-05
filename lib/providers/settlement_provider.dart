import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/account/account_service.dart';
import '../core/constants/app_constants.dart';
import '../models/settlement.dart';

class SettlementProvider extends ChangeNotifier {
  /// Selector helper: wrap Selector<SettlementProvider, T> to reduce rebuilds.
  static Widget select<T>({
    required T Function(SettlementProvider) selector,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return Selector<SettlementProvider, T>(
      selector: (_, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }
  List<Settlement> _settlements = [];

  List<Settlement> get settlements => _settlements;

  Future<void> loadSettlements() async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
      final maps = await db.query(
        AppConstants.tableSettlements,
        orderBy: 'date DESC',
      );
      _settlements = maps.map((m) => Settlement.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      print('加载结算记录失败: $e');
      rethrow;
    }
  }

  /// 账号切换后重载：清空内存缓存并重新从当前账号库读取。
  Future<void> reloadAll() async {
    _settlements.clear();
    await loadSettlements();
  }

  Future<void> addSettlement(Settlement settlement) async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
      await db.insert(
        AppConstants.tableSettlements,
        settlement.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _settlements.insert(0, settlement);
      notifyListeners();
    } catch (e) {
      print('添加结算记录失败: $e');
      rethrow;
    }
  }

  Future<void> deleteSettlement(String id) async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
      await db.delete(
        AppConstants.tableSettlements,
        where: 'id = ?',
        whereArgs: [id],
      );
      _settlements.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      print('删除结算记录失败: $e');
      rethrow;
    }
  }

  List<Settlement> getSettlementsByProject(String projectId) {
    return _settlements.where((s) => s.projectId == projectId).toList();
  }

  /// 移除某个项目的所有记录（配合项目删除，清理内存缓存）
  void removeByProject(String projectId) {
    _settlements.removeWhere((s) => s.projectId == projectId);
    notifyListeners();
  }
}
