import 'package:flutter/material.dart';

import '../app.dart';
import '../core/account/account_service.dart';
import 'auth_screen.dart';

/// 启动入口：无账号 → AuthScreen，有账号 → AppShell。
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  void _onAuthed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cur = AccountService().currentUsername;
    return cur == null ? AuthScreen(onAuthed: _onAuthed) : const AppShell();
  }
}