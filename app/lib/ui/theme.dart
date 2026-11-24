import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData focusTheme() {
  final scheme = ColorScheme(
    brightness: Dissolve.light ? Brightness.light : Brightness.dark,
    surface: Dissolve.bg,
    onSurface: Dissolve.fg,
    surfaceContainerLowest: Dissolve.bg,
    surfaceContainerLow: Dissolve.surface,
    surfaceContainer: Dissolve.surface,
    surfaceContainerHigh: Dissolve.raised,
    surfaceContainerHighest: Dissolve.raised,
    primary: Dissolve.fg,
    onPrimary: Dissolve.ink,
    primaryContainer: Dissolve.raised,
    onPrimaryContainer: Dissolve.fg,
    secondary: Dissolve.accent,
    onError: Dissolve.ink,
    onSecondary: Dissolve.ink,
    secondaryContainer: Dissolve.raised,
    onSecondaryContainer: Dissolve.fg,
    tertiary: Dissolve.success,
    error: Dissolve.danger,
    errorContainer: Dissolve.danger.withValues(alpha: .15),
    onErrorContainer: Dissolve.danger,
    outline: Dissolve.edge,
    outlineVariant: Dissolve.border,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme.apply(
    bodyColor: Dissolve.fg,
    displayColor: Dissolve.fg,
  );
  const pill = StadiumBorder();
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Dissolve.bg,
    disabledColor: Dissolve.muted,
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -.4),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -.2),
      titleSmall: text.titleSmall?.copyWith(color: Dissolve.muted, letterSpacing: .2),
      bodySmall: text.bodySmall?.copyWith(color: Dissolve.muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Dissolve.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Dissolve.fg,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
      ),
    ),
    cardTheme: CardThemeData(
      color: Dissolve.surface.withValues(alpha: .8),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Dissolve.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Dissolve.muted,
      subtitleTextStyle: TextStyle(color: Dissolve.muted, fontSize: 13),
    ),
    dividerTheme: DividerThemeData(color: Dissolve.border, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Dissolve.fg,
        foregroundColor: Dissolve.ink,
        shape: pill,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Dissolve.fg,
        shape: pill,
        side: BorderSide(color: Dissolve.edge),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Dissolve.accent, shape: pill),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Dissolve.fg),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Dissolve.fg,
      foregroundColor: Dissolve.ink,
      elevation: 0,
      highlightElevation: 0,
      shape: StadiumBorder(),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Dissolve.surface,
      selectedColor: Dissolve.fg,
      labelStyle: TextStyle(color: Dissolve.fg),
      secondaryLabelStyle: TextStyle(color: Dissolve.ink),
      side: BorderSide(color: Dissolve.border),
      shape: pill,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Dissolve.ink : Dissolve.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Dissolve.success : Dissolve.raised,
      ),
      trackOutlineColor: WidgetStatePropertyAll(Dissolve.border),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Dissolve.surface,
        foregroundColor: Dissolve.muted,
        selectedBackgroundColor: Dissolve.fg,
        selectedForegroundColor: Dissolve.ink,
        side: BorderSide(color: Dissolve.border),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Dissolve.fg,
      linearTrackColor: Dissolve.raised,
      circularTrackColor: Dissolve.raised,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Dissolve.raised,
      labelStyle: TextStyle(color: Dissolve.muted),
      hintStyle: TextStyle(color: Dissolve.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Dissolve.accent),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Dissolve.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Dissolve.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Dissolve.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Dissolve.raised,
      contentTextStyle: TextStyle(color: Dissolve.fg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Dissolve.border),
      ),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: Dissolve.surface),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
