import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 账号（用户名 + 密码哈希）。仅存哈希，绝不存明文密码。
class Account {
  final String username;
  final String passHash;

  Account({required this.username, required this.passHash});

  Map<String, dynamic> toJson() => {'username': username, 'passHash': passHash};

  static Account fromJson(Map<String, dynamic> json) => Account(
        username: json['username'] as String,
        passHash: json['passHash'] as String,
      );
}

/// 账号系统基础设施：注册 / 登录 / 切换 / 退出。
/// 使用 SharedPreferences 持久化账号列表与当前账号（空 = legacy 模式）。
class AccountService {
  static final AccountService _instance = AccountService._();
  factory AccountService() => _instance;
  AccountService._();

  static const _prefAccountList = 'account_list';
  static const _prefCurrent = 'current_account';

  String? _currentUsername;

  /// 当前登录用户名；null 表示未登录（legacy 模式）。
  String? get currentUsername => _currentUsername;

  /// 密码哈希：sha256('username:salt:password')，salt 固定为 username，
  /// 保证同一账号每次登录哈希一致。
  static String _hash(String username, String password) {
    return sha256.convert(utf8.encode('$username:salt:$password')).toString();
  }

  /// 加载账号列表，并同步当前账号到内存缓存。
  Future<List<Account>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefAccountList);
      final list = <Account>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as List;
        list.addAll(decoded
            .map((e) => Account.fromJson(e as Map<String, dynamic>)));
      }
      final current = prefs.getString(_prefCurrent) ?? '';
      _currentUsername = current.isEmpty ? null : current;
      return list;
    } catch (e) {
      print('加载账号列表失败: $e');
      rethrow;
    }
  }

  /// 注册新账号并设为当前账号。
  Future<Account> register(String username, String password) async {
    try {
      if (username.isEmpty || username.length > 20) {
        throw Exception('用户名需为 1-20 个字符');
      }
      final valid = RegExp(r'^[\u4e00-\u9fa5A-Za-z0-9_.\-]+$');
      if (!valid.hasMatch(username)) {
        throw Exception('用户名仅允许中文、字母、数字及 _. -');
      }
      if (password.length < 6) {
        throw Exception('密码至少 6 位');
      }
      final accounts = await load();
      if (accounts.any((a) => a.username == username)) {
        throw Exception('该用户名已注册');
      }
      final account = Account(
        username: username,
        passHash: _hash(username, password),
      );
      accounts.add(account);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefAccountList,
        json.encode(accounts.map((a) => a.toJson()).toList()),
      );
      await prefs.setString(_prefCurrent, username);
      _currentUsername = username;
      return account;
    } catch (e) {
      print('注册账号失败: $e');
      rethrow;
    }
  }

  /// 登录：校验密码哈希，成功后设为当前账号。
  Future<void> login(String username, String password) async {
    try {
      final accounts = await load();
      final matches = accounts.where((a) => a.username == username).toList();
      if (matches.isEmpty) {
        throw Exception('账号不存在');
      }
      if (matches.first.passHash != _hash(username, password)) {
        throw Exception('密码错误');
      }
      await setCurrent(username);
    } catch (e) {
      print('登录失败: $e');
      rethrow;
    }
  }

  /// 快速切换账号（不做密码校验，仅限已登录过的账号）。
  Future<void> switchAccount(String username) async {
    try {
      await setCurrent(username);
    } catch (e) {
      print('切换账号失败: $e');
      rethrow;
    }
  }

  /// 退出登录，回到 legacy 模式。
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCurrent, '');
      _currentUsername = null;
    } catch (e) {
      print('退出登录失败: $e');
      rethrow;
    }
  }

  /// 设置当前账号（写 prefs + 更新内存缓存）。
  Future<void> setCurrent(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCurrent, username);
      _currentUsername = username;
    } catch (e) {
      print('设置当前账号失败: $e');
      rethrow;
    }
  }
}