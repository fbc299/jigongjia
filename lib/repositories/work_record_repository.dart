import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/work_record.dart';

class WorkRecordRepository {
  /// Load all work records ordered by date descending.
  Future<List<WorkRecord>> loadAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableWorkRecords,
      orderBy: 'date DESC',
    );
    return maps.map((m) => WorkRecord.fromMap(m)).toList();
  }

  /// Load work records with pagination.
  Future<List<WorkRecord>> loadPaged({int limit = 50, int offset = 0}) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableWorkRecords,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => WorkRecord.fromMap(m)).toList();
  }

  /// Insert a work record. Throws if ID already exists (DATA-004).
  Future<void> insert(WorkRecord record) async {
    final db = await DatabaseHelper.instance.database;
    // Check for existing record to prevent silent overwrite
    final existing = await db.query(
      AppConstants.tableWorkRecords,
      where: 'id = ?',
      whereArgs: [record.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw StateError('记录已存在 (id: ${record.id})，请使用 update');
    }
    await db.insert(
      AppConstants.tableWorkRecords,
      record.toMap(),
    );
  }

  /// Update a work record.
  Future<void> update(WorkRecord record) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tableWorkRecords,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// Delete a work record by id.
  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableWorkRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
