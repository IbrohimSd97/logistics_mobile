import 'package:flutter/services.dart';

/// Mashina davlat raqami turi. Faqat O'zbekiston jismoniy shaxs raqami emas —
/// yuridik shaxs, davlat, chet el fuqarosi va xorijda ro'yxatdan o'tgan
/// mashinalar ham qabul qilinadi.
enum PlateKind {
  /// O'zbekiston, jismoniy shaxs: `01 A 123 BC`.
  uzIndividual,

  /// O'zbekiston, yuridik shaxs: `01 123 ABC`.
  uzLegal,

  /// Boshqa: davlat, diplomatik, chet el fuqarosi yoki xorijiy raqam —
  /// formati turlicha, shuning uchun erkin kiritiladi.
  other;

  /// Niqob: `D` — raqam, `L` — harf. [other] uchun niqob yo'q.
  String? get mask => switch (this) {
        PlateKind.uzIndividual => 'DDLDDDLL',
        PlateKind.uzLegal => 'DDDDDLLL',
        PlateKind.other => null,
      };

  /// Saqlangan raqamdan turini aniqlaydi (qayta yuborishda prefill uchun).
  static PlateKind detect(String? plate) {
    final p = normalize(plate ?? '', PlateKind.uzIndividual);
    if (_individual.hasMatch(p)) return PlateKind.uzIndividual;
    if (_legal.hasMatch(p)) return PlateKind.uzLegal;
    if ((plate ?? '').trim().isEmpty) return PlateKind.uzIndividual;
    return PlateKind.other;
  }

  TextInputFormatter get formatter =>
      mask == null ? const _FreePlateFormatter() : _MaskedPlateFormatter(mask!);

  /// Serverga yuboriladigan ko'rinish: O'zbekiston raqamlari bo'shliqsiz
  /// (`01A123BC`), boshqalari katta harf bilan, ortiqcha bo'shliqlarsiz.
  static String normalize(String raw, PlateKind kind) {
    final up = raw.toUpperCase().trim();
    if (kind == PlateKind.other) return up.replaceAll(RegExp(r'\s+'), ' ');
    return up.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// To'liq va to'g'ri kiritilganmi. Xato bo'lsa — tarjima kaliti.
  String? validate(String raw) {
    final p = normalize(raw, this);
    if (p.isEmpty) return 'driver.reg.field_required_short';
    final ok = switch (this) {
      PlateKind.uzIndividual => _individual.hasMatch(p),
      PlateKind.uzLegal => _legal.hasMatch(p),
      PlateKind.other => _otherOk(p),
    };
    return ok ? null : 'driver.reg.plate_invalid';
  }

  static final _individual = RegExp(r'^\d{2}[A-Z]\d{3}[A-Z]{2}$');
  static final _legal = RegExp(r'^\d{5}[A-Z]{3}$');

  static bool _otherOk(String p) {
    final compact = p.replaceAll(RegExp(r'[\s-]'), '');
    return compact.length >= 3 &&
        compact.length <= 15 &&
        RegExp(r'\d').hasMatch(compact);
  }
}

/// O'zbekiston raqami niqobi: har pozitsiyada faqat raqam yoki faqat harf.
class _MaskedPlateFormatter extends TextInputFormatter {
  const _MaskedPlateFormatter(this.mask);

  final String mask;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    final buf = StringBuffer();
    for (var i = 0; i < raw.length && buf.length < mask.length; i++) {
      final c = raw[i];
      final isDigit = c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
      if ((mask[buf.length] == 'D') == isDigit) buf.write(c);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Erkin raqam: lotin/kirill harflari, raqam, bo'sh joy va tire; katta harf.
class _FreePlateFormatter extends TextInputFormatter {
  const _FreePlateFormatter();

  static const _maxLength = 20; // backend: plate_number max:20

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9А-ЯЁЎҚҒҲ \-]'), '')
        .replaceAll(RegExp(r' {2,}'), ' ');
    if (text.length > _maxLength) text = text.substring(0, _maxLength);
    final offset = newValue.selection.baseOffset.clamp(0, text.length);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }
}
