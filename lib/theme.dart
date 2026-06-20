import 'package:flutter/material.dart';

/// A quiet, minimalist monochrome theme with light + dark variants.
///
/// Screens use the context helpers ([ink], [onInk], [surface]) so colors
/// follow the active brightness. [muted] is a neutral grey that reads well on
/// both, so it stays constant.
class AppTheme {
  // Light palette
  static const _lightInk = Color(0xFF111111);
  static const _lightSurface = Color(0xFFF6F6F4);
  static const _lightBg = Colors.white;
  static const _lightDivider = Color(0xFFEDEDED);

  // Dark palette
  static const _darkInk = Color(0xFFF2F2F2);
  static const _darkSurface = Color(0xFF1C1C1E);
  static const _darkBg = Color(0xFF0B0B0C);
  static const _darkDivider = Color(0xFF242426);

  /// Secondary text/icon grey — legible on both light and dark surfaces.
  static const Color muted = Color(0xFF8A8A8E);

  /// Primary text/icon colour for the active theme.
  static Color ink(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? _darkInk : _lightInk;

  /// Foreground that sits on top of [ink] (e.g. FAB icon, filled buttons).
  static Color onInk(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFF111111)
          : Colors.white;

  /// Card / elevated panel background for the active theme.
  static Color surface(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? _darkSurface : _lightSurface;

  static ThemeData get light => _build(
        brightness: Brightness.light,
        ink: _lightInk,
        onInk: Colors.white,
        bg: _lightBg,
        surface: _lightSurface,
        divider: _lightDivider,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        ink: _darkInk,
        onInk: const Color(0xFF111111),
        bg: _darkBg,
        surface: _darkSurface,
        divider: _darkDivider,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color ink,
    required Color onInk,
    required Color bg,
    required Color surface,
    required Color divider,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        brightness: brightness,
        surface: bg,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: bg,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        surfaceTintColor: bg,
        indicatorColor: surface,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? ink : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? ink : muted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: onInk,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
