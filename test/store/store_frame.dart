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
  });

  final String title;
  final String subtitle;
  final Widget screen;

  /// To'q fon varianti (ketma-ketlikda ritm berish uchun).
  final bool dark;

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
              child: _Phone(width: phoneW, bezel: bezel, dark: dark, screen: screen),
            ),
          ],
        ),
      );
    });
  }
}

class _Phone extends StatelessWidget {
  const _Phone({required this.width, required this.bezel, required this.dark, required this.screen});

  final double width;
  final double bezel;
  final bool dark;
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
            child: SizedBox.fromSize(size: kPhoneScreen, child: PhoneScreen(child: screen)),
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
  const PhoneScreen({super.key, required this.child});

  final Widget child;

  static const double statusBar = 47;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).copyWith(
      size: kPhoneScreen,
      devicePixelRatio: 3,
      padding: const EdgeInsets.only(top: statusBar, bottom: 20),
      viewPadding: const EdgeInsets.only(top: statusBar, bottom: 20),
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
            const Positioned(left: 0, right: 0, top: 0, height: statusBar, child: _StatusBar()),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const c = AppPalette.inkStrong;
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
