import 'package:flutter/material.dart';

/// ALIX brend palitrasi.
///
/// Brend ikki rangdan iborat: **orange** (#FF6A13) va **charcoal** (#3A3A3A).
/// Qolgani — shu ikkisiga xizmat qiladigan neytral yuzalar. Yangi rang
/// qo'shishdan oldin o'ylab ko'ring: ko'pincha mavjud tokenning bosqichi
/// (soft / deep) yetarli bo'ladi.
///
/// Ranglar logotip fayllaridan olingan, `tool/brand/alix_mark.py` bilan bir xil.
class AppPalette {
  AppPalette._();

  // ─── Brend ─────────────────────────────────────────────────────────────
  /// Asosiy brend rangi — CTA, faol holat, marshrut chizig'i.
  static const Color orange = Color(0xFFFF6A13);

  /// Bosilgan/hover holati va gradient oxiri.
  static const Color orangeDeep = Color(0xFFE05605);

  /// Yorug' fonda orange ustidagi yumshoq to'ldirish (chip, banner).
  static const Color orangeSoft = Color(0xFFFFF0E6);

  /// Yorug' fonda MATN uchun orange.
  ///
  /// Brend orange (#FF6A13) oq fonda 2.87:1 beradi — WCAG AA (4.5:1) dan
  /// past, ya'ni kichik matn o'qilishi qiyin. To'ldirish (tugma foni,
  /// progress, nuqtalar) uchun brend rangi qoladi, matn esa shu quyuq
  /// variantda yoziladi: oq fonda 5.83:1, krem fonda 5.23:1.
  /// To'q rejimda brend orange o'zi yetarli (6.42:1), shuning uchun
  /// [accentTextOn] rejimga qarab tanlaydi.
  static const Color orangeText = Color(0xFFB23F00);

  /// Brendning to'q rangi — matn, to'q kartalar, ikkilamchi CTA.
  static const Color ink = Color(0xFF3A3A3A);

  /// Eng to'q daraja — to'q kartalar foni (tracking kartasi kabi).
  static const Color inkStrong = Color(0xFF1E1E1E);

  /// Ikkinchi darajali matn.
  static const Color inkMuted = Color(0xFF616161);

  /// Krem yuza — ro'yxat kartalari, ikkilamchi bloklar.
  static const Color sand = Color(0xFFF4F2EE);

  /// Krem yuzaning chegarasi.
  static const Color sandBorder = Color(0xFFE8E6E2);

  // ─── Holat ranglari (brenddan tashqari, faqat ma'no uchun) ─────────────
  static const Color success = Color(0xFF12A150);
  static const Color successSoft = Color(0xFFE7F6EE);

  /// Yorug' fonda matn uchun yashil (5.9:1). `success` o'zi 3:1 atrofida —
  /// belgi va to'ldirish uchun yetarli, matn uchun emas.
  static const Color successText = Color(0xFF0B6B35);

  /// Kutilmoqda / diqqat — brend orange bilan chalkashmasligi uchun sariq.
  static const Color amber = Color(0xFFF5A524);
  static const Color amberSoft = Color(0xFFFEF3E0);

  static const Color danger = Color(0xFFB3261E);
  static const Color dangerLight = Color(0xFFE5484D);
  static const Color dangerSoft = Color(0xFFFDECEC);

  // ─── Yorug' rejim yuzalari ─────────────────────────────────────────────
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = sand;
  static const Color lightBorder = Color(0xFFE6E4E0);
  static const Color lightOn = ink;
  static const Color lightMuted = inkMuted;

  // ─── To'q rejim yuzalari ───────────────────────────────────────────────
  static const Color darkBg = Color(0xFF141414);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkCardElevated = Color(0xFF262626);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkOn = Color(0xFFF4F2EE);
  static const Color darkMuted = Color(0xFFA3A3A3);

  // ─── Kontrastga mos variantlar ─────────────────────────────────────────
  /// Rejimga qarab matn uchun urg'u rangi.
  static Color accentTextOn(Brightness brightness) =>
      brightness == Brightness.dark ? orange : orangeText;

  /// Rejimga qarab matn uchun yashil.
  static Color successTextOn(Brightness brightness) =>
      brightness == Brightness.dark ? success : successText;

  /// Rejimga qarab matn uchun qizil (`dangerLight` oq fonda 3.9:1, kam).
  static Color dangerTextOn(Brightness brightness) =>
      brightness == Brightness.dark ? dangerLight : danger;

  // ─── Gradientlar ───────────────────────────────────────────────────────
  /// Asosiy CTA. Brend tekis rangda ishlaydi, gradient faqat sezilarli
  /// bo'lmagan chuqurlik beradi — shuning uchun ikki bosqich juda yaqin.
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [orange, orangeDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Ikkilamchi CTA — to'q charcoal (brend vizitkasidagi tugma kabi).
  static const LinearGradient inkGradient = LinearGradient(
    colors: [ink, inkStrong],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── O'lchovlar ────────────────────────────────────────────────────────
  /// Brendda burchaklar yumshoq: kartalar 18, tugmalar 16, chiplar 12.
  static const double radiusCard = 18;
  static const double radiusButton = 16;
  static const double radiusChip = 12;
  static const double radiusField = 14;
}
