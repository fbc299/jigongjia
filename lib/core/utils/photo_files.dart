import 'dart:io';

import 'package:flutter/foundation.dart';

/// 照片文件清理。
///
/// 数据库里的 photo_evidence 行只是路径索引，图片本体落在
/// `${appDocuments}/photo_evidence/`。删项目/删照片时如果只删 DB 行，
/// 图片会永远留在磁盘上（用户看不到，也删不掉）。
Future<int> deletePhotoFiles(Iterable<String> paths) async {
  var deleted = 0;
  for (final path in paths) {
    if (path.isEmpty) continue;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        deleted++;
      }
    } catch (e) {
      // 单个文件删不掉不影响整体流程（可能被占用/已不存在）
      debugPrint('删除照片文件失败 $path: $e');
    }
  }
  return deleted;
}
