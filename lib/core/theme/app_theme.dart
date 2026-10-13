import 'package:flutter/material.dart';

/// 暖色友好 · 米白 + 砖红
/// token 对应 design/ui-v2.html（Hallmark warm-terracotta）
class AppTheme {
  AppTheme._();

  // ── 暖色 token ──
  static const Color paper = Color(0xFFF8F6F2); // 米白
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFEAE4DA);
  static const Color brick = Color(0xFFB84A33); // 砖红 accent
  static const Color brickInk = Color(0xFF6E2C1E); // 深砖红
  static const Color brickSoft = Color(0xFFF0E2DA); // 砖红软底
  static const Color ink = Color(0xFF3A342D); // 暖墨（正文/数字）
  static const Color ink2 = Color(0xFF7A7268); // 次级
  static const Color ink3 = Color(0xFFA79E90); // 弱
  static const Color okGreen = Color(0xFF4E9A6A);
  static const Color warnAmber = Color(0xFFD98324);
  static const Color dangerRed = Color(0xFFC0392B);
  static const Color clay = Color(0xFF8C6A4F); // 陶土（包工·量 / 住宿）

  static ColorScheme _scheme(Brightness b) {
    final isLight = b == Brightness.light;
    return ColorScheme(
      brightness: b,
      primary: isLight ? brick : brickInk,
      onPrimary: Colors.white,
      primaryContainer: isLight ? brickSoft : const Color(0xFF5A2A1E),
      onPrimaryContainer: isLight ? brickInk : const Color(0xFFE8C7BC),
      secondary: isLight ? warnAmber : const Color(0xFFD9A441),
      onSecondary: Colors.white,
      secondaryContainer: isLight ? const Color(0xFFF3E4CE) : const Color(0xFF4A3A1E),
      onSecondaryContainer:
          isLight ? const Color(0xFF6B4E1E) : const Color(0xFFE8CFA0),
      surface: isLight ? paper : const Color(0xFF1D1B18),
      onSurface: isLight ? ink : const Color(0xFFEDE7DC),
      surfaceContainerHighest: isLight ? cardWhite : const Color(0xFF2A2723),
      onSurfaceVariant: isLight ? ink2 : const Color(0xFFB4ACA0),
      error: isLight ? dangerRed : const Color(0xFFE07A6A),
      onError: Colors.white,
      outline: isLight ? cardBorder : const Color(0xFF3A352F),
      outlineVariant: isLight ? cardBorder : const Color(0xFF2E2B26),
    );
  }

  static ThemeData build(Brightness b) {
    final cs = _scheme(b);
    final isLight = b == Brightness.light;
    final base = isLight ? ThemeData.light() : ThemeData.dark();
    final accent = cs.primary; // 关键数字/按钮砖红

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isLight ? brickInk : cs.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? cardWhite : const Color(0xFF2A2723),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? const Color(0xFFF1EEE8) : const Color(0xFF2A2723),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: accent,
          side: BorderSide(color: accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme:
          TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: accent)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(100))), // 胶囊
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? cardWhite : cs.surface,
        indicatorColor: isLight ? brickSoft : const Color(0xFF3A2A20),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? accent : ink3,
              size: 22,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? accent : ink3,
            )),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? ink : const Color(0xFF2A2723),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? cardWhite : const Color(0xFF2A2723),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? cardWhite : const Color(0xFF2A2723),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      switchTheme: SwitchThemeData(
        activeColor: accent,
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.white),
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
        titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        titleMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(fontSize: 16),
        bodyMedium: const TextStyle(fontSize: 15),
        labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        displaySmall: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: brickInk,
        ),
      ),
    );
  }

  static ThemeData get lightTheme => build(Brightness.light);
  static ThemeData get darkTheme => build(Brightness.dark);
}
