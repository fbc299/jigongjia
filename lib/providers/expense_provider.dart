import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/account/account_service.dart';
import '../core/constants/app_constants.dart';
import '../models/expense.dart';

class ExpenseProvider extends ChangeNotifier {
  /// Selector helper: wrap Selector<ExpenseProvider, T> to reduce rebuilds.
  static Widget select<T>({
    required T Function(ExpenseProvider) selector,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return Selector<ExpenseProvider, T>(
      selector: (_, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }
  List<Expense> _expenses = [];

  List<Expense> get expenses => _expenses;

  Future<void> loadExpenses() async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
      final maps = await db.query(
        AppConstants.tableExpenses,
        orderBy: 'date DESC',
      );
      _expenses = maps.map((m) => Expense.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      print('加载开支记录失败: $e');
      rethrow;
    }
  }

  /// 账号切换后重载：清空内存缓存并重新从当前账号库读取。
  Future<void> reloadAll() async {
    _expenses.clear();
    await loadExpenses();
  }

  Future<void> addExpense(Expense expense) async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
      await db.insert(
        AppConstants.tableExpenses,
        expense.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _expenses.insert(0, expense);
      notifyListeners();
    } catch (e) {
      print('添加开支记录失败: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      final db = await DatabaseHelper.instance.databaseForAccount(AccountService().currentUsername);
      await db.delete(
        AppConstants.tableExpenses,
        where: 'id = ?',
        whereArgs: [id],
      );
      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      print('删除开支记录失败: $e');
      rethrow;
    }
  }

  double getMonthlyTotal(int year, int month) {
    return _expenses
        .where((e) => e.date.year == year && e.date.month == month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Map<String, double> getCategoryTotals(int year, int month) {
    final monthExpenses =
        _expenses.where((e) => e.date.year == year && e.date.month == month);
    final totals = <String, double>{};
    for (final expense in monthExpenses) {
      totals[expense.category] = (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }
}
