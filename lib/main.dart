import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import 'core/api/logging_http_client.dart';
import 'core/api/net_log.dart';
import 'core/api/net_log_overlay.dart';
import 'core/i18n/i18n.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'screens/auth_gate.dart';

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
  runApp(const MyApp());
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
