import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/settlement.dart';

class SettlementRepository {
  Future<List<Settlement>> loadAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableSettlements,
      orderBy: 'date DESC',
    );
    return maps.map((m) => Settlement.fromMap(m)).toList();
  }

  Future<void> insert(Settlement settlement) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableSettlements,
      settlement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableSettlements,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
