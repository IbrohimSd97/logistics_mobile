import '../i18n/i18n.dart';

/// Yuk o'lchami matni: "500 kg" yoki hajm kiritilgan bo'lsa "500 kg · 12.5 m³".
String cargoSizeText(int? weightKg, double? volumeM3) {
  final kg = '${weightKg ?? '—'} ${I18n.t('common.kg')}';
  if (volumeM3 == null || volumeM3 <= 0) return kg;
  return '$kg · ${formatVolumeM3(volumeM3)} m³';
}

/// 12.0 → "12", 12.50 → "12.5".
String formatVolumeM3(double v) {
  final s = v.toStringAsFixed(2);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}
