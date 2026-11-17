import 'package:flutter/material.dart';

class AppColors {
  static const brand = Color(0xFF0E6B5C);
  static const azure = Color(0xFF2C6E8F);
  static const accent = Color(0xFFC19A4B);
  static const canvas = Color(0xFFF4F7F4);
  static const ink = Color(0xFF0D1713);
  static const muted = Color(0xFF617069);
  static const line = Color(0xFFDDE5E1);
  static const warm = Color(0xFFB45345);
  static const amber = Color(0xFFB78A3E);

  static const darkBg = Color(0xFF050807);
  static const darkSurface = Color(0xFF0E1512);
  static const darkSurface2 = Color(0xFF16201C);
  static const darkLine = Color(0xFF28362F);
  static const darkMuted = Color(0xFF92A39B);
  static const darkText = Color(0xFFF4F8F5);
  static const mint = Color(0xFF63D7B2);
  static const gold = Color(0xFFD8B56B);
}

ThemeData buildTheme({bool dark = false}) {
  final Color bg = dark ? AppColors.darkBg : AppColors.canvas;
  final Color surface = dark ? AppColors.darkSurface : Colors.white;
  final Color surfaceAlt = dark
      ? AppColors.darkSurface2
      : const Color(0xFFF7FAF8);
  final Color onBg = dark ? AppColors.darkText : AppColors.ink;
  final Color muted = dark ? AppColors.darkMuted : AppColors.muted;
  final Color line = dark ? AppColors.darkLine : AppColors.line;
  final Color primary = dark ? AppColors.mint : AppColors.brand;
  final Color onPrimary = dark ? const Color(0xFF03130E) : Colors.white;
  final Color secondary = dark ? AppColors.gold : const Color(0xFF9A742F);
  final Color outlineStrong = dark
      ? const Color(0xFF41544B)
      : const Color(0xFF9AA7A1);

  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: dark ? const Color(0xFF15382D) : const Color(0xFFD8EFE7),
    onPrimaryContainer: dark
        ? const Color(0xFFA9F2D9)
        : const Color(0xFF07372C),
    secondary: secondary,
    onSecondary: dark ? const Color(0xFF1C1302) : Colors.white,
    secondaryContainer: dark
        ? const Color(0xFF3A2D14)
        : const Color(0xFFF7E8C8),
    onSecondaryContainer: dark
        ? const Color(0xFFFFE3A7)
        : const Color(0xFF4A3507),
    tertiary: dark ? const Color(0xFF9DB8F0) : AppColors.azure,
    onTertiary: dark ? const Color(0xFF071424) : Colors.white,
    tertiaryContainer: dark ? const Color(0xFF182A44) : const Color(0xFFDDEBFA),
    onTertiaryContainer: dark
        ? const Color(0xFFC7DAFF)
        : const Color(0xFF102A43),
    error: dark ? const Color(0xFFFF8F80) : AppColors.warm,
    onError: dark ? const Color(0xFF2B0602) : Colors.white,
    errorContainer: dark ? const Color(0xFF3E1712) : const Color(0xFFFBE4E1),
    onErrorContainer: dark ? const Color(0xFFFFDAD4) : const Color(0xFF5D1710),
    surface: surface,
    onSurface: onBg,
    onSurfaceVariant: muted,
    outline: outlineStrong,
    outlineVariant: line,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: dark ? const Color(0xFFF1F6F3) : const Color(0xFF0B110F),
    onInverseSurface: dark ? const Color(0xFF0B110F) : const Color(0xFFF1F6F3),
    inversePrimary: dark ? AppColors.brand : AppColors.mint,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: dark ? const Color(0xFF030504) : Colors.white,
    surfaceContainerLow: dark
        ? const Color(0xFF0A100D)
        : const Color(0xFFF9FBF9),
    surfaceContainer: surface,
    surfaceContainerHigh: surfaceAlt,
    surfaceContainerHighest: dark
        ? const Color(0xFF1D2924)
        : const Color(0xFFEAF0EC),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    splashColor: primary.withValues(alpha: dark ? 0.10 : 0.08),
    highlightColor: primary.withValues(alpha: dark ? 0.06 : 0.04),
    dividerColor: line,
    visualDensity: VisualDensity.standard,
  );

  final textTheme = base.textTheme.apply(
    bodyColor: onBg,
    displayColor: onBg,
    fontFamily: 'Cairo',
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.18,
        letterSpacing: -0.7,
        color: onBg,
      ),
      displayMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.5,
        color: onBg,
      ),
      headlineLarge: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: -0.3,
        color: onBg,
      ),
      headlineMedium: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: onBg,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: onBg,
      ),
      titleLarge: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: onBg,
      ),
      titleMedium: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: onBg,
      ),
      titleSmall: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: onBg,
      ),
      bodyLarge: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w400,
        height: 1.65,
        color: onBg,
      ),
      bodyMedium: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.7,
        color: onBg,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: onBg,
      ),
      labelMedium: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: muted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: onBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: onBg,
      ),
      iconTheme: IconThemeData(color: onBg, size: 22),
      actionsIconTheme: IconThemeData(color: onBg, size: 22),
    ),
    iconTheme: IconThemeData(color: onBg, size: 24),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(
        color: muted.withValues(alpha: 0.85),
        fontSize: 13,
        fontFamily: 'Cairo',
      ),
      labelStyle: TextStyle(color: muted, fontSize: 13, fontFamily: 'Cairo'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.4),
      ),
      prefixIconColor: muted,
      suffixIconColor: muted,
      errorStyle: TextStyle(color: scheme.error, fontSize: 11.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        disabledBackgroundColor: primary.withValues(alpha: 0.34),
        disabledForegroundColor: onPrimary.withValues(alpha: 0.65),
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onBg,
        backgroundColor: Colors.transparent,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: muted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 10),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: 0.12),
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primary : muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? primary : muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surface,
      selectedColor: primary,
      disabledColor: surfaceAlt,
      side: BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        color: onBg,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: 'Cairo',
        color: onPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? AppColors.darkSurface2 : AppColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: 'Cairo',
        color: dark ? AppColors.darkText : Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: primary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: line),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onBg,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13.5,
        height: 1.7,
        color: onBg,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      modalBarrierColor: Colors.black.withValues(alpha: 0.72),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      dragHandleColor: line,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: line,
      circularTrackColor: line,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? onPrimary : muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : surfaceAlt,
      ),
      trackOutlineColor: WidgetStatePropertyAll(line),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(onPrimary),
      side: BorderSide(color: line, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : muted,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: onBg,
      textColor: onBg,
      subtitleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        color: muted,
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onBg,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 0,
      shape: const CircleBorder(),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface2 : AppColors.ink,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: line),
      ),
      textStyle: TextStyle(
        fontFamily: 'Cairo',
        color: dark ? AppColors.darkText : Colors.white,
        fontSize: 11,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(7),
      radius: const Radius.circular(99),
      thumbColor: WidgetStatePropertyAll(
        dark ? const Color(0xFF31443B) : const Color(0xFFC6D2CC),
      ),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

const LinearGradient brandGradient = LinearGradient(
  colors: [Color(0xFF0E6B5C), Color(0xFF0A3F36)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient goldGradient = LinearGradient(
  colors: [Color(0xFFD8B56B), Color(0xFF9A742F)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

BoxDecoration glassDecoration(bool dark) => BoxDecoration(
  color: (dark ? AppColors.darkSurface2 : Colors.white).withValues(
    alpha: dark ? 0.92 : 0.94,
  ),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(
    color: dark ? AppColors.darkLine.withValues(alpha: 0.9) : AppColors.line,
  ),
);
