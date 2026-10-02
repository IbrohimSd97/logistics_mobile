import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/phone/phone_country.dart';

String fmt(PhoneCountry c, String input) =>
    c.formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: input)).text;

void main() {
  final uz = PhoneCountry.uz;
  final kz = PhoneCountry.byIso('KZ');
  final ru = PhoneCountry.byIso('RU');
  final tm = PhoneCountry.byIso('TM');

  test('API raqami: kod + milliy qism (mavjud 998... formati saqlanadi)', () {
    expect(uz.toApi('90 123 45 67'), '998901234567');
    expect(kz.toApi('7011234567'), '77011234567');
    expect(tm.toApi('65123456'), '99365123456');
  });

  test('to‘liqlik — davlat uzunligi bo‘yicha', () {
    expect(uz.isComplete('901234567'), isTrue);
    expect(uz.isComplete('90123456'), isFalse);
    expect(tm.isComplete('65123456'), isTrue);
    expect(PhoneCountry.byIso('DE').isComplete('15123456789'), isTrue); // 11
    expect(PhoneCountry.byIso('DE').isComplete('1512345678'), isTrue); // 10
  });

  test('formatter: faqat raqam, uzunlik chegarasi', () {
    expect(fmt(uz, '90-123 45 67'), '901234567');
    expect(fmt(uz, '9012345678999'), '901234567');
    expect(fmt(tm, '651234567'), '65123456');
  });

  test('to‘liq raqam joylansa davlat kodi tashlanadi', () {
    expect(fmt(uz, '+998 90 123 45 67'), '901234567');
    expect(fmt(ru, '+7 912 345 67 89'), '9123456789');
    expect(fmt(uz, '0901234567'), '901234567'); // ichki 0 bilan
  });

  test('byIso noma‘lum bo‘lsa O‘zbekiston; bayroq', () {
    expect(PhoneCountry.byIso('XX').iso, 'UZ');
    expect(PhoneCountry.byIso(null).iso, 'UZ');
    expect(uz.flag, '🇺🇿');
  });

  test('KZ va RU ikkalasi ham +7 — ro‘yxatda alohida', () {
    expect(kz.dial, ru.dial);
    expect(PhoneCountry.all.where((c) => c.dial == '7').length, 2);
  });
}
