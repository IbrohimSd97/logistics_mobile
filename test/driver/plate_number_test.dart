import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/driver/plate_number.dart';

String fmt(PlateKind k, String input) =>
    k.formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: input)).text;

void main() {
  group('validate', () {
    test('jismoniy shaxs: 01 A 123 BC', () {
      expect(PlateKind.uzIndividual.validate('01A123BC'), isNull);
      expect(PlateKind.uzIndividual.validate('01 a 123 bc'), isNull);
      expect(PlateKind.uzIndividual.validate('01A12'), 'driver.reg.plate_invalid'); // to'liq emas
      expect(PlateKind.uzIndividual.validate('01123ABC'), 'driver.reg.plate_invalid');
    });

    test('yuridik shaxs: 01 123 ABC', () {
      expect(PlateKind.uzLegal.validate('01123ABC'), isNull);
      expect(PlateKind.uzLegal.validate('01A123BC'), 'driver.reg.plate_invalid');
    });

    test('boshqa: davlat, diplomatik, chet el raqamlari', () {
      for (final p in ['01 D 123456', 'KZ 123 ABC 02', 'А123ВС 77', 'CMD 0123', '01 UN 1234', 'T 12-34']) {
        expect(PlateKind.other.validate(p), isNull, reason: p);
      }
      expect(PlateKind.other.validate('AB'), 'driver.reg.plate_invalid'); // juda qisqa
      expect(PlateKind.other.validate('ABCDEF'), 'driver.reg.plate_invalid'); // raqamsiz
      expect(PlateKind.other.validate('  '), 'driver.reg.field_required_short');
    });
  });

  test('normalize: O\'zbekiston bo\'shliqsiz, boshqasi o\'qiladigan ko\'rinishda', () {
    expect(PlateKind.normalize('01 a 123 bc', PlateKind.uzIndividual), '01A123BC');
    expect(PlateKind.normalize(' kz  123 abc 02 ', PlateKind.other), 'KZ 123 ABC 02');
  });

  test('detect: saqlangan raqamdan tur', () {
    expect(PlateKind.detect('01A123BC'), PlateKind.uzIndividual);
    expect(PlateKind.detect('01123ABC'), PlateKind.uzLegal);
    expect(PlateKind.detect('KZ 123 ABC 02'), PlateKind.other);
    expect(PlateKind.detect(null), PlateKind.uzIndividual);
  });

  test('formatter: niqob va erkin kiritish', () {
    expect(fmt(PlateKind.uzIndividual, '01a123bc99'), '01A123BC');
    expect(fmt(PlateKind.uzLegal, '01 123 abc'), '01123ABC');
    expect(fmt(PlateKind.uzLegal, '01A'), '01'); // harf raqam o'rnida — tushadi
    expect(fmt(PlateKind.other, 'kz 123 abc 02'), 'KZ 123 ABC 02');
    expect(fmt(PlateKind.other, 'а123вс 77'), 'А123ВС 77');
    expect(fmt(PlateKind.other, '12#\$%34'), '1234');
    expect(fmt(PlateKind.other, 'A' * 30).length, 20);
  });
}
