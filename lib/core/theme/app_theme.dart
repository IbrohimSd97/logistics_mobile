import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';

/// ALIX dizayn tizimi.
///
/// Qoida: ekranlarda rang qo'lda yozilmaydi — hammasi shu yerdan
/// (`Theme.of(context).colorScheme` yoki `AppPalette`) olinadi. Shu tufayli
/// brend o'zgarsa bitta fayl yangilanadi.
class AppTheme {
  AppTheme._();

  /// Brend shrifti — Manrope (geometrik grotesk, lotin + kirill).
  static const String fontFamily = 'Manrope';

  static ThemeData light() => _build(brightness: Brightness.light);

  static ThemeData dark() => _build(brightness: Brightness.dark);

  /// Status bar / navigation bar ranglari — yorug' va to'q rejim uchun.
  static SystemUiOverlayStyle overlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark ? AppPalette.darkBg : AppPalette.lightBg,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppPalette.darkBg : AppPalette.lightBg;
    final card = isDark ? AppPalette.darkCard : AppPalette.lightCard;
    final cardElevated = isDark ? AppPalette.darkCardElevated : AppPalette.lightCardElevated;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;
    final onSurface = isDark ? AppPalette.darkOn : AppPalette.lightOn;
    final muted = isDark ? AppPalette.darkMuted : AppPalette.lightMuted;

    // Kiritish maydonlari yorug' rejimda krem, to'q rejimda ko'tarilgan karta —
    // ikkalasida ham fon bilan yengil kontrast beradi.
    final fieldFill = isDark ? AppPalette.darkCardElevated : AppPalette.sand;

    final cs = ColorScheme(
      brightness: brightness,
      primary: AppPalette.orange,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF52240A) : AppPalette.orangeSoft,
      onPrimaryContainer: isDark ? AppPalette.orangeSoft : AppPalette.orangeDeep,
      // Ikkilamchi rang — brendning to'q tomoni (charcoal tugmalar, badge'lar).
      secondary: isDark ? AppPalette.darkOn : AppPalette.ink,
      onSecondary: isDark ? AppPalette.inkStrong : Colors.white,
      secondaryContainer: isDark ? AppPalette.darkCardElevated : AppPalette.sand,
      onSecondaryContainer: onSurface,
      tertiary: AppPalette.amber,
      onTertiary: AppPalette.inkStrong,
      tertiaryContainer: isDark ? const Color(0xFF4A3510) : AppPalette.amberSoft,
      onTertiaryContainer: isDark ? AppPalette.amberSoft : const Color(0xFF7A4E00),
      error: AppPalette.dangerLight,
      onError: Colors.white,
      errorContainer: isDark ? AppPalette.danger : AppPalette.dangerSoft,
      onErrorContainer: isDark ? Colors.white : AppPalette.danger,
      surface: bg,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      surfaceContainerHighest: cardElevated,
      surfaceContainerHigh: cardElevated,
      surfaceContainer: card,
      surfaceContainerLow: isDark ? AppPalette.darkCard : AppPalette.sand,
      surfaceContainerLowest: bg,
      outline: border,
      outlineVariant: border,
      inverseSurface: isDark ? AppPalette.darkOn : AppPalette.inkStrong,
      onInverseSurface: isDark ? AppPalette.inkStrong : Colors.white,
      inversePrimary: AppPalette.orangeDeep,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final textTheme = _textTheme(onSurface: onSurface, muted: muted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle(brightness),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: onSurface),
        actionsIconTheme: IconThemeData(color: onSurface),
      ),

      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppPalette.radiusCard),
          side: BorderSide(color: border, width: 1),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: onSurface,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, color: muted, height: 1.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppPalette.radiusChip),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        labelStyle: TextStyle(fontFamily: fontFamily, color: muted),
        hintStyle: TextStyle(fontFamily: fontFamily, color: muted.withValues(alpha: 0.7)),
        floatingLabelStyle: const TextStyle(fontFamily: fontFamily, color: AppPalette.orange),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: _fieldBorder(border),
        enabledBorder: _fieldBorder(border),
        focusedBorder: _fieldBorder(AppPalette.orange, width: 1.6),
        errorBorder: _fieldBorder(AppPalette.dangerLight),
        focusedErrorBorder: _fieldBorder(AppPalette.dangerLight, width: 1.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppPalette.orange.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPalette.radiusButton),
          ),
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPalette.radiusButton),
          ),
          minimumSize: const Size.fromHeight(52),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: isDark ? border : AppPalette.ink, width: 1.4),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPalette.radiusButton),
          ),
          minimumSize: const Size.fromHeight(50),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.orange,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: isDark
            ? AppPalette.orange.withValues(alpha: 0.22)
            : AppPalette.orangeSoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppPalette.radiusChip),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            color: selected ? (isDark ? AppPalette.orange : AppPalette.ink) : muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppPalette.orange : muted);
        }),
        height: 70,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cardElevated,
        side: BorderSide(color: border),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppPalette.radiusChip),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontSize: 15,
          height: 1.45,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.inkStrong,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          height: 1.35,
        ),
        actionTextColor: AppPalette.orange,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppPalette.radiusChip),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppPalette.orange,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppPalette.orange,
        linearTrackColor: border,
        circularTrackColor: Colors.transparent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppPalette.orange : border,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppPalette.orange : border,
        ),
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      tabBarTheme: TabBarThemeData(
        indicatorColor: AppPalette.orange,
        labelColor: onSurface,
        unselectedLabelColor: muted,
        dividerColor: border,
        labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500),
      ),

      iconTheme: IconThemeData(color: onSurface),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppPalette.orange : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: muted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppPalette.orange : muted,
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: AppPalette.orange,
        inactiveTrackColor: border,
        thumbColor: AppPalette.orange,
        overlayColor: AppPalette.orange.withValues(alpha: 0.12),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppPalette.inkStrong,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white, fontSize: 12),
      ),

      textTheme: textTheme,
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppPalette.radiusField),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Tipografika shkalasi. Sarlavhalar zich (manfiy letterSpacing) va qalin —
  /// brend materiallaridagi kabi; matn qatorlari esa bo'shroq, o'qishga qulay.
  static TextTheme _textTheme({required Color onSurface, required Color muted}) {
    TextStyle head(double size, FontWeight weight) => TextStyle(
          fontFamily: fontFamily,
          color: onSurface,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: -size * 0.02,
          height: 1.15,
        );

    return TextTheme(
      displaySmall: head(34, FontWeight.w800),
      headlineLarge: head(30, FontWeight.w800),
      headlineMedium: head(26, FontWeight.w800),
      headlineSmall: head(22, FontWeight.w700),
      titleLarge: head(19, FontWeight.w700),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        color: onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      // Bo'lim sarlavhalari — brendda kichik, katta harfli, keng oraliqli.
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        color: onSurface,
        fontSize: 16,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        color: onSurface,
        fontSize: 14.5,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        color: muted,
        fontSize: 13,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        color: onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(fontFamily: fontFamily, color: muted, fontSize: 13),
      labelSmall: TextStyle(fontFamily: fontFamily, color: muted, fontSize: 12),
    );
  }
}
