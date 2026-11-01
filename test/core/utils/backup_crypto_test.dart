import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/core/utils/backup_crypto.dart';

void main() {
  const pass = 'test-token-梅花-123';

  test('长文本（多 block）加解密往返一致', () {
    final payload = json.encode({
      'version': 1,
      'projects': List.generate(50, (i) => {'id': 'p$i', 'name': '项目$i'}),
    });
    expect(payload.length, greaterThan(16 * 4));

    final encrypted = BackupCrypto.encrypt(payload, pass);
    expect(BackupCrypto.isEncryptedBody(encrypted), isTrue);
    expect(encrypted, isNot(contains('项目')));
    expect(BackupCrypto.decrypt(encrypted, pass), payload);
  });

  test('短文本往返一致（含单 block 以内）', () {
    for (final s in ['{}', '{"a":1}', 'x' * 15, 'y' * 16, 'z' * 17]) {
      expect(BackupCrypto.decrypt(BackupCrypto.encrypt(s, pass), pass), s);
    }
  });

  test('口令错误抛 FormatException（不返回垃圾）', () {
    final encrypted = BackupCrypto.encrypt('{"a":1}', pass);
    expect(() => BackupCrypto.decrypt(encrypted, 'wrong-pass'),
        throwsA(isA<FormatException>()));
  });

  test('密文被篡改会被 HMAC 拦住', () {
    final encrypted = BackupCrypto.encrypt('{"a":1}', pass);
    final map = json.decode(encrypted) as Map<String, dynamic>;
    final data = base64.decode(map['data'] as String);
    data[0] = data[0] ^ 0xFF;
    map['data'] = base64.encode(data);
    expect(() => BackupCrypto.decrypt(json.encode(map), pass),
        throwsA(isA<FormatException>()));
  });

  test('明文 body 不会被误判为密文', () {
    expect(BackupCrypto.isEncryptedBody('{"version":1}'), isFalse);
    expect(BackupCrypto.isEncryptedBody('not json'), isFalse);
  });
}
