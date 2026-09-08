import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global privacy mode — hides all wage/amount displays when enabled.
class PrivacyService {
  static final PrivacyService _instance = PrivacyService._();
  factory PrivacyService() => _instance;
  PrivacyService._();

  static const _prefKey = 'privacy_mode';
  final ValueNotifier<bool> isHidden = ValueNotifier(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isHidden.value = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> toggle() async {
    isHidden.value = !isHidden.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isHidden.value);
  }

  /// Format amount — returns '****' if hidden, otherwise formatted number.
  static String format(double amount, {bool hide = false}) {
    if (hide) return '****';
    if (amount == amount.roundToDouble()) {
      return '¥${amount.toInt()}';
    }
    return '¥${amount.toStringAsFixed(2)}';
  }
}
