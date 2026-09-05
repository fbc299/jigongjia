import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/settlement.dart';

class SettlementProvider extends ChangeNotifier {
  List<Settlement> _settlements = [];

  List<Settlement> get settlements => _settlements;

  Future<void> loadSettlements() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableSettlements,
      orderBy: 'date DESC',
    );
    _settlements = maps.map((m) => Settlement.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addSettlement(Settlement settlement) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableSettlements,
      settlement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _settlements.insert(0, settlement);
    notifyListeners();
  }

  Future<void> deleteSettlement(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableSettlements,
      where: 'id = ?',
      whereArgs: [id],
    );
    _settlements.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  List<Settlement> getSettlementsByProject(String projectId) {
    return _settlements.where((s) => s.projectId == projectId).toList();
  }
}
