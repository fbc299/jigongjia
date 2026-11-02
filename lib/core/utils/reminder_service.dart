import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 每日记工提醒。
///
/// 用本地通知的「每天固定时间」重复，不需要常驻后台。
/// 权限被拒时不报错、只返回 false，设置页会提示用户去系统里开。
class ReminderService {
  static const String prefEnabled = 'reminder_enabled';
  static const String prefHour = 'reminder_hour';
  static const String prefMinute = 'reminder_minute';

  static const int _notifId = 1001;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (_) {
      // 拿不到时区就用 UTC，最坏情况是提醒时间偏几个小时，不影响功能
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    _inited = true;
  }

  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// 读取设置：是否开启 + 提醒时间（默认 20:00）
  static Future<({bool enabled, TimeOfDay time})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(prefEnabled) ?? false,
      time: TimeOfDay(
        hour: prefs.getInt(prefHour) ?? 20,
        minute: prefs.getInt(prefMinute) ?? 0,
      ),
    );
  }

  /// 开启并设置时间（会申请通知权限）
  static Future<bool> enable(TimeOfDay time) async {
    final ok = await requestPermission();
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefEnabled, true);
    await prefs.setInt(prefHour, time.hour);
    await prefs.setInt(prefMinute, time.minute);
    await schedule(time);
    return true;
  }

  /// 只记时间，不排程（提醒关闭时用户改时间用）
  static Future<void> saveTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefHour, time.hour);
    await prefs.setInt(prefMinute, time.minute);
  }

  static Future<void> disable() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefEnabled, false);
    await _plugin.cancel(id: _notifId);
  }

  /// 排一个每天重复的通知；用 inexact 避免「精确闹钟」权限被拦
  static Future<void> schedule(TimeOfDay time) async {
    await init();
    try {
      await _plugin.cancel(id: _notifId);
      await _plugin.zonedSchedule(
        id: _notifId,
        title: '今天记工了吗？',
        body: '花 10 秒把今天的工记上，别等月底靠回忆',
        scheduledDate: _nextInstance(time),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            '每日记工提醒',
            channelDescription: '每天固定时间提醒记工',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('排提醒失败: $e');
    }
  }

  /// 开机/启动时恢复排程（系统清过通知或换过时区时用）
  static Future<void> restoreIfEnabled() async {
    final setting = await load();
    if (setting.enabled) await schedule(setting.time);
  }

  static tz.TZDateTime _nextInstance(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }
}
