import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/photo_evidence.dart';

class PhotoEvidenceProvider extends ChangeNotifier {
  /// Selector helper: wrap Selector<PhotoEvidenceProvider, T> to reduce rebuilds.
  static Widget select<T>({
    required T Function(PhotoEvidenceProvider) selector,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return Selector<PhotoEvidenceProvider, T>(
      selector: (_, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }
  List<PhotoEvidence> _photos = [];

  List<PhotoEvidence> get photos => _photos;

  Future<void> loadPhotos() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        AppConstants.tablePhotoEvidence,
        orderBy: 'createdAt DESC',
      );
      _photos = maps.map((m) => PhotoEvidence.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      print('加载照片记录失败: $e');
      rethrow;
    }
  }

  List<PhotoEvidence> getPhotosByProject(String projectId) {
    return _photos.where((p) => p.projectId == projectId).toList();
  }

  /// 移除某个项目的所有记录（配合项目删除，清理内存缓存）
  void removeByProject(String projectId) {
    _photos.removeWhere((p) => p.projectId == projectId);
    notifyListeners();
  }

  Future<void> addPhoto(PhotoEvidence photo) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        AppConstants.tablePhotoEvidence,
        photo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _photos.insert(0, photo);
      notifyListeners();
    } catch (e) {
      print('添加照片记录失败: $e');
      rethrow;
    }
  }

  Future<void> deletePhoto(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        AppConstants.tablePhotoEvidence,
        where: 'id = ?',
        whereArgs: [id],
      );
      _photos.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      print('删除照片记录失败: $e');
      rethrow;
    }
  }
}
