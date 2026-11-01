import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 拍照留证水印。
///
/// 关键点：image 包自带的 `arial24` **不含中文字形**，直接 drawString 会把中文项目名
/// 整个丢掉（照片上只剩日期数字）。这里改走 Flutter 的 TextPainter + 中文字体渲染
/// 文字图层，再把图层合成到照片上；解码/合成/编码放到后台 isolate，避免大图卡 UI。
class WatermarkUtil {
  WatermarkUtil._();

  static const String _fontFamily = 'JigongWatermarkCJK';
  static bool _fontLoaded = false;

  static Future<void> _ensureFont() async {
    if (_fontLoaded) return;
    _fontLoaded = true;
    try {
      final loader = FontLoader(_fontFamily)
        ..addFont(rootBundle.load('assets/fonts/CJKFont.ttf'));
      await loader.load();
    } catch (e) {
      debugPrint('加载水印中文字体失败: $e');
    }
  }

  static Future<String> addWatermark(
    String imagePath,
    String projectName,
    DateTime timestamp,
  ) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw FileSystemException('Image file not found', imagePath);
      }

      final bytes = await file.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) {
        throw Exception('Failed to decode image');
      }

      await _ensureFont();

      final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
      final text = '$projectName | $dateStr';

      // 字号按图片宽度自适应：1080 宽的照片约 38px
      final fontSize = (original.width * 0.035).clamp(18.0, 64.0);
      final layer = await _renderTextLayer(text, fontSize);
      if (layer == null) {
        throw Exception('水印文字渲染失败');
      }

      final margin = (original.width * 0.02).clamp(12.0, 48.0);
      final dstX = margin.round();
      final dstY = (original.height - layer.height - margin.round())
          .clamp(0, original.height);

      final appDir = await getApplicationDocumentsDirectory();
      final photoDir = Directory(p.join(appDir.path, 'photo_evidence'));
      if (!await photoDir.exists()) {
        await photoDir.create(recursive: true);
      }

      // 输出编码跟随原图：jpg/jpeg 出 JPEG（体积小得多），其余出 PNG。
      // 旧实现统一 encodePng 却沿用原扩展名，等于 .jpg 文件里装 PNG。
      final ext = p.extension(imagePath).toLowerCase().replaceFirst('.', '');
      final isJpeg = ext == 'jpg' || ext == 'jpeg';
      final outExt = isJpeg ? 'jpg' : 'png';
      final outputPath = p.join(
        photoDir.path,
        'watermark_${timestamp.millisecondsSinceEpoch}.$outExt',
      );

      return await compute(
        _compositeAndSave,
        _WatermarkJob(
          sourceBytes: bytes,
          layerRgba: layer.rgba,
          layerWidth: layer.width,
          layerHeight: layer.height,
          dstX: dstX,
          dstY: dstY,
          outputPath: outputPath,
          encodeJpeg: isJpeg,
        ),
      );
    } catch (e) {
      debugPrint('添加水印失败: $e');
      rethrow;
    }
  }

  /// 用中文字体把文字画成透明背景的 RGBA 图层。
  static Future<_TextLayer?> _renderTextLayer(String text, double fontSize) async {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFFFFFFF),
          shadows: const [
            Shadow(color: Color(0xCC000000), offset: Offset(2, 2), blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final width = painter.width.ceil() + 8;
    final height = painter.height.ceil() + 8;
    if (width <= 0 || height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Offset(4, 4));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    if (data == null) return null;

    return _TextLayer(
      rgba: data.buffer.asUint8List(),
      width: width,
      height: height,
    );
  }
}

class _TextLayer {
  final Uint8List rgba;
  final int width;
  final int height;
  const _TextLayer({required this.rgba, required this.width, required this.height});
}

class _WatermarkJob {
  final Uint8List sourceBytes;
  final Uint8List layerRgba;
  final int layerWidth;
  final int layerHeight;
  final int dstX;
  final int dstY;
  final String outputPath;
  final bool encodeJpeg;

  const _WatermarkJob({
    required this.sourceBytes,
    required this.layerRgba,
    required this.layerWidth,
    required this.layerHeight,
    required this.dstX,
    required this.dstY,
    required this.outputPath,
    required this.encodeJpeg,
  });
}

/// 后台 isolate：解码原图 → 叠加文字图层 → 编码写盘。
String _compositeAndSave(_WatermarkJob job) {
  final base = img.decodeImage(job.sourceBytes);
  if (base == null) {
    throw Exception('Failed to decode image');
  }
  final overlay = img.Image.fromBytes(
    width: job.layerWidth,
    height: job.layerHeight,
    bytes: job.layerRgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  img.compositeImage(base, overlay, dstX: job.dstX, dstY: job.dstY);

  final encoded =
      job.encodeJpeg ? img.encodeJpg(base, quality: 90) : img.encodePng(base);
  File(job.outputPath).writeAsBytesSync(encoded);
  return job.outputPath;
}
