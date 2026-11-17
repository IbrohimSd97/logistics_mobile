import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import 'core/api/logging_http_client.dart';
import 'core/api/net_log.dart';
import 'core/api/net_log_overlay.dart';
import 'core/i18n/i18n.dart';
import 'core/links/deep_link_service.dart';
import 'core/push/push_service.dart';
import 'core/session/session_expiry.dart';
import 'core/session/session_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/push_tap_router.dart';

void main() {
  // Tarmoq logi yoniq bo'lsa, BUTUN ishga tushirishni (binding init + runApp)
  // logging-client bor zona ICHIDA bajaramiz. Bu juda muhim: agar
  // `WidgetsFlutterBinding.ensureInitialized()` zonadan tashqarida chaqirilsa,
  // Flutter binding o'sha (root) zonani "ushlab qoladi" va keyin barcha
  // gesture/async callback'lar (tugma bosish → http.post) root zonada ishlaydi,
  // ya'ni LoggingHttpClient'ni ko'rmaydi — natijada NET log bo'sh qoladi.
  if (kNetLogEnabled) {
    http.runWithClient(
      _bootstrap,
      () => LoggingHttpClient(http.Client()),
    );
  } else {
    _bootstrap();
  }
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait<void>([
    ThemeController.instance.load(),
    I18n.instance.load(),
  ]);
  // Push — tilni bilishi kerak (I18n.load'dan keyin). Xato bo'lsa ilova
  // pushsiz ishlayveradi.
  PushService.instance.onTap = PushTapRouter.open;
  await PushService.instance.init();
  DeepLinkService.instance.init();
  SessionExpiry.handler = _onSessionRevoked;
  runApp(const MyApp());
}

/// Server sessiyani bekor qildi (401): sessiyani tozalab, login sahifasiga.
Future<void> _onSessionRevoked() async {
  final store = SessionStore();
  if ((await store.getRefreshToken()) == null) return;
  try {
    await store.clear();
  } catch (_) {}
  final nav = PushTapRouter.navigatorKey.currentState;
  if (nav == null) return;
  nav.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (_) => false,
  );
  final ctx = PushTapRouter.navigatorKey.currentContext;
  if (ctx != null && ctx.mounted) {
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      SnackBar(content: Text(I18n.t('auth.session_expired'))),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeController va I18n — har birida ChangeNotifier; ikkalasini birlashtirib
    // bitta AnimatedBuilder bilan tinglaymiz, biron tilni yoki temani o'zgartirsa
    // butun ilova qayta chiziladi.
    final merged = Listenable.merge([
      ThemeController.instance,
      I18n.instance,
    ]);
    return AnimatedBuilder(
      animation: merged,
      builder: (_, __) {
        return MaterialApp(
          title: 'ALIX Logistics',
          // Push bosilganda sahifa ochish uchun (context'siz navigatsiya).
          navigatorKey: PushTapRouter.navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: I18n.instance.flutterLocale,
          supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
          // Material widget'lari uchun lokalizatsiya delegate'lari (kalendar,
          // DatePicker, TextField'dagi paste/copy menyusi va h.k.). Bularsiz
          // `locale`'ni o'zbek/rus deb belgilab qo'yganimizda MaterialApp
          // "No MaterialLocalizations found" xatosi ko'taradi.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Debug tarmoq log overlay'i (kNetLogEnabled bo'lsa) — barcha
          // ekranlar ustida suzuvchi tugma + so'rov/javob ro'yxati.
          builder: (context, child) =>
              NetLogOverlay(child: child ?? const SizedBox.shrink()),
          home: const AuthGate(),
        );
      },
    );
  }
}
