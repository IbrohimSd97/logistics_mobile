import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/brand/alix_components.dart';
import 'package:mening_ilovam/core/brand/alix_logo.dart';
import 'package:mening_ilovam/core/brand/alix_splash.dart';
import 'package:mening_ilovam/core/theme/app_palette.dart';
import 'package:mening_ilovam/core/theme/app_theme.dart';
import 'package:mening_ilovam/core/widgets/gradient_button.dart';
import 'package:mening_ilovam/customer/pages/customer_order_create_page.dart';
import 'package:mening_ilovam/customer/pages/customer_wallet_topup_page.dart';
import 'package:mening_ilovam/screens/customer_main_shell.dart';
import 'package:mening_ilovam/driver/pages/driver_pending_page.dart';
import 'package:mening_ilovam/driver/pages/driver_registration_step1_page.dart';
import 'package:mening_ilovam/screens/driver_main_shell.dart';
import 'package:mening_ilovam/screens/login_screen.dart';

import 'fake_api.dart';

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

  testWidgets('customer orders', (tester) async {
    await withFakeApi(() async {
      await tester.binding.setSurfaceSize(const Size(390, 860));
      await tester.pumpWidget(_app(Scaffold(
        appBar: AppBar(title: const Text('Buyurtmalar')),
        body: const CustomerOrdersBody(
          hasRefreshSession: true,
          refreshTick: 0,
          onOpenDetail: _noop,
        ),
      )));
      // Soxta API javobi kelishi uchun bir necha kadr.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
          find.byType(CustomerOrdersBody), matchesGoldenFile('preview_customer_orders.png'));
    });
  }, skip: !_enabled);

  testWidgets('customer wallet', (tester) async {
    await withFakeApi(() async {
      await tester.binding.setSurfaceSize(const Size(390, 860));
      await tester.pumpWidget(_app(Scaffold(
        appBar: AppBar(title: const Text('Hamyon')),
        body: CustomerWalletBody(
          hasRefreshSession: true,
          refreshTick: 0,
          onTopUp: () {},
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
          find.byType(CustomerWalletBody), matchesGoldenFile('preview_customer_wallet.png'));
    });
  }, skip: !_enabled);

  testWidgets('customer profile', (tester) async {
    await withFakeApi(() async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      await tester.pumpWidget(_app(Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: CustomerProfileBody(
          phoneDisplay: '+998 90 000 00 00',
          userId: 1042,
          hasRefreshSession: true,
          onLogout: () {},
          onBecomeDriver: () {},
          onOpenRegistration: () async {},
        ),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
          find.byType(CustomerProfileBody), matchesGoldenFile('preview_customer_profile.png'));
    });
  }, skip: !_enabled);

  testWidgets('order create', (tester) async {
    await withFakeApi(() async {
      await tester.binding.setSurfaceSize(const Size(390, 980));
      await tester.pumpWidget(_app(const CustomerOrderCreatePage()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byType(CustomerOrderCreatePage),
          matchesGoldenFile('preview_order_create.png'));
    });
  }, skip: !_enabled);

  testWidgets('wallet topup', (tester) async {
    await withFakeApi(() async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      await tester.pumpWidget(_app(const CustomerWalletTopupPage()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byType(CustomerWalletTopupPage),
          matchesGoldenFile('preview_wallet_topup.png'));
    });
  }, skip: !_enabled);

  testWidgets('driver home', (tester) async {
    await withFakeApi(() async {
      await tester.binding.setSurfaceSize(const Size(390, 860));
      await tester.pumpWidget(_app(Scaffold(
        appBar: AppBar(title: const AlixLogo(height: 22)),
        body: DriverHomeBody(
          phoneDisplay: '+998 90 000 00 00',
          userId: 7,
          refreshTick: 0,
          onOpenDetail: (_, __) {},
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
          find.byType(DriverHomeBody), matchesGoldenFile('preview_driver_home.png'));
    });
  }, skip: !_enabled);

  testWidgets('driver profile', (tester) async {
    await withFakeApi(() async {
      await tester.binding.setSurfaceSize(const Size(390, 860));
      await tester.pumpWidget(_app(Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: DriverProfileBody(
          phoneDisplay: '+998 90 000 00 00',
          userId: 7,
          onLogout: () {},
          onSwitchToCustomer: () {},
        ),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
          find.byType(DriverProfileBody), matchesGoldenFile('preview_driver_profile.png'));
    });
  }, skip: !_enabled);

  testWidgets('driver registration step 1', (tester) async {
    await withFakeApi(() async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      await tester.pumpWidget(
          _app(const DriverRegistrationStep1Page(phoneDisplay: '+998 90 000 00 00')));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byType(DriverRegistrationStep1Page),
          matchesGoldenFile('preview_driver_reg_step1.png'));
    });
  }, skip: !_enabled);

  testWidgets('driver pending', (tester) async {
    await withFakeApi(() async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      await tester.pumpWidget(
          _app(const DriverPendingPage(phoneDisplay: '+998 90 000 00 00', userId: 7)));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byType(DriverPendingPage),
          matchesGoldenFile('preview_driver_pending.png'));
    });
  }, skip: !_enabled);

  testWidgets('list skeleton', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 520));
    await tester.pumpWidget(_app(const Scaffold(body: AlixListSkeleton())));
    await tester.pump(const Duration(milliseconds: 550));
    await expectLater(
        find.byType(AlixListSkeleton), matchesGoldenFile('preview_skeleton.png'));
  }, skip: !_enabled);

  testWidgets('confirm dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 560));
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showAlixConfirm(
              context,
              icon: Icons.logout_rounded,
              title: 'Chiqish',
              message: 'Hisobdan chiqishni xohlaysizmi?',
              confirmLabel: 'Chiqish',
              cancelLabel: 'Bekor qilish',
              danger: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
        find.byType(AlertDialog), matchesGoldenFile('preview_confirm_dialog.png'));
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

void _noop(Object _) {}

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
