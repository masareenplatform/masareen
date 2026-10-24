import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MASAREEN light, Material Design 3 theme.
///
/// The product surfaces are LIGHT (cool white / ivory canvas), brand navy/blue
/// and green are used as accents only, and every text color is chosen for AA+
/// contrast on the light background. This keeps the app compliant with the
/// Android Material 3 standard and readable in bright environments.
class MasarenTheme {
  // ── Brand palette (logo-derived: navy → blue → green) ──
  static const Color navyDark  = Color(0xFF050910); // deepest ink (kept for legacy refs)
  static const Color navy      = Color(0xFF0D1425); // brand navy
  static const Color navyLight = Color(0xFF0077C8); // azure
  static const Color gold      = Color(0xFF0250A3); // brand blue (primary)
  static const Color ivory     = Color(0xFFF0F4FF); // cool white canvas
  static const Color green     = Color(0xFF2A9D45); // brand green
  static const Color greenLight= Color(0xFF3EBD5C); // mint
  static const Color slate    = Color(0xFF3D4F6B); // muted ink
  static const Color slateLight= Color(0xFF7A8FAD); // soft muted (use sparingly)
  static const Color accent   = Color(0xFFE25555); // alert / like accent

  // ── Light design tokens (Material 3) ──
  static const Color brand   = Color(0xFF0250A3); // primary
  static const Color brandDeep = Color(0xFF0D1425); // ink / on-surface
  static const Color azure   = Color(0xFF0077C8);
  static const Color canvas  = Color(0xFFF0F4FF); // scaffold background
  static const Color surface = Color(0xFFFFFFFF); // card / sheet
  static const Color ink     = Color(0xFF0D1425); // high-emphasis text
  static const Color muted   = Color(0xFF3D4F6B); // medium-emphasis text
  static const Color line    = Color(0xFFDCE6F5); // hairline borders
  static const Color like    = Color(0xFFE25555); // like / favorite

  /// Light signature background: a soft white → cool-white vertical wash.
  /// (No dark navy, keeps the whole app bright per the Android design standard.)
  static BoxDecoration get background => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), canvas],
    ),
  );

  /// Light card surface (replaces the old dark "glass" used on navy).
  static BoxDecoration get glass => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: line),
    boxShadow: [
      BoxShadow(color: Color(0x1A0D1425), blurRadius: 16, offset: const Offset(0, 6)),
    ],
  );

  static BoxDecoration get glassGold => BoxDecoration(
    color: const Color(0xFFEAF2FC),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: brand.withOpacity(0.35)),
    boxShadow: [BoxShadow(color: brand.withOpacity(0.12), blurRadius: 16)],
  );

  /// Accent (green) surface for highlights / success.
  static BoxDecoration get glassGreen => BoxDecoration(
    color: const Color(0xFFE7F6EC),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: green.withOpacity(0.4)),
    boxShadow: [BoxShadow(color: green.withOpacity(0.12), blurRadius: 16)],
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: brand,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCE8F7),
      onPrimaryContainer: brandDeep,
      secondary: green,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: ink,
      surfaceContainerHighest: canvas,
      error: like,
      onError: Colors.white,
      outline: line,
    ),
    scaffoldBackgroundColor: canvas,
    textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme)
        .apply(bodyColor: ink, displayColor: ink),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme)
          .titleLarge
          ?.copyWith(color: ink, fontWeight: FontWeight.bold, fontSize: 20),
      iconTheme: const IconThemeData(color: ink),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brand,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 2,
      shadowColor: const Color(0x1A0D1425),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: brand, width: 1.5),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: brand,
      unselectedItemColor: muted,
      elevation: 4,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: muted,
      textColor: ink,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFEAF2FC),
      labelStyle: const TextStyle(color: brand, fontWeight: FontWeight.w600),
      side: BorderSide(color: brand.withOpacity(0.25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: brand),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF4DA3FF),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF0A2A4A),
      onPrimaryContainer: const Color(0xFFCFE4FF),
      secondary: greenLight,
      onSecondary: navyDark,
      surface: const Color(0xFF0E1524),
      onSurface: const Color(0xFFEAF1FF),
      surfaceContainerHighest: const Color(0xFF162032),
      error: const Color(0xFFFF6B6B),
      onError: Colors.white,
      outline: const Color(0xFF2A3650),
    ),
    scaffoldBackgroundColor: const Color(0xFF0A0F1C),
    textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: const Color(0xFFEAF1FF), displayColor: const Color(0xFFEAF1FF)),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0E1524),
      foregroundColor: Color(0xFFEAF1FF),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF121A2B),
      elevation: 2,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF162032),
      hintStyle: const TextStyle(color: Color(0xFF8AA0C2)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A3650))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A3650))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4DA3FF), width: 1.5)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF0E1524),
      selectedItemColor: Color(0xFF4DA3FF),
      unselectedItemColor: Color(0xFF8AA0C2),
      elevation: 4,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF16223A),
      labelStyle: const TextStyle(color: Color(0xFFCFE4FF), fontWeight: FontWeight.w600),
      side: const BorderSide(color: Color(0xFF2A3650)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );

  static Color canvasOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0F1C) : canvas;
  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF121A2B) : surface;
  static Color inkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFFEAF1FF) : ink;
  static Color mutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8AA0C2) : muted;
  static Color lineOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A3650) : line;

  static BoxDecoration backgroundOf(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? const BoxDecoration(color: Color(0xFF0A0F1C))
      : background;
}



