import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 备份体客户端加密。
///
/// 服务端只做不透明存储（NAS 的 backups.db + 腾讯云 COS 镜像），所以加密必须在客户端做，
/// 否则工资明细就是明文躺在服务器和对象存储里。
///
/// 结构（JSON 外壳，服务端原样保存）：
/// ```json
/// {"format":"aes256-cbc-pbkdf2-v1","iterations":30000,
///  "salt":"base64","iv":"base64","mac":"base64","data":"base64"}
/// ```
/// - 密钥：PBKDF2-HMAC-SHA256(passphrase=备份 token, salt=随机 16B, iterations, 输出 64B)
///   前 32B 做 AES-256 密钥，后 32B 做 HMAC-SHA256 密钥
/// - 加密：AES-256-CBC + PKCS#7
/// - 完整性：HMAC-SHA256(iv || ciphertext)，解密前先校验，防篡改
///
/// 注意：pointycastle 4.x 的 `process()` 只处理第一个 block，必须自己按 16 字节循环
/// `processBlock`，否则超过 16 字节的备份会被加密错。
class BackupCrypto {
  BackupCrypto._();

  static const String formatTag = 'aes256-cbc-pbkdf2-v1';
  // 30000 轮 PBKDF2-HMAC-SHA256：口令本身是 43 字符的随机 token（高熵），
  // 纯 Dart 实现下再往上加轮次只会让手机端每次备份多卡几秒，收益很低。
  static const int iterations = 30000;
  static const int _blockSize = 16;

  static final Random _rng = Random.secure();

  static Uint8List _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  static Uint8List _pbkdf2(String passphrase, Uint8List salt, int iter) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iter, 64));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  static Uint8List _hmac(Uint8List key, Uint8List data) {
    final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
    return mac.process(data);
  }

  static Uint8List _pkcs7Pad(Uint8List input) {
    final padLen = _blockSize - (input.length % _blockSize);
    final out = Uint8List(input.length + padLen);
    out.setRange(0, input.length, input);
    for (var i = 0; i < padLen; i++) {
      out[input.length + i] = padLen;
    }
    return out;
  }

  static Uint8List _pkcs7Unpad(Uint8List input) {
    if (input.isEmpty) throw const FormatException('密文为空');
    final padLen = input.last;
    if (padLen < 1 || padLen > _blockSize || padLen > input.length) {
      throw const FormatException('填充非法，可能是密钥错误或数据被改动');
    }
    for (var i = input.length - padLen; i < input.length; i++) {
      if (input[i] != padLen) {
        throw const FormatException('填充非法，可能是密钥错误或数据被改动');
      }
    }
    return Uint8List.sublistView(input, 0, input.length - padLen);
  }

  /// 加密明文 JSON，返回可直接上传的外壳字符串。
  static String encrypt(String plainJson, String passphrase) {
    if (passphrase.isEmpty) {
      throw ArgumentError('备份口令不能为空');
    }
    final salt = _randomBytes(16);
    final iv = _randomBytes(16);
    final derived = _pbkdf2(passphrase, salt, iterations);
    final encKey = Uint8List.sublistView(derived, 0, 32);
    final macKey = Uint8List.sublistView(derived, 32, 64);

    final plain = Uint8List.fromList(utf8.encode(plainJson));
    final padded = _pkcs7Pad(plain);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(encKey), iv));
    final cipherText = Uint8List(padded.length);
    for (var offset = 0; offset < padded.length; offset += _blockSize) {
      cipher.processBlock(padded, offset, cipherText, offset);
    }

    final macInput = Uint8List(iv.length + cipherText.length)
      ..setRange(0, iv.length, iv)
      ..setRange(iv.length, iv.length + cipherText.length, cipherText);
    final mac = _hmac(macKey, macInput);

    return json.encode({
      'format': formatTag,
      'iterations': iterations,
      'salt': base64.encode(salt),
      'iv': base64.encode(iv),
      'mac': base64.encode(mac),
      'data': base64.encode(cipherText),
    });
  }

  /// 判断一个 body 是否是本模块加密过的外壳。
  static bool isEncryptedBody(String body) {
    final trimmed = body.trimLeft();
    if (!trimmed.startsWith('{')) return false;
    try {
      final map = json.decode(trimmed);
      return map is Map && map['format'] == formatTag;
    } catch (_) {
      return false;
    }
  }

  /// 解密。口令错误 / 数据被改动都会抛 FormatException（不是静默返回垃圾）。
  static String decrypt(String body, String passphrase) {
    final map = json.decode(body);
    if (map is! Map || map['format'] != formatTag) {
      throw const FormatException('不是加过密的备份');
    }
    final salt = base64.decode(map['salt'] as String);
    final iv = base64.decode(map['iv'] as String);
    final macBytes = base64.decode(map['mac'] as String);
    final data = base64.decode(map['data'] as String);
    final iter = (map['iterations'] as num?)?.toInt() ?? iterations;

    final derived = _pbkdf2(passphrase, salt, iter);
    final encKey = Uint8List.sublistView(derived, 0, 32);
    final macKey = Uint8List.sublistView(derived, 32, 64);

    final macInput = Uint8List(iv.length + data.length)
      ..setRange(0, iv.length, iv)
      ..setRange(iv.length, iv.length + data.length, data);
    final expected = _hmac(macKey, macInput);
    if (!_constantTimeEquals(expected, macBytes)) {
      throw const FormatException('备份校验失败：口令不正确或数据被篡改');
    }

    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(encKey), iv));
    final padded = Uint8List(data.length);
    for (var offset = 0; offset < data.length; offset += _blockSize) {
      cipher.processBlock(data, offset, padded, offset);
    }
    return utf8.decode(_pkcs7Unpad(padded));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
