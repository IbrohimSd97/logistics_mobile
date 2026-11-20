import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/orders/cargo_size_text.dart';

void main() {
  test('formatVolumeM3 trims trailing zeros', () {
    expect(formatVolumeM3(12), '12');
    expect(formatVolumeM3(12.5), '12.5');
    expect(formatVolumeM3(0.25), '0.25');
  });

  test('cargoSizeText adds volume only when present', () {
    expect(cargoSizeText(500, null), contains('500'));
    expect(cargoSizeText(500, null), isNot(contains('m³')));
    expect(cargoSizeText(500, 12.5), endsWith('· 12.5 m³'));
  });
}
