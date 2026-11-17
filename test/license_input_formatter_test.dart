import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/forms/license_input_formatter.dart';

void main() {
  const f = SeriesNumberFormatter.license;
  String typeAll(String s) {
    var v = TextEditingValue.empty;
    for (final ch in s.split('')) {
      v = f.formatEditUpdate(v, TextEditingValue(text: v.text + ch));
    }
    return v.text;
  }

  test('harf, keyin bo\'sh joy, keyin 7 ta raqam', () {
    expect(typeAll('af'), 'AF ');
    expect(typeAll('af12345678'), 'AF 1234567');
    expect(typeAll('1af'), 'AF ');
    expect(typeAll('аф9'), 'AF 9');
    expect(f.split('AF 1234567'), ('AF', '1234567'));
    expect(f.isComplete('AF 123456'), isFalse);
    expect(f.format('af', '1234567'), 'AF 1234567');
  });

  test('texpasport: 3 harf + 7 raqam', () {
    const t = SeriesNumberFormatter.techPassport;
    var v = TextEditingValue.empty;
    for (final ch in 'aaf12345678'.split('')) {
      v = t.formatEditUpdate(v, TextEditingValue(text: v.text + ch));
    }
    expect(v.text, 'AAF 1234567');
    expect(t.split(v.text), ('AAF', '1234567'));
    expect(t.hint, 'AAA 1234567');
  });
}
