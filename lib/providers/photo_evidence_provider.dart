import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/photo_evidence.dart';

class PhotoEvidenceProvider extends ChangeNotifier {
  List<PhotoEvidence> _photos = [];

  List<PhotoEvidence> get photos => _photos;

  Future<void> loadPhotos() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tablePhotoEvidence,
      orderBy: 'createdAt DESC',
    );
    _photos = maps.map((m) => PhotoEvidence.fromMap(m)).toList();
    notifyListeners();
  }

  List<PhotoEvidence> getPhotosByProject(String projectId) {
    return _photos.where((p) => p.projectId == projectId).toList();
  }

  Future<void> addPhoto(PhotoEvidence photo) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tablePhotoEvidence,
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _photos.insert(0, photo);
    notifyListeners();
  }

  Future<void> deletePhoto(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tablePhotoEvidence,
      where: 'id = ?',
      whereArgs: [id],
    );
    _photos.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
