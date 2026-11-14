import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Material 3 theme built from AutoSense design tokens.
abstract final class AppTheme {
  /// [useGoogleFonts] is false in tests (no network access).
  static ThemeData light({bool useGoogleFonts = true}) =>
      _build(brightness: Brightness.light, useGoogleFonts: useGoogleFonts);

  static ThemeData dark({bool useGoogleFonts = true}) =>
      _build(brightness: Brightness.dark, useGoogleFonts: useGoogleFonts);

  static ThemeData _build({required Brightness brightness, required bool useGoogleFonts}) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand, brightness: brightness).copyWith(
      primary: isDark ? AppColors.brandDark : AppColors.brand,
      onPrimary: isDark ? AppColors.surfaceDark : Colors.white,
      secondary: AppColors.accent,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      onSurface: isDark ? AppColors.textDark : AppColors.ink,
      onSurfaceVariant: isDark ? AppColors.textMutedDark : AppColors.inkMuted,
      surfaceContainerLowest: isDark ? AppColors.surfaceDark : Colors.white,
      surfaceContainerLow: isDark ? AppColors.cardDark : AppColors.cardLight,
      surfaceContainer: isDark ? const Color(0xFF182030) : const Color(0xFFF0F2F8),
      surfaceContainerHigh: isDark ? const Color(0xFF1D2637) : const Color(0xFFE9ECF4),
      outline: isDark ? AppColors.outlineDark : AppColors.outlineLight,
      outlineVariant: isDark ? AppColors.outlineDark : AppColors.outlineLight,
      error: AppColors.u3,
    );

    final typography = Typography.material2021();
    final baseText = typography.englishLike.merge(isDark ? typography.white : typography.black);
    final fontText = useGoogleFonts ? GoogleFonts.interTextTheme(baseText) : baseText;
    final textTheme = fontText
        .copyWith(
          displaySmall: fontText.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
          headlineMedium: fontText.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
          headlineSmall: fontText.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          titleLarge: fontText.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          titleMedium: fontText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: fontText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: fontText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          bodyMedium: fontText.bodyMedium?.copyWith(height: 1.45),
          bodySmall: fontText.bodySmall?.copyWith(height: 1.4),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final roundedButton = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: buttonPadding,
          shape: roundedButton,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          shape: roundedButton,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: roundedButton, textStyle: textTheme.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: Radii.chip),
        side: BorderSide(color: scheme.outline),
        labelStyle: textTheme.labelLarge,
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: roundedButton,
          side: BorderSide(color: scheme.outline),
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) =>
              IconThemeData(color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md))),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
      checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
    );
  }
}
