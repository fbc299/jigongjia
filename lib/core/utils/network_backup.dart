import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Network backup via NAS backup server (IPv6 direct, no DNS needed)
class NetworkBackupService {
  static const _prefUrl = 'backup_server_url';
  static const _prefToken = 'backup_server_token';
  static const _defaultUrl = 'https://fbc299.xyz:10443';
  static const _defaultToken = 'BNyIn22qyZbHP5S9HqF4PoaLjToKgR2KlwE5bUISuME';

  String _serverUrl = _defaultUrl;
  String _token = _defaultToken;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_prefUrl) ?? _defaultUrl;
    _token = prefs.getString(_prefToken) ?? _defaultToken;
  }

  Future<void> save(String url, String token) async {
    _serverUrl = url;
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUrl, url);
    await prefs.setString(_prefToken, token);
  }

  String get serverUrl => _serverUrl;
  String get token => _token;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  Future<bool> ping() async {
    try {
      final resp = await http
          .get(Uri.parse('$_serverUrl/api/ping'))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> upload(String jsonStr) async {
    final resp = await http
        .post(Uri.parse('$_serverUrl/api/backup'), headers: _headers, body: jsonStr)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return data['name'] ?? 'ok';
    }
    throw Exception('上传失败: ${resp.statusCode}');
  }

  Future<List<Map<String, dynamic>>> list() async {
    final resp = await http
        .get(Uri.parse('$_serverUrl/api/backups'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return List<Map<String, dynamic>>.from(data['backups'] ?? []);
    }
    throw Exception('获取列表失败');
  }

  Future<String> download(String name) async {
    final resp = await http
        .get(Uri.parse('$_serverUrl/api/backup/$name'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) return resp.body;
    throw Exception('下载失败: ${resp.statusCode}');
  }

  Future<void> delete(String name) async {
    final resp = await http
        .delete(Uri.parse('$_serverUrl/api/backup/$name'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('删除失败');
  }
}
