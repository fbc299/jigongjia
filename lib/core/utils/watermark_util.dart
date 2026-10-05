import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WatermarkUtil {
  WatermarkUtil._();

  static Future<String> addWatermark(
    String imagePath,
    String projectName,
    DateTime timestamp, {
    String? account,
  }) async {
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

    final image = original.clone();

    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
    final watermarkText = '$projectName | $dateStr';

    // Draw shadow (offset by 2 pixels)
    img.drawString(
      image,
      watermarkText,
      font: img.arial24,
      x: 22,
      y: image.height - 58,
      color: img.ColorRgb8(0, 0, 0),
    );

    // Draw main text
    img.drawString(
      image,
      watermarkText,
      font: img.arial24,
      x: 20,
      y: image.height - 60,
      color: img.ColorRgb8(255, 255, 255),
    );

    // Save to app documents directory (per-account subdir)
    final appDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory(
      (account == null || account.isEmpty)
          ? p.join(appDir.path, 'photo_evidence')
          : p.join(appDir.path, 'photo_evidence', account),
    );
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    final timestampMs = timestamp.millisecondsSinceEpoch;
    final ext = p.extension(imagePath);
    final outputPath = p.join(photoDir.path, 'watermark_$timestampMs$ext');

    final encodedBytes = img.encodePng(image);
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(encodedBytes);

    return outputPath;
    } catch (e) {
      print('添加水印失败: $e');
      rethrow;
    }
  }
}
