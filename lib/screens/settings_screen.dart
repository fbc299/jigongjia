import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings/data_backup_section.dart';
import 'package:package_info_plus/package_info_plus.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _buildSectionHeader(context, '项目管理'),
          const ProjectManagementSection(),
          const Divider(height: 1),
          _buildSectionHeader(context, '数据管理'),
          const DataManagementSection(),
          const Divider(height: 1),
          _buildSectionHeader(context, '腾讯云COS备份'),
          const NetworkBackupSection(),
          const Divider(height: 1),
          _buildSectionHeader(context, '关于'),
          const _AboutSection(),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

// ===================== About =====================

class _AboutSection extends StatefulWidget {
  const _AboutSection();
  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '…';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = 'v${info.version}(${info.buildNumber})');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('版本'),
          subtitle: Text(_version),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text('开发者'),
          subtitle: Text('格格记工'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text('应用介绍'),
          subtitle: Text('格格记工 - 工人记工记账助手，轻松管理工地考勤、工资、借支和结算'),
        ),
      ],
    );
  }
}
