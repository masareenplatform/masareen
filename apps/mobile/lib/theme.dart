import 'package:flutter/material.dart';

class AppColors {
  static const brand = Color(0xFF0E6B5C);
  static const azure = Color(0xFF2C6E8F);
  static const accent = Color(0xFFC19A4B);
  static const canvas = Color(0xFFF0F2F5);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF65676B);
  static const line = Color(0xFFDADDE1);
  static const warm = Color(0xFFB45345);
  static const amber = Color(0xFFC19A4B);

  static const darkBg = Color(0xFF0A1210);
  static const darkSurface = Color(0xFF121C19);
  static const darkSurface2 = Color(0xFF1B2723);
  static const darkLine = Color(0xFF2E3B36);
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
    primary: dark ? const Color(0xFF76D7C4) : AppColors.brand,
    onPrimary: dark ? const Color(0xFF00382F) : Colors.white,
    secondary: dark ? const Color(0xFFE8C46A) : AppColors.accent,
    surface: surface,
    onSurface: onBg,
    surfaceTint: Colors.transparent,
  ).copyWith(
    primaryContainer: dark ? const Color(0xFF1B3A5C) : const Color(0xFFD2E3FC),
    onPrimaryContainer: dark ? const Color(0xFFA8C7FA) : const Color(0xFF062E6F),
    onSurfaceVariant: muted,
    outline: dark ? const Color(0xFF8A938F) : const Color(0xFF8A8D91),
    outlineVariant: line,
    surfaceContainerLowest:
        dark ? const Color(0xFF101412) : Colors.white,
    surfaceContainerLow:
        dark ? const Color(0xFF1A1C1E) : const Color(0xFFF7F8FA),
    surfaceContainer: dark ? const Color(0xFF202225) : Colors.white,
    surfaceContainerHigh:
        dark ? const Color(0xFF2A2D31) : const Color(0xFFF0F2F5),
    surfaceContainerHighest:
        dark ? const Color(0xFF313539) : const Color(0xFFE4E6EB),
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
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
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
  colors: [Color(0xFF0E6B5C), Color(0xFF174B43)],
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

