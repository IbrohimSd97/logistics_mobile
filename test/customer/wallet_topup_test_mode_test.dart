import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mening_ilovam/core/theme/app_theme.dart';
import 'package:mening_ilovam/customer/pages/customer_payment_webview_page.dart';
import 'package:mening_ilovam/customer/pages/customer_wallet_topup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test rejimi (bank ulanmagan): server pulni darhol yozadi — ilova bank
/// sahifasini ochmasdan sahifani yopadi va muvaffaqiyat xabarini ko'rsatadi.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'alix_refresh_token': 'test-token',
      'alix_user_id': 1,
      'alix_user_type': 'customer',
    });
  });

  http.Response json(Object body) => http.Response(
        jsonEncode({'success': true, 'data': body}),
        200,
        headers: {'content-type': 'application/json'},
      );

  testWidgets('credited init closes the page without opening the bank', (tester) async {
    final calls = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CustomerWalletTopupPage()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '250000');
      await tester.tap(find.text('To‘ldirish').last);
      await tester.pumpAndSettle();
    }, () => MockClient((req) async {
          calls.add('${req.method} ${req.url.path}');
          if (req.url.path.endsWith('/topup/init')) {
            expect(jsonDecode(req.body)['amount'], 250000);
            return json({
              'operation_id': 'test-1',
              'payment_link': null,
              'credited': true,
              'test_mode': true,
              'status': 'PAID',
              'amount': 250000,
            });
          }
          return json(<dynamic>[]);
        }));

    expect(calls, contains('POST /api/customer/wallet/topup/init'));
    expect(find.byType(CustomerPaymentWebviewPage), findsNothing);
    expect(find.byType(CustomerWalletTopupPage), findsNothing); // sahifa yopildi
    expect(find.text('To‘lov qabul qilindi, hamyon to‘ldirildi.'), findsOneWidget);
  });
}
