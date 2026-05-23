import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_ru.dart';
import 'strings_uz.dart';

/// Qo'llab-quvvatlanadigan til kodlari.
enum AppLocaleCode { uz, ru }

extension AppLocaleCodeX on AppLocaleCode {
  String get code => switch (this) {
        AppLocaleCode.uz => 'uz',
        AppLocaleCode.ru => 'ru',
      };

  /// Inson o'qiy oladigan til nomi (o'z tilida).
  String get nativeName => switch (this) {
        AppLocaleCode.uz => 'O‘zbekcha',
        AppLocaleCode.ru => 'Русский',
      };

  Locale get locale => Locale(code);
}

/// Ilova bo'yicha aktiv tilni boshqaradi.
/// Tanlov `shared_preferences`da saqlanadi va `notifyListeners()` orqali
/// barcha widget'lar avtomatik qayta chiziladi.
///
/// Foydalanish (widget tree):
/// ```dart
/// AnimatedBuilder(
///   animation: I18n.instance,
///   builder: (_, __) => Text(I18n.t('common.refresh')),
/// );
/// ```
class I18n extends ChangeNotifier {
  I18n._();
  static final I18n instance = I18n._();

  static const String _kKey = 'alix_locale';

  AppLocaleCode _locale = AppLocaleCode.uz;

  AppLocaleCode get locale => _locale;
  String get code => _locale.code;
  Locale get flutterLocale => _locale.locale;

  /// Statik shortcut — `I18n.t('key')`.
  static String t(String key, [Map<String, Object?>? params]) =>
      instance.tr(key, params);

  /// Boshlang'ich yuklash (main()'da, runApp()'dan oldin chaqirin).
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_kKey);
      switch (v) {
        case 'ru':
          _locale = AppLocaleCode.ru;
          break;
        case 'uz':
          _locale = AppLocaleCode.uz;
          break;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('I18n.load error: $e');
    }
  }

  Future<void> setLocale(AppLocaleCode l) async {
    if (_locale == l) return;
    _locale = l;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kKey, l.code);
    } catch (e) {
      debugPrint('I18n.setLocale persist error: $e');
    }
  }

  /// Asosiy tarjima funksiyasi. Joriy tilda topilmasa — uz fallback.
  /// `params` keldi-mi `{name}` shaklidagi placeholder'lar almashtiriladi.
  String tr(String key, [Map<String, Object?>? params]) {
    final table = _tableFor(_locale);
    String? value = table[key];
    if (value == null && _locale != AppLocaleCode.uz) {
      value = kStringsUz[key];
    }
    value ??= key; // last-resort: kalitning o'zi
    if (params != null && params.isNotEmpty) {
      params.forEach((k, v) {
        value = value!.replaceAll('{$k}', v?.toString() ?? '');
      });
    }
    return value!;
  }

  Map<String, String> _tableFor(AppLocaleCode l) {
    switch (l) {
      case AppLocaleCode.ru:
        return kStringsRu;
      case AppLocaleCode.uz:
        return kStringsUz;
    }
  }
}

/// `BuildContext.tr('key')` shortcut'i — `Text(context.tr('common.refresh'))`.
extension TrContextX on BuildContext {
  String tr(String key, [Map<String, Object?>? params]) =>
      I18n.instance.tr(key, params);
}

/// State'ga aralashtirib qo'shilganda — I18n locale o'zgarganda widget'ni
/// avtomat qayta chizadi. Bu shartli: pushed Navigator route'lari MaterialApp
/// rebuild'idan ta'sirlanmaydi, shu mixin'siz til o'zgarishini sezmaydilar.
///
/// Foydalanish:
/// ```dart
/// class _MyPageState extends State<MyPage> with I18nObserverMixin<MyPage> {
///   ...
/// }
/// ```
mixin I18nObserverMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    I18n.instance.addListener(_onI18nChanged);
  }

  @override
  void dispose() {
    I18n.instance.removeListener(_onI18nChanged);
    super.dispose();
  }

  void _onI18nChanged() {
    if (mounted) setState(() {});
  }
}
