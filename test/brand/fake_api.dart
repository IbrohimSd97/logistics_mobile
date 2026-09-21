import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brend ko'rinish namunalari uchun soxta backend.
///
/// Ekranlar haqiqiy kod bilan (API → model → widget) chiziladi, faqat tarmoq
/// javoblari shu yerdan beriladi. Shu tufayli namunalar UI'ning haqiqiy
/// holatini ko'rsatadi, qo'lda yig'ilgan maket emas.
Future<T> withFakeApi<T>(Future<T> Function() body) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'alix_refresh_token': 'preview-token',
    'alix_user_id': 1,
    'alix_user_type': 'customer',
    'alix_phone_display': '+998 90 000 00 00',
  });
  return http.runWithClient(body, () => MockClient(_handle));
}

Future<http.Response> _handle(http.Request request) async {
  final path = request.url.path;
  final body = switch (path) {
    _ when path.endsWith('/orders/current-orders') => {'data': _currentOrders},
    _ when path.endsWith('/orders/archive-list') => {'data': _archiveOrders},
    _ when path.endsWith('/customer/wallet') => {'data': _wallet},
    _ when path.endsWith('/wallet/transactions') => {'data': _transactions},
    _ when path.endsWith('/wallet/topup/history') => {'data': <dynamic>[]},
    _ => {'data': <dynamic>[]},
  };
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}

const _currentOrders = [
  {
    'id': 20481,
    'order_number': 'AX-20481',
    'status': 6, // yo'lda
    'total_price': '1450000',
    'currency': 'UZS',
    'pickup_address': 'Toshkent, Yunusobod tumani, Amir Temur 108',
    'delivery_address': 'Almaty, Abay ko\'chasi 52',
    'created_at': '2026-09-20T08:12:00Z',
    'accepted_at': '2026-09-20T09:03:00Z',
    'cargo_weight_kg': 1800,
  },
  {
    'id': 20486,
    'order_number': 'AX-20486',
    'status': 2, // haydovchi qidirilmoqda
    'total_price': '380000',
    'currency': 'UZS',
    'pickup_address': 'Toshkent, Chilonzor 9-kvartal',
    'delivery_address': 'Samarqand, Registon ko\'chasi 14',
    'created_at': '2026-09-21T06:40:00Z',
    'scheduled_pickup_at': '2026-09-24T07:00:00Z',
  },
];

const _archiveOrders = [
  {
    'id': 20390,
    'order_number': 'AX-20390',
    'status': 10, // yakunlangan
    'total_price': '920000',
    'currency': 'UZS',
    'pickup_address': 'Toshkent, Sergeli logistika markazi',
    'delivery_address': 'Buxoro, Sanoat zonasi 4',
    'created_at': '2026-09-12T05:10:00Z',
    'completed_at': '2026-09-13T14:25:00Z',
  },
];

const _wallet = {
  'balance': '2450000',
  'blocked_amount': '380000',
  'currency': 'UZS',
};

const _transactions = [
  {
    'id': 1,
    'transaction_type': 1,
    'amount': '1000000',
    'created_at': '2026-09-20T10:00:00Z',
  },
  {
    'id': 2,
    'transaction_type': 3,
    'amount': '380000',
    'created_at': '2026-09-21T06:41:00Z',
  },
];
