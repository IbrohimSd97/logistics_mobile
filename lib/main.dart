import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (_, __) {
        return MaterialApp(
          title: 'ALIX Logistics',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const LoginScreen(),
        );
      },
    );
  }
}
