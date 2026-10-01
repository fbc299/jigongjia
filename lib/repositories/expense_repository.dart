import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/expense.dart';

class ExpenseRepository {
  Future<List<Expense>> loadAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableExpenses,
      orderBy: 'date DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<void> insert(Expense expense) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableExpenses,
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableExpenses,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
