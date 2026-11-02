import 'package:flutter/material.dart';

import '../../core/utils/reminder_service.dart';

/// 每日记工提醒：开关 + 提醒时间
class ReminderSection extends StatefulWidget {
  const ReminderSection({super.key});

  @override
  State<ReminderSection> createState() => _ReminderSectionState();
}

class _ReminderSectionState extends State<ReminderSection> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ReminderService.load();
    if (!mounted) return;
    setState(() {
      _enabled = s.enabled;
      _time = s.time;
      _loading = false;
    });
  }

  String get _timeText =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _toggle(bool on) async {
    if (!on) {
      await ReminderService.disable();
      if (mounted) setState(() => _enabled = false);
      return;
    }
    final ok = await ReminderService.enable(_time);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有通知权限，请到系统设置里允许「格格记工」发通知')),
      );
      setState(() => _enabled = false);
      return;
    }
    setState(() => _enabled = true);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
    if (_enabled) {
      await ReminderService.enable(picked);
    } else {
      // 提醒没开时只记住时间，等打开时生效
      await ReminderService.saveTime(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.alarm),
          title: const Text('每日记工提醒'),
          subtitle: Text(_enabled ? '每天 $_timeText 提醒你记工' : '关闭中，打开后每天定时提醒'),
          value: _enabled,
          onChanged: _toggle,
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('提醒时间'),
          subtitle: Text(_timeText),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickTime,
        ),
      ],
    );
  }
}
