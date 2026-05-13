import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ilova bo'yicha tema rejimini boshqaradi (light/dark/system).
/// Tanlov shared_preferences'da saqlanadi.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _kKey = 'alix_theme_mode';
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

  /// Initialdan keyin chaqiriladi: saqlangan tanlovni yuklaydi.
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_kKey);
      switch (v) {
        case 'dark':
          _mode = ThemeMode.dark;
          break;
        case 'light':
          _mode = ThemeMode.light;
          break;
        case 'system':
          _mode = ThemeMode.system;
          break;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ThemeController.load error: $e');
    }
  }

  Future<void> setMode(ThemeMode m) async {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kKey, _serialize(m));
    } catch (e) {
      debugPrint('ThemeController.setMode persist error: $e');
    }
  }

  Future<void> toggle() async {
    final next = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }

  String _serialize(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }
}
