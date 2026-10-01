import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/photo_evidence.dart';

class PhotoEvidenceRepository {
  Future<List<PhotoEvidence>> loadAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tablePhotoEvidence,
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => PhotoEvidence.fromMap(m)).toList();
  }

  Future<void> insert(PhotoEvidence photo) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tablePhotoEvidence,
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tablePhotoEvidence,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
