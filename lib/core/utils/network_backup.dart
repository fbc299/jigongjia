import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Progress callback: reports 0.0 ~ 1.0 during upload/download operations.
typedef ProgressCallback = void Function(double progress);

/// Network backup via NAS backup server (IPv6 direct, no DNS needed)
/// Enhanced with retry (exponential backoff) and progress callbacks.
class NetworkBackupService {
  static const _prefUrl = 'backup_server_url';
  static const _prefToken = 'backup_server_token';
  static const _defaultUrl = 'https://fbc299.xyz:10443';
  static const _defaultToken = 'BNyIn22qyZbHP5S9HqF4PoaLjToKgR2KlwE5bUISuME';

  String _serverUrl = _defaultUrl;
  String _token = _defaultToken;
  SharedPreferences? _prefs;

  /// Initialize and cache SharedPreferences instance.
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = prefs.getString(_prefUrl) ?? _defaultUrl;
      _token = prefs.getString(_prefToken) ?? _defaultToken;
    } catch (e) {
      print('加载备份配置失败: $e');
      rethrow;
    }
  }

  Future<void> save(String url, String token) async {
    try {
      _serverUrl = url;
      _token = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUrl, url);
      await prefs.setString(_prefToken, token);
    } catch (e) {
      print('保存备份配置失败: $e');
      rethrow;
    }
  }

  String get serverUrl => _serverUrl;
  String get token => _token;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

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
        if (i == maxRetries - 1) rethrow;
        final delay = Duration(seconds: math.pow(2, i).toInt());
        debugPrint('[NetworkBackup] ${delay.inSeconds}s后重试...');
        await Future.delayed(delay);
      }
    }
    throw Exception('超过最大重试次数');
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
  Future<String> upload(
    String jsonStr, {
    ProgressCallback? onProgress,
    String? backupName,
  }) async {
    try {
    return _retry(() async {
      onProgress?.call(0.0);
      debugPrint('[NetworkBackup] 开始上传 (${jsonStr.length} 字节)');
      // Inject custom filename into JSON body
      String body = jsonStr;
      if (backupName != null) {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        data['__backup_name'] = backupName;
        body = json.encode(data);
      }
      final resp = await http
          .post(Uri.parse('$_serverUrl/api/backup'),
              headers: _headers, body: body)
          .timeout(const Duration(seconds: 30));
      onProgress?.call(0.9);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        onProgress?.call(1.0);
        debugPrint('[NetworkBackup] 上传成功: ${data['name']}');
        return data['name'] ?? 'ok';
      }
      throw Exception('上传失败: HTTP ${resp.statusCode} - ${resp.body}');
    });
    } catch (e) {
      print('上传备份失败: $e');
      rethrow;
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
      throw Exception('获取列表失败: HTTP ${resp.statusCode}');
    });
    } catch (e) {
      print('获取备份列表失败: $e');
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
        return resp.body;
      }
      throw Exception('下载失败: HTTP ${resp.statusCode}');
    });
    } catch (e) {
      print('下载备份失败: $e');
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
      print('删除备份失败: $e');
      rethrow;
    }
  }
}
