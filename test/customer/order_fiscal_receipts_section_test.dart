import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mening_ilovam/core/theme/app_theme.dart';
import 'package:mening_ilovam/customer/customer_models.dart';
import 'package:mening_ilovam/customer/widgets/order_fiscal_receipts_section.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _receipt({
  required int id,
  required int type,
  String status = 'accepted',
  String? qr,
}) =>
    {
      'id': id,
      'receipt_type': type,
      'is_refund': false,
      'status': status,
      'receipt_seq': 1840 + id,
      'terminal_id': status == 'accepted' ? 'UZ191211502383' : null,
      'fiscal_sign': type == 0 && status == 'accepted' ? '381602947215' : null,
      'qr_code_url': qr,
      'amount': 1450000,
      'issued_at': '2026-09-30T05:15:00Z',
    };

http.Response _ok(List<Map<String, dynamic>> items) => http.Response(
      jsonEncode({
        'success': true,
        'data': {'order_id': 7, 'items': items},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

Widget _host() => MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: OrderFiscalReceiptsSection(orderId: 7),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'alix_refresh_token': 'test-token',
      'alix_user_id': 1,
      'alix_user_type': 'customer',
    });
  });

  group('OrderFiscalReceipt.fromMap', () {
    test('parses accepted sale with QR', () {
      final r = OrderFiscalReceipt.fromMap(_receipt(id: 2, type: 0, qr: 'https://ofd/x'))!;
      expect(r.receiptType, 0);
      expect(r.isAccepted, isTrue);
      expect(r.hasQr, isTrue);
      expect(r.amount, 1450000);
      expect(r.fiscalSign, '381602947215');
    });

    test('pending receipt has no QR even if url present', () {
      final r = OrderFiscalReceipt.fromMap(_receipt(id: 3, type: 2, status: 'pending', qr: 'https://ofd/y'))!;
      expect(r.isPending, isTrue);
      expect(r.hasQr, isFalse);
    });

    test('missing id → null, empty strings → null', () {
      expect(OrderFiscalReceipt.fromMap({'status': 'accepted'}), isNull);
      final r = OrderFiscalReceipt.fromMap({'id': '5', 'qr_code_url': '', 'is_refund': 1})!;
      expect(r.id, 5);
      expect(r.qrCodeUrl, isNull);
      expect(r.isRefund, isTrue);
    });
  });

  testWidgets('sends bearer token to the right endpoint and lists receipts', (tester) async {
    late http.Request seen;
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
    }, () => MockClient((req) async {
          seen = req;
          return _ok([
            _receipt(id: 1, type: 1, qr: 'https://ofd/1'),
            _receipt(id: 2, type: 0, qr: 'https://ofd/2'),
            _receipt(id: 3, type: 2, qr: 'https://ofd/3'),
          ]);
        }));

    expect(seen.method, 'GET');
    expect(seen.url.path, '/api/customer/orders/7/fiscal-receipts');
    expect(seen.headers['Authorization'], 'Bearer test-token');
    expect(find.text('Avans cheki'), findsOneWidget);
    expect(find.text('Sotuv cheki'), findsOneWidget);
    expect(find.text('Kredit cheki'), findsOneWidget);
    expect(find.text('Qabul qilindi'), findsNWidgets(3));
    expect(find.textContaining('1 450 000'), findsNWidgets(3));
  });

  testWidgets('tapping accepted receipt opens QR sheet with fiscal data', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sotuv cheki'));
      await tester.pumpAndSettle();
    }, () => MockClient((_) async => _ok([_receipt(id: 2, type: 0, qr: 'https://ofd.soliq.uz/epi?r=2')])));

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr, isNotNull);
    expect(find.text('381602947215'), findsOneWidget);
    expect(find.text('UZ191211502383'), findsOneWidget);
    expect(find.text('Soliq saytida ochish'), findsOneWidget);
  });

  testWidgets('pending receipt is not tappable and polling picks up acceptance', (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('Yuborilmoqda'), findsOneWidget);
      await tester.tap(find.text('Sotuv cheki'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);

      // 5 soniyadan keyin qayta so'raladi — endi accepted.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Qabul qilindi'), findsOneWidget);
      expect(find.text('Yuborilmoqda'), findsNothing);

      // Hammasi accepted — boshqa so'rov yuborilmaydi.
      final before = calls;
      await tester.pump(const Duration(seconds: 30));
      expect(calls, before);
    }, () => MockClient((_) async {
          calls++;
          return _ok([
            calls == 1
                ? _receipt(id: 2, type: 0, status: 'pending')
                : _receipt(id: 2, type: 0, qr: 'https://ofd/2'),
          ]);
        }));
    expect(calls, 2);
  });

  testWidgets('empty list shows preparing hint and stops polling after the limit', (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.text('Cheklar tayyorlanmoqda…'), findsOneWidget);

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
      }
      expect(find.textContaining('hali shakllanmagan'), findsOneWidget);
    }, () => MockClient((_) async {
          calls++;
          return _ok(const []);
        }));
    // 1 ta boshlang'ich + 24 ta polling.
    expect(calls, 25);
  });

  testWidgets('server error is shown and refresh button retries', (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Sotuv cheki'), findsOneWidget);
    }, () => MockClient((_) async {
          calls++;
          if (calls == 1) {
            return http.Response(
              jsonEncode({'success': false, 'error': {'code': 'server_error', 'message': 'Server xatosi'}}),
              500,
              headers: {'content-type': 'application/json'},
            );
          }
          return _ok([_receipt(id: 2, type: 0, qr: 'https://ofd/2')]);
        }));
    expect(calls, 2);
  });

  testWidgets('disposing while a poll is scheduled does not throw', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 10));
    }, () => MockClient((_) async => _ok([_receipt(id: 2, type: 0, status: 'pending')])));
    expect(tester.takeException(), isNull);
  });
}
