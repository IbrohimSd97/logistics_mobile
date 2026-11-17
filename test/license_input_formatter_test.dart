import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/forms/license_input_formatter.dart';

void main() {
  final f = LicenseInputFormatter();
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
    expect(LicenseInputFormatter.split('AF 1234567'), ('AF', '1234567'));
    expect(LicenseInputFormatter.isComplete('AF 123456'), isFalse);
    expect(LicenseInputFormatter.format('af', '1234567'), 'AF 1234567');
  });
}
