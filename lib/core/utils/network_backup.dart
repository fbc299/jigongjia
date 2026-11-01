import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_crypto.dart';

/// Progress callback: reports 0.0 ~ 1.0 during upload/download operations.
typedef ProgressCallback = void Function(double progress);

/// 一次备份上传的结果：分别记录「服务器」与「腾讯云存储桶(COS)」是否成功。
class BackupUploadResult {
  final String name;
  /// 服务器（NAS 备份服务端）是否成功。
  final bool serverOk;
  /// 腾讯云存储桶是否成功；null = 服务端未报告（旧版本）。
  final bool? cosOk;

  const BackupUploadResult({
    required this.name,
    required this.serverOk,
    this.cosOk,
  });

  /// 生成给用户的提示文案（哪个失败就报哪个）。
  String get message {
    if (!serverOk) return '服务器备份失败';
    switch (cosOk) {
      case true:
        return '备份成功：服务器 ✓ 腾讯云存储桶 ✓';
      case false:
        return '服务器备份成功 ✓，但腾讯云存储桶备份失败';
      default:
        return '备份成功：服务器 ✓';
    }
  }
}

/// Network backup via NAS backup server (IPv6 direct, no DNS needed)
/// Enhanced with retry (exponential backoff) and progress callbacks.
/// 服务器拒绝访问：本机没有备份口令，或口令被换掉了。
/// 卸载重装、清除数据都会把 Keystore 里的口令一起清掉，但服务器上的备份还在，
/// 重新填入口令即可恢复——所以这里必须抛明确异常，不能当成「没有备份」。
class BackupAuthException implements Exception {
  final String message;
  const BackupAuthException([
    this.message = '本机没有备份口令，或口令已失效（服务器上的备份仍在）',
  ]);

  @override
  String toString() => message;
}

class NetworkBackupService {
  static const _prefUrl = 'backup_server_url';
  static const _prefToken = 'backup_server_token';
  static const _defaultUrl = 'https://bf.fbc299.xyz';
  // Token 不再硬编码进 APK（H5）：默认空，用户在「设置→备份服务器」填入。
  // 留空时服务端按匿名模式处理，仅做备份文件读写。
  static const _defaultToken = '';

  /// 备份 token 就是加密口令：它能读/写/删服务器上全部备份，
  /// 不能明文躺在 SharedPreferences（root / adb / 云备份都能取走）。
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String _serverUrl = _defaultUrl;
  String _token = _defaultToken;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefUrl) ?? _defaultUrl;
      // 设置页保存时校验过 scheme，但 prefs 可以被旧版本/别的代码写脏，
      // 这里再验一次：非法地址回退默认值并清空口令，避免把 token 发给任意主机。
      _serverUrl = _isAcceptableUrl(savedUrl) ? savedUrl : _defaultUrl;

      String? token;
      try {
        token = await _secureStorage.read(key: _prefToken);
      } catch (e) {
        debugPrint('读取加密存储失败，回退 prefs: $e');
      }
      // 老版本把 token 明文存在 prefs，读到就迁移进加密存储并清掉明文
      final legacy = prefs.getString(_prefToken);
      if ((token == null || token.isEmpty) && legacy != null && legacy.isNotEmpty) {
        token = legacy;
        try {
          await _secureStorage.write(key: _prefToken, value: legacy);
          await prefs.remove(_prefToken);
        } catch (e) {
          debugPrint('迁移 token 到加密存储失败: $e');
        }
      }
      _token = (token != null && token.isNotEmpty) ? token : _defaultToken;
    } catch (e) {
      debugPrint('加载备份配置失败: $e');
      rethrow;
    }
  }

  Future<void> save(String url, String token) async {
    try {
      _serverUrl = url;
      _token = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUrl, url);
      try {
        if (token.isEmpty) {
          await _secureStorage.delete(key: _prefToken);
        } else {
          await _secureStorage.write(key: _prefToken, value: token);
        }
        await prefs.remove(_prefToken);
      } catch (e) {
        // 个别机型 Keystore 异常时不能让保存直接失败：降级到 prefs 并留日志
        debugPrint('token 写入加密存储失败，降级 prefs: $e');
        await prefs.setString(_prefToken, token);
      }
    } catch (e) {
      debugPrint('保存备份配置失败: $e');
      rethrow;
    }
  }

  /// 只接受 https，或指向本机回环的 http（开发调试用）。
  static bool _isAcceptableUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return false;
    if (uri.scheme == 'https') return true;
    if (uri.scheme == 'http') {
      return uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1';
    }
    return false;
  }

  /// 备份是否加密：配了口令（token）就加密，没配则保持明文（旧行为）。
  bool get isEncrypted => _token.isNotEmpty;

  /// 上传前打包：加密时只把密文塞进 `encrypted`，`__backup_name` 保持明文，
  /// 否则服务端读不到文件名，固定名覆盖就失效。
  String _packForUpload(String jsonStr, String? backupName) {
    if (!isEncrypted) {
      if (backupName == null) return jsonStr;
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      data['__backup_name'] = backupName;
      return json.encode(data);
    }
    final out = <String, dynamic>{
      'encrypted': BackupCrypto.encrypt(jsonStr, _token),
    };
    if (backupName != null) out['__backup_name'] = backupName;
    return json.encode(out);
  }

  /// 下载后解包：兼容「加密外壳」「顶层即密文」和「旧版明文」三种 body。
  String _unpack(String body) {
    final trimmed = body.trimLeft();
    if (!trimmed.startsWith('{')) return body;
    Map<String, dynamic>? map;
    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map<String, dynamic>) map = decoded;
    } catch (_) {
      return body;
    }
    if (map == null) return body;

    final encryptedField = map['encrypted'];
    if (encryptedField is String) {
      if (_token.isEmpty) {
        throw StateError('该备份已加密，请先在设置里填写备份口令（token）');
      }
      return BackupCrypto.decrypt(encryptedField, _token);
    }
    if (map['format'] == BackupCrypto.formatTag) {
      if (_token.isEmpty) {
        throw StateError('该备份已加密，请先在设置里填写备份口令（token）');
      }
      return BackupCrypto.decrypt(trimmed, _token);
    }
    return body;
  }

  String get serverUrl => _serverUrl;
  String get token => _token;

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Retry an async action with exponential backoff.
  /// Delays: 1s, 2s, 4s (2^0, 2^1, 2^2) by default.
  Future<T> _retry<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await action();
      } catch (e) {
        debugPrint('[NetworkBackup] 尝试 ${i + 1}/$maxRetries 失败: $e');
        // 4xx（401 token 错 / 404 不存在 / 400 参数错）重试也没用，白等 1+2+4 秒
        if (_isPermanentFailure(e) || i == maxRetries - 1) rethrow;
        final delay = Duration(seconds: math.pow(2, i).toInt());
        debugPrint('[NetworkBackup] ${delay.inSeconds}s后重试...');
        await Future.delayed(delay);
      }
    }
    throw Exception('超过最大重试次数');
  }

  /// 判定为「重试无意义」的错误：HTTP 4xx。
  bool _isPermanentFailure(Object e) {
    final message = e.toString();
    final match = RegExp(r'HTTP (\d{3})').firstMatch(message);
    if (match != null) {
      final code = int.tryParse(match.group(1) ?? '') ?? 0;
      return code >= 400 && code < 500;
    }
    return e is StateError; // 例如「备份已加密但没填口令」
  }

  Future<bool> ping() async {
    try {
      final resp = await _retry(() => http
          .get(Uri.parse('$_serverUrl/api/ping'))
          .timeout(const Duration(seconds: 5)));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('[NetworkBackup] ping失败: $e');
      return false;
    }
  }

  /// Upload backup data with retry and progress callback.
  /// [backupName] is optional custom filename (e.g. "梅花_20260906.json").
  Future<BackupUploadResult> upload(
    String jsonStr, {
    ProgressCallback? onProgress,
    String? backupName,
  }) async {
    try {
    return await _retry<BackupUploadResult>(() async {
      onProgress?.call(0.0);
      debugPrint('[NetworkBackup] 开始上传 (${jsonStr.length} 字节)');
      // 加密 + 注入文件名（加密时只有文件名保持明文）
      final body = _packForUpload(jsonStr, backupName);
      final resp = await http
          .post(Uri.parse('$_serverUrl/api/backup'),
              headers: _headers, body: body)
          .timeout(const Duration(seconds: 30));
      onProgress?.call(0.9);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        onProgress?.call(1.0);
        // 服务端未报告 cos_ok（旧版本）时 cosOk 为 null，提示只认服务器结果
        return BackupUploadResult(
          name: (data['name'] ?? 'ok').toString(),
          serverOk: true,
          cosOk: data['cos_ok'] as bool?,
        );
      }
      // 服务端返回 4xx/5xx：服务器侧失败（存储桶无从谈起）
      return BackupUploadResult(
        name: backupName ?? '',
        serverOk: false,
        cosOk: null,
      );
    });
    } catch (e) {
      debugPrint('上传备份失败: $e');
      // 网络异常 / 服务端无法访问：服务器侧失败
      return BackupUploadResult(name: backupName ?? '', serverOk: false, cosOk: null);
    }
  }

  /// 获取腾讯云 COS 预签名下载链接（有时限，默认 1 小时）。
  /// 返回 {ok, name, url, expire_seconds, expires_at}；失败返回 {ok:false, error}。
  Future<Map<String, dynamic>> getCosLink({String? name, int expire = 3600}) async {
    try {
      final qs = <String, String>{'expire': '$expire'};
      if (name != null) qs['name'] = name;
      final uri = Uri.parse('$_serverUrl/api/cos-link').replace(queryParameters: qs);
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        return data;
      }
      return {'ok': false, 'error': 'HTTP ${resp.statusCode}'};
    } catch (e) {
      debugPrint('[NetworkBackup] 获取 COS 链接失败: $e');
      return {'ok': false, 'error': '$e'};
    }
  }

  /// List backups with retry.
  Future<List<Map<String, dynamic>>> list() async {
    try {
    return _retry(() async {
      debugPrint('[NetworkBackup] 获取备份列表...');
      final resp = await http
          .get(Uri.parse('$_serverUrl/api/backups'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final items = List<Map<String, dynamic>>.from(data['backups'] ?? []);
        debugPrint('[NetworkBackup] 列表获取成功: ${items.length} 条');
        return items;
      }
      if (resp.statusCode == 401) throw const BackupAuthException();
      throw Exception('获取列表失败: HTTP ${resp.statusCode}');
    });
    } catch (e) {
      debugPrint('获取备份列表失败: $e');
      rethrow;
    }
  }

  /// Download a backup by name with retry and progress callback.
  Future<String> download(
    String name, {
    ProgressCallback? onProgress,
  }) async {
    try {
    return _retry(() async {
      onProgress?.call(0.0);
      debugPrint('[NetworkBackup] 开始下载: $name');
      final resp = await http
          .get(Uri.parse('$_serverUrl/api/backup/$name'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      onProgress?.call(0.9);
      if (resp.statusCode == 200) {
        onProgress?.call(1.0);
        debugPrint('[NetworkBackup] 下载成功: ${resp.body.length} 字节');
        return _unpack(resp.body);
      }
      if (resp.statusCode == 401) throw const BackupAuthException();
      throw Exception('下载失败: HTTP ${resp.statusCode}');
    });
    } catch (e) {
      debugPrint('下载备份失败: $e');
      rethrow;
    }
  }

  /// Delete a backup by name with retry.
  Future<void> delete(String name) async {
    try {
    return _retry(() async {
      debugPrint('[NetworkBackup] 删除备份: $name');
      final resp = await http
          .delete(Uri.parse('$_serverUrl/api/backup/$name'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        throw Exception('删除失败: HTTP ${resp.statusCode}');
      }
      debugPrint('[NetworkBackup] 删除成功: $name');
    });
    } catch (e) {
      debugPrint('删除备份失败: $e');
      rethrow;
    }
  }
}
