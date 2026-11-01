import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/models/photo_evidence.dart';

void main() {
  test('缩略图字段能序列化/反序列化', () {
    final photo = PhotoEvidence(
      projectId: 'p1',
      filePath: '/data/app/photo_evidence/a.jpg',
      thumbPath: '/data/app/photo_evidence/a_thumb.jpg',
      projectName: '工地A',
      timestamp: DateTime(2026, 11, 1, 10),
    );
    final restored = PhotoEvidence.fromMap(photo.toMap());
    expect(restored.thumbPath, photo.thumbPath);
    expect(restored.filePath, photo.filePath);
  });

  test('老备份没有 thumbPath 字段时回退空串', () {
    final map = PhotoEvidence(
      projectId: 'p1',
      filePath: '/x/a.jpg',
      projectName: '工地A',
      timestamp: DateTime(2026, 11, 1),
    ).toMap()
      ..remove('thumbPath');
    expect(PhotoEvidence.fromMap(map).thumbPath, '');
  });

  test('copyWith 能单独更新 thumbPath', () {
    final photo = PhotoEvidence(
      projectId: 'p1',
      filePath: '/x/a.jpg',
      projectName: '工地A',
      timestamp: DateTime(2026, 11, 1),
    );
    final updated = photo.copyWith(thumbPath: '/x/a_thumb.jpg');
    expect(updated.thumbPath, '/x/a_thumb.jpg');
    expect(updated.filePath, '/x/a.jpg');
  });
}
