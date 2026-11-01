import 'package:flutter/material.dart';

/// Obsidian theme, grounded in the supplied Room UI screenshots:
/// near-black background, gold accent, red "AI" accent, cream text.
/// Bottom navigation in the real screenshots: Talk / Chat / Crew /
/// Memory / Settings - app_scaffold.dart follows that, not the mockups.
abstract final class Obsidian {
  static const background = Color(0xFF0A0A0B);
  static const panel = Color(0xFF161311);
  static const gold = Color(0xFFC9A24B);
  static const goldBright = Color(0xFFE3B341);
  static const red = Color(0xFFE5484D);
  static const cream = Color(0xFFF2EDE4);
  static const muted = Color(0xFF9A938A);

  static ThemeData theme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: red,
        surface: panel,
        onSurface: cream,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: cream,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: red,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
