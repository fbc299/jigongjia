import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
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

/// 生成列表用缩略图（长边 400px，JPEG q80），返回缩略图路径；失败返回空串。
///
/// 照片原图是 1920px、几百 KB～2MB，列表里直接解码原图会明显占内存、滚动掉帧。
Future<String> generateThumbnail(String sourcePath, {int maxSide = 400}) async {
  try {
    final source = File(sourcePath);
    if (!await source.exists()) return '';
    final bytes = await source.readAsBytes();
    final thumbBytes = await compute(_makeThumbBytes, {
      'bytes': bytes,
      'maxSide': maxSide,
    });
    if (thumbBytes == null || thumbBytes.isEmpty) return '';
    final dir = source.parent;
    final name = p.basenameWithoutExtension(sourcePath);
    final thumbPath = p.join(dir.path, '${name}_thumb.jpg');
    await File(thumbPath).writeAsBytes(thumbBytes, flush: true);
    return thumbPath;
  } catch (e) {
    debugPrint('生成缩略图失败 $sourcePath: $e');
    return '';
  }
}

/// 顶层函数：compute 要求参数可跨 isolate 传递（这里用 Map + Uint8List）。
Uint8List? _makeThumbBytes(Map<String, dynamic> job) {
  final bytes = job['bytes'] as Uint8List;
  final maxSide = job['maxSide'] as int;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? maxSide : null,
    height: decoded.height > decoded.width ? maxSide : null,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}

/// 列表展示用：有缩略图且文件存在就用缩略图，否则回退原图。
String displayPhotoPath(String filePath, String thumbPath) {
  if (thumbPath.isEmpty) return filePath;
  try {
    if (File(thumbPath).existsSync()) return thumbPath;
  } catch (_) {}
  return filePath;
}
