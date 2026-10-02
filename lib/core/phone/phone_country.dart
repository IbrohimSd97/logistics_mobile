import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';

/// Telefon raqami uchun davlat: xalqaro kod va milliy raqam uzunligi.
///
/// API'ga raqam avvalgidek faqat raqamlardan iborat, davlat kodi bilan
/// yuboriladi (`998901234567`, `77011234567`) — mavjud foydalanuvchilar uchun
/// hech narsa o'zgarmaydi.
class PhoneCountry {
  const PhoneCountry(this.iso, this.dial, this.nameUz, this.nameRu, this.minLen, this.maxLen, this.hint);

  /// ISO 3166-1 alpha-2 (`UZ`).
  final String iso;

  /// Xalqaro kod, `+`siz (`998`).
  final String dial;
  final String nameUz;
  final String nameRu;

  /// Milliy raqam uzunligi (davlat kodisiz).
  final int minLen;
  final int maxLen;

  /// Namuna (milliy qism).
  final String hint;

  String get name => I18n.instance.code == 'ru' ? nameRu : nameUz;

  /// Bayroq emoji — ISO koddan (regional indicator belgilar).
  String get flag => String.fromCharCodes(iso.codeUnits.map((c) => 0x1F1E6 + c - 65));

  /// Milliy raqam to'liq kiritilganmi.
  bool isComplete(String national) {
    final n = national.replaceAll(RegExp(r'\D'), '').length;
    return n >= minLen && n <= maxLen;
  }

  /// API uchun to'liq raqam: kod + milliy qism (faqat raqamlar).
  String toApi(String national) => dial + national.replaceAll(RegExp(r'\D'), '');

  TextInputFormatter get formatter => _NationalNumberFormatter(this);

  static const uz = PhoneCountry('UZ', '998', 'O‘zbekiston', 'Узбекистан', 9, 9, '90 123 45 67');

  /// Tanlov ro'yxati: O'zbekiston, Markaziy Osiyo va qo'shnilar, so'ng yuk
  /// tashishda ko'p uchraydigan davlatlar.
  static const all = <PhoneCountry>[
    uz,
    PhoneCountry('KZ', '7', 'Qozog‘iston', 'Казахстан', 10, 10, '701 123 45 67'),
    PhoneCountry('RU', '7', 'Rossiya', 'Россия', 10, 10, '912 345 67 89'),
    PhoneCountry('KG', '996', 'Qirg‘iziston', 'Кыргызстан', 9, 9, '700 123 456'),
    PhoneCountry('TJ', '992', 'Tojikiston', 'Таджикистан', 9, 9, '91 123 4567'),
    PhoneCountry('TM', '993', 'Turkmaniston', 'Туркменистан', 8, 8, '65 123456'),
    PhoneCountry('AF', '93', 'Afg‘oniston', 'Афганистан', 9, 9, '70 123 4567'),
    PhoneCountry('AZ', '994', 'Ozarbayjon', 'Азербайджан', 9, 9, '50 123 45 67'),
    PhoneCountry('GE', '995', 'Gruziya', 'Грузия', 9, 9, '555 12 34 56'),
    PhoneCountry('AM', '374', 'Armaniston', 'Армения', 8, 8, '77 123456'),
    PhoneCountry('BY', '375', 'Belarus', 'Беларусь', 9, 9, '29 123 45 67'),
    PhoneCountry('UA', '380', 'Ukraina', 'Украина', 9, 9, '50 123 4567'),
    PhoneCountry('TR', '90', 'Turkiya', 'Турция', 10, 10, '501 234 56 78'),
    PhoneCountry('IR', '98', 'Eron', 'Иран', 10, 10, '912 345 6789'),
    PhoneCountry('PK', '92', 'Pokiston', 'Пакистан', 10, 10, '301 234 5678'),
    PhoneCountry('CN', '86', 'Xitoy', 'Китай', 11, 11, '131 2345 6789'),
    PhoneCountry('IN', '91', 'Hindiston', 'Индия', 10, 10, '81234 56789'),
    PhoneCountry('AE', '971', 'BAA', 'ОАЭ', 9, 9, '50 123 4567'),
    PhoneCountry('KR', '82', 'Janubiy Koreya', 'Южная Корея', 9, 10, '10 1234 5678'),
    PhoneCountry('PL', '48', 'Polsha', 'Польша', 9, 9, '512 345 678'),
    PhoneCountry('LT', '370', 'Litva', 'Литва', 8, 8, '612 34567'),
    PhoneCountry('LV', '371', 'Latviya', 'Латвия', 8, 8, '21 234 567'),
    PhoneCountry('DE', '49', 'Germaniya', 'Германия', 10, 11, '151 2345 6789'),
    PhoneCountry('US', '1', 'AQSh', 'США', 10, 10, '201 555 0123'),
  ];

  static PhoneCountry byIso(String? iso) =>
      all.firstWhere((c) => c.iso == iso, orElse: () => uz);

  static const _prefsKey = 'alix_phone_country';

  /// Oxirgi tanlangan davlat (keyingi kirishda shu ochiladi).
  static Future<PhoneCountry> loadLast() async {
    try {
      final p = await SharedPreferences.getInstance();
      return byIso(p.getString(_prefsKey));
    } catch (_) {
      return uz;
    }
  }

  static Future<void> saveLast(PhoneCountry c) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, c.iso);
    } catch (_) {}
  }
}

/// Faqat milliy raqam: raqamlar, davlat uzunligigacha. Agar foydalanuvchi
/// raqamni to'liq (`+998 90 …`) joylasa, davlat kodi tashlab yuboriladi.
class _NationalNumberFormatter extends TextInputFormatter {
  const _NationalNumberFormatter(this.country);

  final PhoneCountry country;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > country.maxLen && digits.startsWith(country.dial)) {
      digits = digits.substring(country.dial.length);
    }
    // O'zbekistonda ichki "0 90 …" yozuvi.
    if (digits.length > country.maxLen && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > country.maxLen) digits = digits.substring(0, country.maxLen);
    return TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
  }
}

/// Davlat tanlash oynasi (qidiruv bilan). Tanlangan davlat yoki `null`.
Future<PhoneCountry?> showPhoneCountryPicker(BuildContext context, PhoneCountry current) {
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CountryPickerSheet(current: current),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.current});

  final PhoneCountry current;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _q.trim().toLowerCase().replaceAll('+', '');
    final list = PhoneCountry.all.where((c) {
      if (q.isEmpty) return true;
      return c.nameUz.toLowerCase().contains(q) ||
          c.nameRu.toLowerCase().contains(q) ||
          c.dial.startsWith(q) ||
          c.iso.toLowerCase() == q;
    }).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(I18n.t('auth.choose_country'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: I18n.t('auth.country_search'),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  final selected = c.iso == widget.current.iso;
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(c.name),
                    trailing: Text('+${c.dial}',
                        style: TextStyle(
                          color: selected ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        )),
                    selected: selected,
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
