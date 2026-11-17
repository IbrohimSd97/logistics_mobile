import 'package:flutter/services.dart';

/// Haydovchilik guvohnomasi bitta maydonda: "AF 1234567".
///
/// Avval 2 ta lotin harfi (katta harfga o'tadi, kirill lotinga o'giriladi),
/// so'ng bo'sh joy o'zi qo'yiladi va 7 ta raqam. Serverga seriya va raqam
/// alohida ketadi — [LicenseInputFormatter.split] bilan ajratiladi.
class LicenseInputFormatter extends TextInputFormatter {
  static const _cyr = {
    'А': 'A',
    'В': 'B',
    'Е': 'E',
    'К': 'K',
    'М': 'M',
    'Н': 'H',
    'О': 'O',
    'Р': 'P',
    'С': 'C',
    'Т': 'T',
    'Х': 'X',
    'У': 'Y',
    'Ф': 'F',
    'Д': 'D',
    'Г': 'G',
    'Л': 'L',
    'З': 'Z',
    'И': 'I',
    'Б': 'B',
  };

  /// (seriya, raqam)
  static (String, String) split(String text) {
    var letters = '';
    var digits = '';
    for (final c in text.toUpperCase().split('')) {
      final ch = _cyr[c] ?? c;
      if (RegExp('[A-Z]').hasMatch(ch) &&
          digits.isEmpty &&
          letters.length < 2) {
        letters += ch;
      } else if (RegExp(r'\d').hasMatch(ch) &&
          letters.length == 2 &&
          digits.length < 7) {
        digits += ch;
      }
    }
    return (letters, digits);
  }

  static String format(
    String series,
    String number, {
    bool trailingSpace = false,
  }) {
    final (l, d) = split('$series$number');
    return l +
        (l.length == 2 && (d.isNotEmpty || trailingSpace) ? ' ' : '') +
        d;
  }

  static bool isComplete(String text) {
    final (l, d) = split(text);
    return l.length == 2 && d.length == 7;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final deleting = newValue.text.length < oldValue.text.length;
    final (l, d) = split(newValue.text);
    final text = format(l, d, trailingSpace: !deleting);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
