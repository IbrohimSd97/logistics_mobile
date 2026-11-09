import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/i18n/i18n.dart';
import 'package:mening_ilovam/driver/pages/driver_registration_step3_page.dart';

/// 3-bosqichda yuridik shakl (YATT / yuridik shaxs) va guvohnoma so'ralmaydi:
/// server ularni 1-bosqichdagi JShShIR (YATT) yoki STIR (yuridik shaxs)
/// dan aniqlaydi.
void main() {
  testWidgets('yuridik holat tanlovi va guvohnoma yuklash yo\'q', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DriverRegistrationStep3Page(
        sessionId: 'test-session',
        phoneDisplay: '+998 90 000 00 00',
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(I18n.t('driver.reg.legal_title')), findsNothing);
    expect(find.text(I18n.t('driver.reg.legal_yatt')), findsNothing);
    expect(find.text(I18n.t('driver.reg.legal_entity')), findsNothing);
    expect(find.text(I18n.t('driver.reg.legal_pdf')), findsNothing);
    // Egalik va avtopark qoladi.
    expect(find.text(I18n.t('driver.reg.ownership_title')), findsOneWidget);
    expect(find.text(I18n.t('driver.reg.avtopark_title')), findsOneWidget);
  });
}
