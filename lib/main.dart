import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/i18n/i18n.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'screens/login_screen.dart';

void main() async {
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
          home: const LoginScreen(),
        );
      },
    );
  }
}
