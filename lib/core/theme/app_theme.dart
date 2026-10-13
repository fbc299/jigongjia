import 'package:flutter/material.dart';

/// Apple HIG · iOS 系统色板
/// token 对应 design/ui-v6-apple.html（系统蓝 #0A84FF / 灰白 #F5F5F7）
/// 屏幕里引用的 token 名保持不变（brick=系统蓝、warnAmber=系统橙、
/// okGreen=系统绿、clay=系统紫、dangerRed=系统红），仅数值换成 iOS 色板。
class AppTheme {
  AppTheme._();

  // ── iOS token ──
  static const Color paper = Color(0xFFF5F5F7); // iOS 灰白
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE5E5EA); // 分隔灰
  static const Color brick = Color(0xFF0A84FF); // 系统蓝 accent
  static const Color brickInk = Color(0xFF0066CC); // 深蓝（按压/强调）
  static const Color brickSoft = Color(0xFFE8F2FE); // 蓝软底
  static const Color ink = Color(0xFF1D1D1F); // 近黑（正文/数字）
  static const Color ink2 = Color(0xFF86868B); // 次级灰
  static const Color ink3 = Color(0xFFC7C7CC); // 弱灰
  static const Color okGreen = Color(0xFF34C759); // 系统绿
  static const Color warnAmber = Color(0xFFFF9500); // 系统橙
  static const Color dangerRed = Color(0xFFFF3B30); // 系统红
  static const Color clay = Color(0xFFAF52DE); // 系统紫（包工·量 / 住宿）

  static ColorScheme _scheme(Brightness b) {
    final isLight = b == Brightness.light;
    return ColorScheme(
      brightness: b,
      primary: isLight ? brick : brickInk,
      onPrimary: Colors.white,
      primaryContainer: isLight ? brickSoft : const Color(0xFF0A2A4A),
      onPrimaryContainer: isLight ? brickInk : const Color(0xFFB8D4FF),
      secondary: isLight ? warnAmber : const Color(0xFFFFB050),
      onSecondary: Colors.white,
      secondaryContainer: isLight ? const Color(0xFFFFF1D6) : const Color(0xFF4A3A1E),
      onSecondaryContainer:
          isLight ? const Color(0xFF6B4E1E) : const Color(0xFFE8CFA0),
      surface: isLight ? paper : const Color(0xFF1C1C1E),
      onSurface: isLight ? ink : const Color(0xFFF2F2F7),
      surfaceContainerHighest: isLight ? cardWhite : const Color(0xFF2C2C2E),
      onSurfaceVariant: isLight ? ink2 : const Color(0xFF98989E),
      error: isLight ? dangerRed : const Color(0xFFFF453A),
      onError: Colors.white,
      outline: isLight ? cardBorder : const Color(0xFF3A3A3C),
      outlineVariant: isLight ? cardBorder : const Color(0xFF2C2C2E),
    );
  }

  static ThemeData build(Brightness b) {
    final cs = _scheme(b);
    final isLight = b == Brightness.light;
    final base = isLight ? ThemeData.light() : ThemeData.dark();
    final accent = cs.primary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        // iOS Large Title 观感：标题左对齐、大字号、不加高
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        titleTextStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? cardWhite : const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? const Color(0xFFF5F5F7) : const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: ink2, fontSize: 13),
        hintStyle: const TextStyle(color: ink3, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: accent,
          side: BorderSide(color: cs.outlineVariant, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme:
          TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: accent)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // iOS Tab bar 观感：近白毛玻璃底、顶部 0.5px 发丝线、系统蓝选中
        backgroundColor: isLight ? const Color(0xFFF9F9FB) : const Color(0xFF1C1C1E),
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? accent : ink2,
              size: 24,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 10,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? accent : ink2,
            )),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? ink : const Color(0xFF2C2C2E),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? cardWhite : const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? cardWhite : const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(),
        iconColor: ink2,
        minVerticalPadding: 4,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? okGreen : Colors.grey[300]),
        thumbColor: WidgetStateProperty.all(Colors.white),
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
        titleLarge: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleMedium: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        bodyLarge: const TextStyle(fontSize: 16, letterSpacing: -0.2),
        bodyMedium: const TextStyle(fontSize: 15, letterSpacing: -0.2),
        labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        displaySmall: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          color: ink,
        ),
      ),
    );
  }

  static ThemeData get lightTheme => build(Brightness.light);
  static ThemeData get darkTheme => build(Brightness.dark);
}
