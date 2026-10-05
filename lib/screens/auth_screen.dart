import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/account/account_service.dart';
import '../providers/project_provider.dart';
import '../providers/work_provider.dart';
import '../providers/borrow_provider.dart';
import '../providers/settlement_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/note_provider.dart';
import '../providers/photo_evidence_provider.dart';

/// 重载全部 7 个 provider 的内存缓存，使其指向当前账号（或共享库）的数据库。
Future<void> reloadAllProviders(BuildContext context) async {
  await context.read<WorkProvider>().reloadAll();
  await context.read<BorrowProvider>().reloadAll();
  await context.read<SettlementProvider>().reloadAll();
  await context.read<ExpenseProvider>().reloadAll();
  await context.read<NoteProvider>().reloadAll();
  await context.read<PhotoEvidenceProvider>().reloadAll();
  await context.read<ProjectProvider>().reloadAll();
}

/// 沉浸式登录/注册页。
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthed});

  /// 登录/注册/共享模式任一成功后的回调（由 AppEntry 传入，切主界面）。
  final VoidCallback onAuthed;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  String _friendlyError(Object e) {
    final s = '$e';
    const prefix = 'Exception: ';
    return s.startsWith(prefix) ? s.substring(prefix.length) : s;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text;
    if (u.isEmpty) {
      setState(() => _error = '请输入用户名');
      return;
    }
    if (p.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    if (!_isLogin && _confirmCtrl.text != p) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        await AccountService().login(u, p);
      } else {
        await AccountService().register(u, p);
      }
      await reloadAllProviders(context);
      if (!mounted) return;
      widget.onAuthed();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  Future<void> _useSharedMode() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AccountService().logout();
      await reloadAllProviders(context);
      if (!mounted) return;
      widget.onAuthed();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  InputDecoration _dec(String label, String hint, {Widget? suffix}) {
    final grey300 = Colors.grey.shade300;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: grey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: grey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 72),
              _buildLogo(),
              const SizedBox(height: 16),
              const Text(
                '格格记工',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '工人记工记账助手',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              _buildSegmentedTab(),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameCtrl,
                decoration: _dec('用户名', '中文/字母/数字'),
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: _dec(
                  '密码',
                  _isLogin ? '请输入密码' : '至少 6 位',
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onChanged: (_) => _clearError(),
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: _dec('确认密码', '再次输入密码'),
                  onChanged: (_) => _clearError(),
                ),
              ],
              const SizedBox(height: 12),
              _buildSubmitButton(),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: _useSharedMode,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text('先以共享模式使用 →', style: TextStyle(fontSize: 13)),
                ),
              ),
              Text(
                '无需密码，数据存本机共享库',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green, Colors.green.shade700],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.handyman, size: 48, color: Colors.white),
      ),
    );
  }

  Widget _buildSegmentedTab() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildTab(true),
          _buildTab(false),
        ],
      ),
    );
  }

  Widget _buildTab(bool isLogin) {
    final selected = _isLogin == isLogin;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: selected ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextButton(
          onPressed: () {
            if (_isLogin == isLogin) return;
            setState(() {
              _isLogin = isLogin;
              _error = null;
            });
          },
          style: TextButton.styleFrom(
            foregroundColor:
                selected ? Colors.white : Colors.grey.shade600,
            padding: EdgeInsets.zero,
          ),
          child: Text(
            isLogin ? '登录' : '注册',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _submit,
        child: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isLogin ? '登 录' : '注 册',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}