import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/brand/alix_logo.dart';
import 'package:mening_ilovam/core/brand/alix_splash.dart';
import 'package:mening_ilovam/core/theme/app_palette.dart';
import 'package:mening_ilovam/core/theme/app_theme.dart';
import 'package:mening_ilovam/core/widgets/gradient_button.dart';
import 'package:mening_ilovam/screens/customer_main_shell.dart';
import 'package:mening_ilovam/screens/login_screen.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
    home: child,
  );
}

/// Brend ekranlarining ko'rinish namunalari (golden).
///
/// Golden'lar platformaga bog'liq (shrift rasterizatsiyasi macOS va Linux'da
/// bir xil emas), shuning uchun ular ODATDAGI `flutter test` da o'tkazib
/// yuboriladi. Brend o'zgarsa namunalarni shunday yangilaymiz:
///
///     flutter test test/brand --dart-define=brand_previews=true --update-goldens
///
/// Natija PNG'lari `test/brand/` da yotadi va brend hujjatiga havola qilinadi.
const bool _enabled = bool.fromEnvironment('brand_previews');

void main() {
  // Golden'larda haqiqiy shrift ko'rinishi uchun Manrope'ni qo'lda yuklaymiz —
  // aks holda test muhiti o'rniga bo'sh to'rtburchaklar chizadi.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Manrope');
    for (final weight in const [
      'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold',
    ]) {
      loader.addFont(
        rootBundle.load('assets/fonts/Manrope-$weight.ttf'),
      );
    }
    await loader.load();
  });

  testWidgets('splash', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    await tester.pumpWidget(_app(const AlixSplash()));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(AlixSplash), matchesGoldenFile('preview_splash.png'));
  }, skip: !_enabled);

  testWidgets('login', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    await tester.pumpWidget(_app(const LoginScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(LoginScreen), matchesGoldenFile('preview_login.png'));
  }, skip: !_enabled);

  testWidgets('customer home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 860));
    await tester.pumpWidget(_app(Scaffold(
      appBar: AppBar(
        title: const AlixLogo(height: 22),
        actions: const [Icon(Icons.notifications_none_rounded), SizedBox(width: 16)],
      ),
      body: CustomerHomeBody(
        phoneDisplay: '+998 90 000 00 00',
        userId: 1,
        // Tarmoqqa chiqmasligi uchun: sessiya yo'q bo'lsa `_load()` chaqirilmaydi.
        hasRefreshSession: false,
        refreshTick: 0,
        onRefreshParent: () async {},
        onCreateOrder: () {},
        onOpenOrders: (_) {},
      ),
    )));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
        find.byType(CustomerHomeBody), matchesGoldenFile('preview_customer_home.png'));
  }, skip: !_enabled);

  testWidgets('components light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    await tester.pumpWidget(_app(const _Showcase()));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(_Showcase), matchesGoldenFile('preview_components_light.png'));
  }, skip: !_enabled);

  testWidgets('components dark', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    await tester.pumpWidget(_app(const _Showcase(), brightness: Brightness.dark));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(_Showcase), matchesGoldenFile('preview_components_dark.png'));
  }, skip: !_enabled);
}

class _Showcase extends StatelessWidget {
  const _Showcase();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const AlixLogo(height: 22),
        actions: const [Icon(Icons.notifications_none_rounded), SizedBox(width: 16)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          Text('Yuklaringiz', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppPalette.inkStrong,
              borderRadius: BorderRadius.circular(AppPalette.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TRACKING · AX-20481',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white70)),
                const SizedBox(height: 8),
                const Text('Toshkent → Almaty',
                    style: TextStyle(
                        color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.62,
                    minHeight: 6,
                    color: AppPalette.orange,
                    backgroundColor: Color(0xFF3A3A3A),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("Yo'lda", style: TextStyle(color: Colors.white)),
                    Text('62%',
                        style: TextStyle(
                            color: AppPalette.orange, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: cs.surfaceContainerHighest,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: const AlixMark(height: 26),
              title: const Text('Konteyner 40ft'),
              subtitle: const Text('Yetkazish: 24 sentabr'),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Telefon raqami',
              hintText: '+998 90 123 45 67',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(label: 'Yangi buyurtma', onPressed: () {}),
          const SizedBox(height: 10),
          AlixInkButton(label: 'Batafsil', onPressed: () {}),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () {}, child: const Text('Bekor qilish')),
        ],
      ),
    );
  }
}
