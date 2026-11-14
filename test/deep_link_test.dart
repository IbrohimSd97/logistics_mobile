import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/links/deep_link_service.dart';

void main() {
  const t = 'Ab12Cd34Ef56Gh78Ij90Kl12Mn34Op56Qr78St90';
  test('parses https and custom scheme tracking links', () {
    expect(DeepLinkService.recipientToken(Uri.parse('https://admin.alix.uz/t/$t')), t);
    expect(DeepLinkService.recipientToken(Uri.parse('https://admin.alix.uz/t/$t?lang=ru')), t);
    expect(DeepLinkService.recipientToken(Uri.parse('alix://t/$t')), t);
    expect(DeepLinkService.recipientToken(Uri.parse('https://admin.alix.uz/admin/login')), isNull);
    expect(DeepLinkService.recipientToken(Uri.parse('alix://t/short')), isNull);
  });
}
