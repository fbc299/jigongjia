import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';

import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/providers/expense_provider.dart';
import 'package:jigongjia/providers/note_provider.dart';
import 'package:jigongjia/screens/work_entry_screen.dart';
import 'package:jigongjia/screens/home_screen.dart';
import 'package:jigongjia/screens/stats_screen.dart';
import 'package:jigongjia/screens/settings_screen.dart';
import 'package:jigongjia/core/utils/network_backup.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().loadProjects();
      _autoBackup();
    });
  }

  Future<void> _autoBackup() async {
    try {
      final service = NetworkBackupService();
      await service.load();
      final ok = await service.ping();
      if (!ok) return;
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      // Delete old backups first (keep only latest)
      try {
        final backups = await service.list();
        for (final b in backups) {
          await service.delete(b['name']);
        }
      } catch (_) {}
      if (!mounted) return;
      final ctx = context;
      final data = json.encode({
        'version': 1, 'exportedAt': DateTime.now().toIso8601String(),
        'projects': ctx.read<ProjectProvider>().projects.map((p) => p.toMap()).toList(),
        'workRecords': ctx.read<WorkProvider>().records.map((r) => r.toMap()).toList(),
        'borrowRecords': ctx.read<BorrowProvider>().records.map((r) => r.toMap()).toList(),
        'settlements': ctx.read<SettlementProvider>().settlements.map((s) => s.toMap()).toList(),
        'expenses': ctx.read<ExpenseProvider>().expenses.map((e) => e.toMap()).toList(),
        'notes': ctx.read<NoteProvider>().notes.map((n) => n.toMap()).toList(),
      });
      await service.upload(data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectProvider>().activeProjects;

    // Auto-select first project if none selected
    if (_selectedProjectId == null && projects.isNotEmpty) {
      _selectedProjectId = projects.first.id;
    }

    final selectedProject = projects.where((p) => p.id == _selectedProjectId).isEmpty
        ? (projects.isNotEmpty ? projects.first : null)
        : projects.firstWhere((p) => p.id == _selectedProjectId);

    // Build screens dynamically
    final screens = <Widget>[
      // Tab 0: Calendar - always shown
      if (selectedProject != null)
        WorkEntryScreen(
          projectId: selectedProject.id,
          project: selectedProject,
        )
      else
        _buildNoProjectHint(),
      // Tab 1: Project list
      const HomeScreen(showFab: true),
      // Tab 2: Stats
      const StatsScreen(),
      // Tab 3: Tools/Settings
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '记工',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open_outlined),
            selectedIcon: Icon(Icons.folder_open),
            label: '项目',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: '工具',
          ),
        ],
      ),
    );
  }

  Widget _buildNoProjectHint() {
    return Scaffold(
      appBar: AppBar(title: const Text('记工')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('还没有项目', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('请先在「项目」页创建一个项目', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}
