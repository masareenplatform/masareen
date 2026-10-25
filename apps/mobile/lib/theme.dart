import 'package:flutter/material.dart';

class AppColors {
  static const brand = Color(0xFF1A73E8);
  static const azure = Color(0xFF1A73E8);
  static const accent = Color(0xFF34A853);
  static const canvas = Color(0xFFF8F9FA);
  static const ink = Color(0xFF202124);
  static const muted = Color(0xFF5F6368);
  static const line = Color(0xFFDADCE0);
  static const warm = Color(0xFFEA4335);
  static const amber = Color(0xFFFBBC04);

  static const darkBg = Color(0xFF111111);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkSurface2 = Color(0xFF2D2D2D);
  static const darkLine = Color(0xFF3C4043);
}

ThemeData buildTheme({bool dark = false}) {
  final Color bg = dark ? AppColors.darkBg : AppColors.canvas;
  final Color surface = dark ? const Color(0xFF202124) : Colors.white;
  final Color onBg = dark ? const Color(0xFFE8EAED) : AppColors.ink;
  final Color muted = dark ? const Color(0xFF9AA0A6) : AppColors.muted;
  final Color line = dark ? AppColors.darkLine : AppColors.line;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: AppColors.brand,
    secondary: AppColors.accent,
    surface: surface,
    onSurface: onBg,
  ).copyWith(
    primaryContainer: dark ? const Color(0xFF1B3A5C) : const Color(0xFFD2E3FC),
    onPrimaryContainer: dark ? const Color(0xFFA8C7FA) : const Color(0xFF062E6F),
    surfaceContainerLow: dark ? const Color(0xFF1A1C1E) : const Color(0xFFF8F9FA),
    surfaceContainer: dark ? const Color(0xFF202225) : Colors.white,
    surfaceContainerHigh: dark ? const Color(0xFF2A2D31) : const Color(0xFFF1F3F4),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppColors.darkBg : Colors.white,
      foregroundColor: onBg,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 22,
        fontWeight: FontWeight.w400,
        color: onBg,
      ),
      iconTheme: IconThemeData(color: onBg),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: line.withValues(alpha: dark ? 0.3 : 1)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.darkSurface2 : const Color(0xFFF1F3F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.brand, width: 2),
      ),
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? AppColors.darkSurface2 : const Color(0xFFF1F3F4),
      labelStyle: TextStyle(color: dark ? const Color(0xFFE8EAED) : AppColors.ink, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.brand),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: dark ? AppColors.darkBg : Colors.white,
      selectedItemColor: AppColors.brand,
      unselectedItemColor: muted,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
    ),
    dividerColor: line,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: CircleBorder(),
    ),
  );
}

const LinearGradient brandGradient = LinearGradient(
  colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

BoxDecoration glassDecoration(bool dark) => BoxDecoration(
      color: (dark ? AppColors.darkSurface2 : Colors.white)
          .withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dark
            ? AppColors.darkLine.withValues(alpha: 0.6)
            : AppColors.line,
      ),
    );

