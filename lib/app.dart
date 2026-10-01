import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/providers/expense_provider.dart';
import 'package:jigongjia/providers/note_provider.dart';
import 'package:jigongjia/providers/photo_evidence_provider.dart';
import 'package:jigongjia/screens/work_entry_screen.dart';
import 'package:jigongjia/screens/home_screen.dart';
import 'package:jigongjia/screens/stats_screen.dart';
import 'package:jigongjia/screens/settings_screen.dart';
import 'package:jigongjia/core/utils/network_backup.dart';
import 'package:jigongjia/core/utils/privacy_service.dart';

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
      PrivacyService().load();
      _promptBackup();
    });
  }

  /// Prompt user to backup instead of auto-backing up silently.
  Future<void> _promptBackup() async {
    try {
      final service = NetworkBackupService();
      await service.load();
      final ok = await service.ping();
      if (!ok || !mounted) return;

      // Check if already backed up today
      final prefs = await SharedPreferences.getInstance();
      final lastBackup = prefs.getString('last_backup_date') ?? '';
      final today = DateFormat('yyyyMMdd').format(DateTime.now());
      if (lastBackup == today) return;

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('数据备份'),
          content: const Text('检测到备份服务器可用，是否备份当前数据？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('跳过'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('备份'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;

      // Build backup data
      final ctx = context;
      final projects = ctx.read<ProjectProvider>().projects;
      final data = json.encode({
        'version': 1, 'exportedAt': DateTime.now().toIso8601String(),
        'projects': projects.map((p) => p.toMap()).toList(),
        'workRecords': ctx.read<WorkProvider>().records.map((r) => r.toMap()).toList(),
        'borrowRecords': ctx.read<BorrowProvider>().records.map((r) => r.toMap()).toList(),
        'settlements': ctx.read<SettlementProvider>().settlements.map((s) => s.toMap()).toList(),
        'expenses': ctx.read<ExpenseProvider>().expenses.map((e) => e.toMap()).toList(),
        'notes': ctx.read<NoteProvider>().notes.map((n) => n.toMap()).toList(),
        'photoEvidence': ctx.read<PhotoEvidenceProvider>().photos.map((p) => p.toMap()).toList(),
      });
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      final projectNames = projects.map((p) => p.name).join('+');
      final backupName = '${projectNames}_$date.json';
      await service.upload(data, backupName: backupName);
      await prefs.setString('last_backup_date', today);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('备份成功')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectProvider>().activeProjects;

    // Auto-select first project if none selected
    if (_selectedProjectId == null && projects.isNotEmpty) {
      _selectedProjectId = projects.first.id;
    }

    final selectedProject = projects.where((p) => p.id == _selectedProjectId).firstOrNull
        ?? (projects.isNotEmpty ? projects.first : null);

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
