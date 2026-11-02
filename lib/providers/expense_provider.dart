import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
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

  /// 仅供测试注入数据
  set expensesForTest(List<Expense> value) => _expenses = value;

  Future<void> loadExpenses() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        AppConstants.tableExpenses,
        orderBy: 'date DESC',
      );
      _expenses = maps.map((m) => Expense.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('加载开支记录失败: $e');
      rethrow;
    }
  }

  Future<void> addExpense(Expense expense) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        AppConstants.tableExpenses,
        expense.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      // 与 DB 的 `ORDER BY date DESC` 保持一致
      _expenses..add(expense)..sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    } catch (e) {
      debugPrint('添加开支记录失败: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        AppConstants.tableExpenses,
        where: 'id = ?',
        whereArgs: [id],
      );
      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('删除开支记录失败: $e');
      rethrow;
    }
  }

  /// 某项目的开支合计（projectId 传空串表示全部项目）
  double getTotalByProject(String projectId) {
    if (projectId.isEmpty) return _expenses.fold(0.0, (sum, e) => sum + e.amount);
    return _expenses
        .where((e) => e.projectId == projectId)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  List<Expense> getExpensesByProject(String projectId) =>
      _expenses.where((e) => e.projectId == projectId).toList();

  /// 删除项目后清理内存缓存（DB 行的清理由项目页负责）
  void removeByProject(String projectId) {
    _expenses.removeWhere((e) => e.projectId == projectId);
    notifyListeners();
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
