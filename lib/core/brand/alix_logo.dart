import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// ALIX logotipi — vektor sifatida chiziladi, shuning uchun har qanday
/// o'lchamda tiniq va rangini tema bo'yicha o'zgartira oladi.
///
/// Geometriya `tool/brand/alix_mark.py` dagi bilan bir xil (240 × 126 birlik):
/// to'rtta charcoal panel, o'ngida orange panel va uning ichida oq tirqish.
/// Panellar orasidagi bo'shliqlar SHAFFOF — belgi oq, krem va to'q fonda
/// bir xil to'g'ri ko'rinadi.
class AlixMark extends StatelessWidget {
  const AlixMark({
    super.key,
    this.height = 24,
    this.inkColor,
    this.accentColor = AppPalette.orange,
    this.slotColor = Colors.white,
    this.monochrome = false,
  });

  /// Belgining balandligi; kenglik nisbat bo'yicha hisoblanadi.
  final double height;

  /// Panellar rangi. Berilmasa temadagi asosiy matn rangi olinadi, shunda
  /// belgi to'q rejimda ham ko'rinadi.
  final Color? inkColor;

  /// O'ng paneldagi brend rangi.
  final Color accentColor;

  /// Orange panel ichidagi tirqish rangi.
  final Color slotColor;

  /// Bitta rangdagi variant — orange panel ham `inkColor` bilan chiziladi
  /// (masalan bir rangli bosma yoki disabled holat uchun).
  final bool monochrome;

  static const double aspectRatio = _AlixMarkPainter.unitWidth / _AlixMarkPainter.unitHeight;

  @override
  Widget build(BuildContext context) {
    final ink = inkColor ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: height,
      width: height * aspectRatio,
      child: CustomPaint(
        painter: _AlixMarkPainter(
          ink: ink,
          accent: monochrome ? ink : accentColor,
          slot: monochrome ? Colors.transparent : slotColor,
        ),
        isComplex: false,
      ),
    );
  }
}

class _AlixMarkPainter extends CustomPainter {
  const _AlixMarkPainter({
    required this.ink,
    required this.accent,
    required this.slot,
  });

  final Color ink;
  final Color accent;
  final Color slot;

  // Brend geometriyasining birliklari.
  static const double unitWidth = 240;
  static const double unitHeight = 126;
  static const double _radius = 13;
  static const double _accentX = 177;
  static const List<List<double>> _gaps = [
    [42, 48],
    [81, 87],
    [120, 126],
  ];
  static const Rect _slot = Rect.fromLTRB(205.5, 24, 211.5, 102);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / unitHeight;
    canvas.save();
    canvas.scale(k);

    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, unitWidth, unitHeight),
          const Radius.circular(_radius),
        ),
      );

    // Chap (charcoal) qism: umumiy shakldan o'ng panelni va bo'shliqlarni ayiramiz.
    var inkPath = Path.combine(
      PathOperation.intersect,
      outline,
      Path()..addRect(const Rect.fromLTWH(0, 0, _accentX, unitHeight)),
    );
    for (final gap in _gaps) {
      inkPath = Path.combine(
        PathOperation.difference,
        inkPath,
        Path()..addRect(Rect.fromLTRB(gap[0], 0, gap[1], unitHeight)),
      );
    }

    // O'ng (orange) qism — yumaloq burchaklar umumiy shakldan meros bo'ladi.
    final accentPath = Path.combine(
      PathOperation.intersect,
      outline,
      Path()..addRect(const Rect.fromLTRB(_accentX, 0, unitWidth, unitHeight)),
    );

    canvas.drawPath(inkPath, Paint()..color = ink);
    canvas.drawPath(accentPath, Paint()..color = accent);
    if (slot.a > 0) {
      canvas.drawRect(_slot, Paint()..color = slot);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AlixMarkPainter old) =>
      old.ink != ink || old.accent != accent || old.slot != slot;
}

/// "ALIX" so'z belgisi — brendda doim katta harflar va keng harf oralig'i.
class AlixWordmark extends StatelessWidget {
  const AlixWordmark({super.key, this.fontSize = 18, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'ALIX',
      style: TextStyle(
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        // Brend kitobidagi lockup: harflar orasi keng.
        letterSpacing: fontSize * 0.22,
        height: 1,
      ),
    );
  }
}

/// Belgi + so'z belgisi — gorizontal lockup (AppBar, login, sarlavhalar).
class AlixLogo extends StatelessWidget {
  const AlixLogo({
    super.key,
    this.height = 22,
    this.color,
    this.showWordmark = true,
  });

  final double height;
  final Color? color;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.onSurface;
    final mark = AlixMark(height: height, inkColor: ink);
    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: height * 0.62),
        AlixWordmark(fontSize: height * 0.86, color: ink),
      ],
    );
  }
}

/// Vertikal lockup — splash va bo'sh holat ekranlari uchun.
class AlixLogoStacked extends StatelessWidget {
  const AlixLogoStacked({super.key, this.markHeight = 64, this.color});

  final double markHeight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AlixMark(height: markHeight, inkColor: ink),
        SizedBox(height: markHeight * 0.55),
        AlixWordmark(fontSize: markHeight * 0.42, color: ink),
      ],
    );
  }
}
