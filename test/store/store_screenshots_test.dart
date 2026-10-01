import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/brand/alix_components.dart';
import 'package:mening_ilovam/core/i18n/i18n.dart';
import 'package:mening_ilovam/core/theme/app_theme.dart';
import 'package:mening_ilovam/customer/pages/customer_order_create_page.dart';
import 'package:mening_ilovam/customer/widgets/order_fiscal_receipts_section.dart';
import 'package:mening_ilovam/screens/customer_main_shell.dart';
import 'package:mening_ilovam/screens/driver_main_shell.dart';

import 'store_fake_api.dart';
import 'store_frame.dart';

/// App Store / Google Play screenshotlari. Ekranlar haqiqiy kod bilan,
/// soxta backend javoblari asosida chiziladi. Oddiy `flutter test` da
/// o'tkazib yuboriladi; yangilash:
///
///     flutter test test/store --dart-define=store_shots=true --update-goldens
///
/// Natija: `store_assets/screenshots/<o'lcham>/<til>/NN_nom.png`.
const bool _enabled = bool.fromEnvironment('store_shots');

const _canvasKey = ValueKey('store-canvas');

/// Do'kon o'lchamlari — mantiqiy o'lcham × 3 = talab qilingan piksel.
const _sizes = <String, Size>{
  'ios_6.9': Size(440, 956), // 1320×2868 — App Store, iPhone 6.9"
  'ios_6.5': Size(414, 896), // 1242×2688 — App Store, iPhone 6.5"
  'play_phone': Size(360, 640), // 1080×1920 — Google Play, telefon (9:16)
};

class _Shot {
  const _Shot(this.name, this.titleUz, this.subUz, this.titleRu, this.subRu,
      {required this.userType, required this.screen, this.after, this.dark = false});

  final String name;
  final String titleUz, subUz, titleRu, subRu;
  final String userType;
  final Widget Function() screen;

  /// Ekran chizilgandan keyingi harakat (tab bosish, sheet ochish).
  final Future<void> Function(WidgetTester tester)? after;
  final bool dark;
}

Future<void> _tapText(WidgetTester tester, String key) async {
  await tester.tap(find.text(I18n.t(key)).last);
  await _settle(tester);
}

/// Pastki navigatsiya telefon ramkasidan pastda (ko'rinmaydi) — tabni
/// to'g'ridan-to'g'ri tanlaymiz.
Future<void> _selectTab(WidgetTester tester, int index) async {
  tester.widget<NavigationBar>(find.byType(NavigationBar)).onDestinationSelected!(index);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _shots = <_Shot>[
  _Shot(
    '01_home',
    'Yukingiz qayerda —\nbir qarashda',
    'Buyurtma holati va har bir bosqich real vaqtda',
    'Где ваш груз —\nс одного взгляда',
    'Статус заказа и каждый этап в реальном времени',
    userType: 'customer',
    screen: () => const CustomerMainShell(
        phoneDisplay: '+998 90 123 45 67', userId: 1, hasRefreshSession: true),
  ),
  _Shot(
    '02_create',
    'Buyurtmani\nbir daqiqada bering',
    'Manzil, yuk turi va vazn — qolganini ALIX hal qiladi',
    'Оформите заказ\nза минуту',
    'Адрес, тип груза и вес — остальное сделает ALIX',
    userType: 'customer',
    screen: () => CustomerOrderCreatePage(
      prefillCargoTypeId: 1,
      prefillPickupAddress: I18n.instance.code == 'ru'
          ? 'Ташкент, Юнусабад, Амир Темур 108'
          : 'Toshkent, Yunusobod, Amir Temur 108',
      prefillPickupLat: 41.3650,
      prefillPickupLng: 69.2870,
      prefillDeliveryAddress: I18n.instance.code == 'ru'
          ? 'Самарканд, ул. Регистан 14'
          : 'Samarqand, Registon ko\'chasi 14',
      prefillDeliveryLat: 39.6542,
      prefillDeliveryLng: 66.9597,
      prefillCargoWeightKg: 1800,
    ),
  ),
  _Shot(
    '03_orders',
    'Barcha buyurtmalar\nbir joyda',
    'Joriy va arxiv — har bir bosqich vaqti bilan',
    'Все заказы\nв одном месте',
    'Текущие и архив — с временем каждого этапа',
    userType: 'customer',
    screen: () => const CustomerMainShell(
        phoneDisplay: '+998 90 123 45 67', userId: 1, hasRefreshSession: true),
    after: (t) => _selectTab(t, 1),
  ),
  _Shot(
    '04_receipt',
    'Har bir buyurtmaga\nfiskal chek',
    'Soliq tizimida QR kod orqali tekshiriladi',
    'Фискальный чек\nна каждый заказ',
    'Проверяется в налоговой по QR-коду',
    userType: 'customer',
    dark: true,
    screen: () => const _ReceiptScreen(),
    after: (t) => _tapText(t, 'fiscal.type.sale'),
  ),
  _Shot(
    '05_wallet',
    'Hamyon: tez va\nxavfsiz to\'lov',
    'Kartadan to\'ldiring, buyurtmani bir tugma bilan to\'lang',
    'Кошелёк: быстрая\nи безопасная оплата',
    'Пополняйте с карты и оплачивайте в одно касание',
    userType: 'customer',
    screen: () => const CustomerMainShell(
        phoneDisplay: '+998 90 123 45 67', userId: 1, hasRefreshSession: true),
    after: (t) => _selectTab(t, 2),
  ),
  _Shot(
    '06_driver',
    'Haydovchilar uchun\nyangi buyurtmalar',
    'Mos yuklarni qabul qiling va daromadingizni kuzating',
    'Новые заказы\nдля водителей',
    'Принимайте подходящие грузы и следите за доходом',
    userType: 'driver',
    dark: true,
    screen: () => const DriverMainShell(
        phoneDisplay: '+998 90 123 45 67', userId: 7, userType: 'driver'),
  ),
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final manrope = FontLoader('Manrope');
    for (final w in const ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      manrope.addFont(rootBundle.load('assets/fonts/Manrope-$w.ttf'));
    }
    await manrope.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  // Haydovchi joylashuvi — Toshkent markazi (GPS plagini test muhitida yo'q).
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async => switch (call.method) {
        'isLocationServiceEnabled' => true,
        'checkPermission' || 'requestPermission' => 3,
        'getLastKnownPosition' || 'getCurrentPosition' => {
            'latitude': 41.3111,
            'longitude': 69.2797,
            'timestamp': DateTime.utc(2026, 10, 1, 4).millisecondsSinceEpoch,
            'accuracy': 5.0,
            'altitude': 450.0,
            'altitude_accuracy': 3.0,
            'heading': 0.0,
            'heading_accuracy': 1.0,
            'speed': 0.0,
            'speed_accuracy': 0.0,
            'is_mocked': false,
          },
        _ => null,
      },
    );

    // Yandex reverse-geocode: session kanallari `..._session_<id>` (id o'sib
    // boradi) — bir nechtasini oldindan ulaymiz.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('yandex_mapkit/yandex_search'), (_) async => null);
    for (var id = 0; id < 400; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('yandex_mapkit/yandex_search_session_$id'),
        (call) async {
          if (call.method != 'searchByPoint') return null;
          final ru = I18n.instance.code == 'ru';
          const pt = {'latitude': 41.3111, 'longitude': 69.2797};
          return {
            'found': 1,
            'page': 0,
            'error': null,
            'items': [
              {
                'name': ru ? 'улица Амира Темура' : 'Amir Temur ko\'chasi',
                'geometry': [
                  {'point': pt}
                ],
                'toponymMetadata': {
                  'balloonPoint': pt,
                  'address': {
                    'formattedAddress': ru
                        ? 'Ташкент, Мирабадский район, ул. Амира Темура'
                        : 'Toshkent, Mirobod tumani, Amir Temur ko\'chasi',
                  },
                },
              }
            ],
          };
        },
      );
    }
  });

  // Google Play "Feature graphic" — 1024×500 (mantiqiy 512×250 × 2).
  for (final lang in AppLocaleCode.values) {
    testWidgets('play feature graphic ${lang.code}', (tester) async {
      await withStoreApi(userType: 'customer', body: () async {
        await I18n.instance.setLocale(lang);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1024, 500);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: RepaintBoundary(
            key: _canvasKey,
            child: FittedBox(
              child: SizedBox(
                width: 512,
                height: 250,
                child: FeatureGraphic(
                  ru: lang == AppLocaleCode.ru,
                  screen: const CustomerMainShell(
                      phoneDisplay: '+998 90 123 45 67', userId: 1, hasRefreshSession: true),
                ),
              ),
            ),
          ),
        ));
        await _settle(tester);
        await expectLater(find.byKey(_canvasKey),
            matchesGoldenFile('../../store_assets/play/feature_graphic_${lang.code}.png'));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 5));
      });
    }, skip: !_enabled);
  }

  for (final lang in AppLocaleCode.values) {
    for (final size in _sizes.entries) {
      for (final shot in _shots) {
        testWidgets('${size.key} ${lang.code} ${shot.name}', (tester) async {
          await withStoreApi(userType: shot.userType, body: () async {
            await I18n.instance.setLocale(lang);
            // Golden 1x chiziladi — shuning uchun sahna mantiqiy o'lchamda
            // quriladi va ×3 (do'kon piksel o'lchami) ga vektor holida
            // kattalashtiriladi (rasterizatsiya yakuniy o'lchamda bo'ladi).
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size.value * 3;
            addTearDown(tester.view.reset);

            final ru = lang == AppLocaleCode.ru;
            await tester.pumpWidget(MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: RepaintBoundary(
                key: _canvasKey,
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: size.value,
                    child: StoreFrame(
                      title: ru ? shot.titleRu : shot.titleUz,
                      subtitle: ru ? shot.subRu : shot.subUz,
                      dark: shot.dark,
                      screen: shot.screen(),
                    ),
                  ),
                ),
              ),
            ));
            await _settle(tester);
            await shot.after?.call(tester);
            await _settle(tester);

            await expectLater(
              find.byKey(_canvasKey),
              matchesGoldenFile(
                  '../../store_assets/screenshots/${size.key}/${lang.code}/${shot.name}.png'),
            );

            // Taymerlar (polling, GPS) keyingi testga o'tmasin.
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(minutes: 5));
          });
        }, skip: !_enabled);
      }
    }
  }
}

/// Yakunlangan buyurtma: qisqa ma'lumot + haqiqiy `OrderFiscalReceiptsSection`.
/// (Tafsilot sahifasidagi Yandex xarita test muhitida chizilmaydi.)
class _ReceiptScreen extends StatelessWidget {
  const _ReceiptScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ru = I18n.instance.code == 'ru';
    return Scaffold(
      appBar: AppBar(title: const Text('AX-20390')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              AlixStatusChip(label: I18n.t('order.status.finished_short'), tone: AlixTone.success),
              const Spacer(),
              Text('920 000', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text('UZS', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 14),
          AlixCard(
            tone: AlixSurfaceTone.cream,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ru ? 'Ташкент, Сергелийский логистический центр' : 'Toshkent, Sergeli logistika markazi',
                    style: tt.bodyMedium),
                const Divider(height: 18),
                Text(ru ? 'Бухара, Промзона 4' : 'Buxoro, Sanoat zonasi 4', style: tt.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const OrderFiscalReceiptsSection(orderId: 20390),
        ],
      ),
    );
  }
}
