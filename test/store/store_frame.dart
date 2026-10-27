import 'package:flutter/material.dart';
import 'package:mening_ilovam/core/brand/alix_logo.dart';
import 'package:mening_ilovam/core/theme/app_palette.dart';
import 'package:mening_ilovam/core/theme/app_theme.dart';

/// Ilova ekrani chiziladigan "telefon" mantiqiy o'lchami (iPhone 14/15).
const Size kPhoneScreen = Size(390, 844);

/// Do'kon screenshoti: brend foni, sarlavha + izoh va telefon ramkasida
/// ilovaning haqiqiy ekrani. Telefon pastdan biroz chiqib ketadi — ekran
/// yirikroq ko'rinadi.
class StoreFrame extends StatelessWidget {
  const StoreFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.screen,
    this.dark = false,
    this.ios = false,
  });

  final String title;
  final String subtitle;
  final Widget screen;

  /// To'q fon varianti (ketma-ketlikda ritm berish uchun).
  final bool dark;

  /// App Store uchun: iPhone status bar (Dynamic Island). Aks holda Android.
  final bool ios;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      final bg = dark ? AppPalette.inkStrong : AppPalette.sand;
      final fg = dark ? Colors.white : AppPalette.inkStrong;
      final muted = dark ? Colors.white.withValues(alpha: 0.72) : AppPalette.inkMuted;

      // Uzun ekranlarda (iPhone) telefon kengroq, 16:9 (Play) da torroq.
      final aspect = h / w;
      final phoneW = w * (aspect > 2.0 ? 0.80 : 0.66);
      final bezel = phoneW * 0.032;
      final textTop = h * (aspect > 2.0 ? 0.075 : 0.06);

      return Material(
        color: bg,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Brend chiziqlari — o'ng yuqori burchakda (login ekranidagidek).
            Positioned(
              right: -w * 0.18,
              top: -h * 0.04,
              child: Transform.rotate(
                angle: 0.32,
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: w * 0.06,
                        height: h * 0.55,
                        margin: EdgeInsets.only(left: w * 0.04),
                        color: (dark ? Colors.white : AppPalette.inkStrong)
                            .withValues(alpha: dark ? 0.05 : 0.035),
                      ),
                    Container(
                      width: w * 0.06,
                      height: h * 0.55,
                      margin: EdgeInsets.only(left: w * 0.04),
                      color: AppPalette.orange.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: w * 0.08,
              right: w * 0.08,
              top: textTop,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlixLogo(height: w * 0.05, color: dark ? Colors.white : null),
                  SizedBox(height: h * 0.022),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: w * 0.078,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: fg,
                    ),
                  ),
                  SizedBox(height: h * 0.012),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: w * 0.042,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: (w - phoneW) / 2,
              width: phoneW,
              top: h * (aspect > 2.0 ? 0.335 : 0.36),
              child: _Phone(width: phoneW, bezel: bezel, dark: dark, ios: ios, screen: screen),
            ),
          ],
        ),
      );
    });
  }
}

class _Phone extends StatelessWidget {
  const _Phone({
    required this.width,
    required this.bezel,
    required this.dark,
    required this.screen,
    this.ios = false,
  });

  final double width;
  final double bezel;
  final bool dark;
  final bool ios;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    final innerW = width - bezel * 2;
    final innerH = innerW * kPhoneScreen.height / kPhoneScreen.width;
    final radius = width * 0.13;
    return Container(
      padding: EdgeInsets.all(bezel),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
          width: bezel * 0.25,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.5 : 0.22),
            blurRadius: width * 0.12,
            offset: Offset(0, width * 0.05),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - bezel),
        child: SizedBox(
          width: innerW,
          height: innerH,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            child: SizedBox.fromSize(size: kPhoneScreen, child: PhoneScreen(ios: ios, child: screen)),
          ),
        ),
      ),
    );
  }
}

/// Telefon ichidagi ilova: o'z MediaQuery'si (390×844, status bar joyi),
/// o'z Navigator'i (bottom sheet'lar ekran ichida ochiladi) va soxta
/// status bar.
class PhoneScreen extends StatelessWidget {
  const PhoneScreen({super.key, required this.child, this.ios = false});

  final Widget child;
  final bool ios;

  static const double statusBar = 47;
  static const double iosStatusBar = 54;

  @override
  Widget build(BuildContext context) {
    final top = ios ? iosStatusBar : statusBar;
    final mq = MediaQuery.of(context).copyWith(
      size: kPhoneScreen,
      devicePixelRatio: 3,
      padding: EdgeInsets.only(top: top, bottom: 20),
      viewPadding: EdgeInsets.only(top: top, bottom: 20),
      textScaler: TextScaler.noScaling,
    );
    return MediaQuery(
      data: mq,
      child: Theme(
        data: AppTheme.light(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Navigator(
                onGenerateRoute: (_) => PageRouteBuilder<void>(
                  pageBuilder: (_, __, ___) => child,
                  transitionDuration: Duration.zero,
                ),
              ),
            ),
            Positioned(left: 0, right: 0, top: 0, height: top, child: _StatusBar(ios: ios)),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.ios});

  final bool ios;

  @override
  Widget build(BuildContext context) {
    const c = AppPalette.inkStrong;
    if (ios) {
      return const IgnorePointer(child: CustomPaint(painter: _IosStatusBarPainter(c)));
    }
    return const IgnorePointer(
      child: Padding(
        padding: EdgeInsets.fromLTRB(34, 14, 26, 0),
        child: Row(
          children: [
            Text('9:41',
                style: TextStyle(
                    fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.w700, color: c)),
            Spacer(),
            Icon(Icons.signal_cellular_alt_rounded, size: 18, color: c),
            SizedBox(width: 5),
            Icon(Icons.wifi_rounded, size: 18, color: c),
            SizedBox(width: 5),
            Icon(Icons.battery_full_rounded, size: 20, color: c),
          ],
        ),
      ),
    );
  }
}

/// iPhone (Dynamic Island) status bar: chapda vaqt, o'rtada "orol", o'ngda
/// iOS uslubidagi signal, Wi-Fi va batareya. App Store Android status bar'li
/// screenshotlarni rad etadi (Guideline 2.3.10).
class _IosStatusBarPainter extends CustomPainter {
  const _IosStatusBarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const cy = 29.5; // ikonkalar va vaqtning vertikal markazi (orol markazi)
    final fill = Paint()..color = color;

    // Dynamic Island.
    const islandW = 125.0, islandH = 37.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, cy), width: islandW, height: islandH),
        const Radius.circular(islandH / 2),
      ),
      Paint()..color = Colors.black,
    );

    // Vaqt — orolning chap tomonidagi bo'shliq markazida.
    final time = TextPainter(
      text: TextSpan(
        text: '9:41',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final leftCenter = (w / 2 - islandW / 2) / 2 + 4;
    time.paint(canvas, Offset(leftCenter - time.width / 2, cy - time.height / 2));

    // O'ng guruh: signal (17×11), Wi-Fi (15×11), batareya (27×13).
    const signalW = 17.0, wifiW = 15.5, batteryW = 27.5, gap = 6.0;
    const groupW = signalW + gap + wifiW + gap + batteryW;
    final rightCenter = w - (w / 2 - islandW / 2) / 2 - 4;
    var x = rightCenter - groupW / 2;

    // Signal: 4 ta pog'onali ustun.
    const barW = 3.2, barGap = 1.4;
    for (var i = 0; i < 4; i++) {
      final h = 4.0 + i * 2.4;
      final left = x + i * (barW + barGap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, cy + 5.5 - h, barW, h),
          const Radius.circular(1),
        ),
        fill,
      );
    }
    x += signalW + gap;

    // Wi-Fi: pastdagi nuqtadan tarqaladigan 3 ta yoy (sektor).
    final origin = Offset(x + wifiW / 2, cy + 5.6);
    const sweep = 1.55; // ~89°
    const startAngle = -1.5708 - sweep / 2;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    for (final r in [4.0, 7.6, 11.2]) {
      if (r == 4.0) {
        final path = Path()
          ..moveTo(origin.dx, origin.dy)
          ..arcTo(Rect.fromCircle(center: origin, radius: r + 1), startAngle, sweep, false)
          ..close();
        canvas.drawPath(path, fill);
      } else {
        canvas.drawArc(Rect.fromCircle(center: origin, radius: r), startAngle + 0.08, sweep - 0.16,
            false, stroke);
      }
    }
    x += wifiW + gap;

    // Batareya: ochiq kontur, ichida to'liq zaryad va o'ngda "tugmacha".
    const bodyW = 25.0, bodyH = 12.5;
    final body = Rect.fromLTWH(x, cy - bodyH / 2, bodyW, bodyH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      Paint()
        ..color = color.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.deflate(2), const Radius.circular(2.5)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x + bodyW + 1.2, cy - 2.2, 1.6, 4.4),
        topRight: const Radius.circular(1),
        bottomRight: const Radius.circular(1),
      ),
      Paint()..color = color.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _IosStatusBarPainter old) => old.color != color;
}

/// Google Play "Feature graphic" (1024×500): chapda logotip va shior, o'ngda
/// qiyshaytirilgan telefon. Muhim matn chetlarga yaqin emas — Play uni
/// ba'zi joylarda kesib ko'rsatadi.
class FeatureGraphic extends StatelessWidget {
  const FeatureGraphic({super.key, required this.ru, required this.screen});

  final bool ru;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.inkStrong,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: 150,
            top: -40,
            child: Transform.rotate(
              angle: 0.32,
              child: Container(width: 26, height: 360, color: AppPalette.orange),
            ),
          ),
          Positioned(
            left: 36,
            top: 0,
            bottom: 0,
            width: 270,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AlixLogo(height: 26, color: Colors.white),
                const SizedBox(height: 18),
                Text(
                  ru ? 'Грузоперевозки —\nв одном приложении' : 'Yuk tashish —\nbitta ilovada',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ru
                      ? 'Заказ, отслеживание, оплата и фискальный чек'
                      : 'Buyurtma, kuzatuv, to\'lov va fiskal chek',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 34,
            top: 26,
            width: 150,
            child: Transform.rotate(
              angle: -0.06,
              child: _Phone(width: 150, bezel: 5, dark: true, screen: screen),
            ),
          ),
        ],
      ),
    );
  }
}
