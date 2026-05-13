import 'package:flutter/material.dart';

/// ALIX Logistics dizayn palitra. Light va Dark rejimlar uchun.
class AppPalette {
  AppPalette._();

  // ─── Brand (har ikki rejimda bir xil) ───
  static const Color amber = Color(0xFFFBBF24);
  static const Color amberDeep = Color(0xFFD97706);
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealDeep = Color(0xFF0D9488);

  // Status
  static const Color danger = Color(0xFF991B1B);
  static const Color dangerLight = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // ─── Dark rejim ───
  static const Color darkBg = Color(0xFF070B12);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkCardElevated = Color(0xFF1A2230);
  static const Color darkBorder = Color(0xFF1F2937);
  static const Color darkOn = Color(0xFFF3F4F6);
  static const Color darkMuted = Color(0xFF9CA3AF);

  // ─── Light rejim ───
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightOn = Color(0xFF0F172A);
  static const Color lightMuted = Color(0xFF64748B);

  // ─── Backwards-compat aliases (login_screen `AppPalette.bg/card/...` ishlatadi) ───
  /// Login sahifa yaratilganda dark fon ishlatadi (gradient, grid painter), shu yerda
  /// `bg`, `card`, `border`, `onDark`, `muted` doim dark variantni qaytaradi.
  static const Color bg = darkBg;
  static const Color card = darkCard;
  static const Color border = darkBorder;
  static const Color onDark = darkOn;
  static const Color muted = darkMuted;

  /// Brand gradient — amber → amberDeep (asosiy CTA)
  static const LinearGradient amberGradient = LinearGradient(
    colors: [amber, amberDeep],
  );

  /// Brand gradient — teal → tealDeep
  static const LinearGradient tealGradient = LinearGradient(
    colors: [teal, tealDeep],
  );
}
