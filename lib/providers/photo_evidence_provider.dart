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
      debugPrint('加载照片记录失败: $e');
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
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      // 与 DB 的 `ORDER BY createdAt DESC` 保持一致
      _photos..add(photo)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('添加照片记录失败: $e');
      rethrow;
    }
  }

  /// 老数据补缩略图：把 thumbPath 写回 DB 与内存（生成任务由调用方完成）。
  Future<void> updateThumbPath(String id, String thumbPath) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        AppConstants.tablePhotoEvidence,
        {'thumbPath': thumbPath},
        where: 'id = ?',
        whereArgs: [id],
      );
      final index = _photos.indexWhere((p) => p.id == id);
      if (index >= 0) {
        _photos[index] = _photos[index].copyWith(thumbPath: thumbPath);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('更新缩略图路径失败: $e');
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
      debugPrint('删除照片记录失败: $e');
      rethrow;
    }
  }
}
