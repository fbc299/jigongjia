import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/expense.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Expense> _expenses = [];

  List<Expense> get expenses => _expenses;

  Future<void> loadExpenses() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableExpenses,
      orderBy: 'date DESC',
    );
    _expenses = maps.map((m) => Expense.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableExpenses,
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _expenses.insert(0, expense);
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableExpenses,
      where: 'id = ?',
      whereArgs: [id],
    );
    _expenses.removeWhere((e) => e.id == id);
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
