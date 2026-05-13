import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(brightness: Brightness.light);

  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppPalette.darkBg : AppPalette.lightBg;
    final card = isDark ? AppPalette.darkCard : AppPalette.lightCard;
    final cardElevated = isDark ? AppPalette.darkCardElevated : AppPalette.lightCardElevated;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;
    final onSurface = isDark ? AppPalette.darkOn : AppPalette.lightOn;
    final muted = isDark ? AppPalette.darkMuted : AppPalette.lightMuted;

    final cs = ColorScheme(
      brightness: brightness,
      primary: AppPalette.teal,
      onPrimary: isDark ? AppPalette.darkBg : Colors.white,
      primaryContainer: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
      onPrimaryContainer: isDark ? AppPalette.darkOn : const Color(0xFF115E59),
      secondary: AppPalette.amber,
      onSecondary: const Color(0xFF111827),
      secondaryContainer: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
      onSecondaryContainer: isDark ? AppPalette.darkOn : const Color(0xFF92400E),
      tertiary: AppPalette.amber,
      onTertiary: const Color(0xFF111827),
      tertiaryContainer: isDark ? const Color(0xFF422006) : const Color(0xFFFEF3C7),
      onTertiaryContainer: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
      error: AppPalette.dangerLight,
      onError: Colors.white,
      errorContainer: isDark ? AppPalette.danger : const Color(0xFFFFE4E6),
      onErrorContainer: isDark ? const Color(0xFFFFE4E6) : AppPalette.danger,
      surface: bg,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      surfaceContainerHighest: cardElevated,
      surfaceContainerHigh: card,
      surfaceContainer: card,
      surfaceContainerLow: bg,
      surfaceContainerLowest: bg,
      outline: border,
      outlineVariant: border,
      inverseSurface: isDark ? AppPalette.darkOn : AppPalette.darkBg,
      onInverseSurface: isDark ? AppPalette.darkBg : AppPalette.darkOn,
      inversePrimary: AppPalette.tealDeep,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: border,

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: onSurface),
        actionsIconTheme: IconThemeData(color: onSurface),
      ),

      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: onSurface,
        subtitleTextStyle: TextStyle(color: muted, height: 1.35),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.65)),
        floatingLabelStyle: const TextStyle(color: AppPalette.teal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.teal, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.dangerLight),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.dangerLight, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.teal,
          foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(46),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.teal,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.teal.withValues(alpha: isDark ? 0.18 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppPalette.teal : muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppPalette.teal : muted);
        }),
        height: 68,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: onSurface,
          fontSize: 14,
          height: 1.45,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardElevated,
        contentTextStyle: TextStyle(color: onSurface, height: 1.35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppPalette.teal,
        linearTrackColor: border,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppPalette.teal : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppPalette.teal.withValues(alpha: 0.4)
              : border,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      tabBarTheme: TabBarThemeData(
        indicatorColor: AppPalette.teal,
        labelColor: AppPalette.teal,
        unselectedLabelColor: muted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),

      iconTheme: IconThemeData(color: onSurface),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppPalette.teal : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(isDark ? AppPalette.darkBg : Colors.white),
        side: BorderSide(color: muted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppPalette.teal : muted,
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: muted, fontWeight: FontWeight.w600, letterSpacing: 0.4),
        bodyLarge: TextStyle(color: onSurface),
        bodyMedium: TextStyle(color: onSurface),
        bodySmall: TextStyle(color: muted),
        labelLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: muted),
        labelSmall: TextStyle(color: muted),
      ),
    );
  }
}
