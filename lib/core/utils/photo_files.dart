import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

/// 导出/上传备份时把照片路径降级成纯文件名：
/// 一是别把设备目录结构传上服务器，二是换机后路径必然失效。
String backupPhotoPath(String filePath) => p.basename(filePath);

/// 导入备份时把纯文件名还原成本机的照片绝对路径（旧备份里的绝对路径原样保留）。
Future<String> resolvePhotoPath(String stored) async {
  if (p.isAbsolute(stored)) return stored;
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'photo_evidence', stored);
}
