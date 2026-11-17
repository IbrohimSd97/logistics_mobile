import 'package:flutter/services.dart';

/// Hujjat seriyasi va raqami bitta maydonda: harflar, bo'sh joy (o'zi qo'yiladi),
/// raqamlar. Kichik harf kattaga o'tadi, kirill lotinga o'giriladi. Serverga
/// seriya va raqam alohida ketadi — [split] bilan ajratiladi.
///
///   - haydovchilik guvohnomasi: [SeriesNumberFormatter.license] → "AF 1234567"
///   - texpasport: [SeriesNumberFormatter.techPassport] → "AAF 1234567"
class SeriesNumberFormatter extends TextInputFormatter {
  const SeriesNumberFormatter({this.letters = 2, this.digits = 7});

  static const license = SeriesNumberFormatter();
  static const techPassport = SeriesNumberFormatter(letters: 3);

  final int letters;
  final int digits;

  static const _cyr = {
    'А': 'A', 'В': 'B', 'Е': 'E', 'К': 'K', 'М': 'M', 'Н': 'H', 'О': 'O', 'Р': 'P', 'С': 'C',
    'Т': 'T', 'Х': 'X', 'У': 'Y', 'Ф': 'F', 'Д': 'D', 'Г': 'G', 'Л': 'L', 'З': 'Z', 'И': 'I', 'Б': 'B',
  };

  String get hint => '${'A' * letters} ${List.generate(digits, (i) => '${(i + 1) % 10}').join()}';

  /// (seriya, raqam)
  (String, String) split(String text) {
    var l = '';
    var d = '';
    for (final c in text.toUpperCase().split('')) {
      final ch = _cyr[c] ?? c;
      if (RegExp('[A-Z]').hasMatch(ch) && d.isEmpty && l.length < letters) {
        l += ch;
      } else if (RegExp(r'\d').hasMatch(ch) && l.length == letters && d.length < digits) {
        d += ch;
      }
    }
    return (l, d);
  }

  String format(String series, String number, {bool trailingSpace = false}) {
    final (l, d) = split('$series$number');
    return l + (l.length == letters && (d.isNotEmpty || trailingSpace) ? ' ' : '') + d;
  }

  bool isComplete(String text) {
    final (l, d) = split(text);
    return l.length == letters && d.length == digits;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final deleting = newValue.text.length < oldValue.text.length;
    final (l, d) = split(newValue.text);
    final text = format(l, d, trailingSpace: !deleting);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
