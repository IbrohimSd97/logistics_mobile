// Ilova ishga tushishining eng asosiy tekshiruvi: birinchi kadrda brend
// splash ekrani chiziladi.
//
// `pumpAndSettle` ATAYLAB ishlatilmaydi — splashdagi progress indikatori
// cheksiz animatsiya, shuning uchun u hech qachon "settle" bo'lmaydi.

import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/brand/alix_logo.dart';
import 'package:mening_ilovam/core/brand/alix_splash.dart';
import 'package:mening_ilovam/main.dart';

void main() {
  testWidgets('App boots to the ALIX splash', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(AlixSplash), findsOneWidget);
    expect(find.byType(AlixMark), findsOneWidget);
    expect(find.text('ALIX'), findsOneWidget);
  });
}
