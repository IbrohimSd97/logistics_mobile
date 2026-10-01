import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Do'kon screenshotlari uchun soxta backend. Ekranlar haqiqiy kod bilan
/// (API → model → widget) chiziladi; javoblar `Accept-Language` bo'yicha
/// o'zbek yoki rus tilida beriladi.
Future<T> withStoreApi<T>({required String userType, required Future<T> Function() body}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'alix_refresh_token': 'store-token',
    'alix_user_id': userType == 'driver' ? 7 : 1,
    'alix_user_type': userType,
    'alix_phone_display': '+998 90 123 45 67',
  });
  return http.runWithClient(body, () => MockClient(_handle));
}

Future<http.Response> _handle(http.Request request) async {
  final ru = (request.headers['Accept-Language'] ?? 'uz').startsWith('ru');
  final p = request.url.path;
  final Object? data = switch (p) {
    _ when p.endsWith('/customer/orders/current-orders') => _customerCurrent(ru),
    _ when p.endsWith('/customer/orders/archive-list') => _customerArchive(ru),
    _ when p.endsWith('/fiscal-receipts') => {'order_id': 20390, 'items': _fiscal},
    _ when p.endsWith('/customer/wallet') => _wallet,
    _ when p.endsWith('/customer/wallet/billing-info') => {'is_company_staff': false},
    _ when p.endsWith('/wallet/transactions') => _transactions(ru),
    _ when p.endsWith('/wallet/topup/history') => <dynamic>[],
    _ when p.endsWith('/cargo-types') => _cargoTypes(ru),
    _ when p.endsWith('/customer/me') => _me,
    _ when p.endsWith('/driver/registration/status') => {'user_id': 7, 'driver_id': 7, 'status': 4, 'next_step': 5},
    _ when p.endsWith('/driver/me/status') => {'is_online': true, 'cargo_type_ids': [1, 2, 3], 'went_online_at': '2026-10-01T04:00:00Z'},
    _ when p.endsWith('/driver/orders/current-order') => null,
    _ when p.endsWith('/driver/orders/active-list') => _driverFeed(ru),
    _ when p.endsWith('/driver/orders/scheduled-list') => _driverScheduled(ru),
    _ when p.endsWith('/driver/orders/archive-list') => <dynamic>[],
    _ when p.endsWith('/driver/wallet') => {'balance': '3870000', 'blocked_amount': '0', 'currency': 'UZS'},
    _ => <dynamic>[],
  };
  return http.Response(
    jsonEncode({'success': true, 'data': data}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

String _a(bool ru, String uz, String r) => ru ? r : uz;

Map<String, dynamic> _cargo(bool ru, int id) => {
      'id': id,
      'name': switch (id) {
        1 => _a(ru, 'Konteyner', 'Контейнер'),
        2 => _a(ru, 'Tentli yuk', 'Тентованный груз'),
        3 => _a(ru, 'Refrijerator', 'Рефрижератор'),
        _ => _a(ru, 'Qurilish materiallari', 'Стройматериалы'),
      },
      'pickup_free_wait_minutes': 60,
      'pickup_paid_wait_price': '50000',
      'pickup_paid_wait_interval_min': 30,
      'delivery_free_wait_minutes': 60,
      'delivery_paid_wait_price': '50000',
      'delivery_paid_wait_interval_min': 30,
      'late_penalty_per_hour': '25000',
    };

List<Map<String, dynamic>> _cargoTypes(bool ru) => [for (final id in [1, 2, 3, 4]) _cargo(ru, id)];

List<Map<String, dynamic>> _customerCurrent(bool ru) => [
      {
        'id': 20481,
        'order_number': 'AX-20481',
        'status': 6,
        'total_price': '1450000',
        'currency': 'UZS',
        'pickup_address': _a(ru, 'Toshkent, Yunusobod, Amir Temur 108', 'Ташкент, Юнусабад, Амир Темур 108'),
        'pickup_lat': 41.3650,
        'pickup_lng': 69.2870,
        'delivery_address': _a(ru, 'Samarqand, Registon ko\'chasi 14', 'Самарканд, ул. Регистан 14'),
        'delivery_lat': 39.6542,
        'delivery_lng': 66.9597,
        'distance_km': '298.4',
        'cargo_weight_kg': 1800,
        'cargo_type': _cargo(ru, 1),
        'created_at': '2026-09-30T05:12:00Z',
        'accepted_at': '2026-09-30T05:31:00Z',
        'arrived_pickup_at': '2026-09-30T06:05:00Z',
        'loading_started_at': '2026-09-30T06:10:00Z',
        'in_transit_at': '2026-09-30T06:48:00Z',
        'delivery_deadline_at': '2026-09-30T18:48:00Z',
        'sla_hours_snapshot': 12,
      },
      {
        'id': 20486,
        'order_number': 'AX-20486',
        'status': 2,
        'total_price': '380000',
        'currency': 'UZS',
        'pickup_address': _a(ru, 'Toshkent, Chilonzor 9-kvartal', 'Ташкент, Чиланзар 9-квартал'),
        'delivery_address': _a(ru, 'Toshkent, Sergeli logistika markazi', 'Ташкент, Сергелийский логистический центр'),
        'distance_km': '14.2',
        'cargo_weight_kg': 450,
        'cargo_type': _cargo(ru, 2),
        'created_at': '2026-09-30T07:40:00Z',
      },
    ];

List<Map<String, dynamic>> _customerArchive(bool ru) => [
      {
        'id': 20390,
        'order_number': 'AX-20390',
        'status': 10,
        'total_price': '920000',
        'currency': 'UZS',
        'pickup_address': _a(ru, 'Toshkent, Sergeli logistika markazi', 'Ташкент, Сергелийский логистический центр'),
        'delivery_address': _a(ru, 'Buxoro, Sanoat zonasi 4', 'Бухара, Промзона 4'),
        'cargo_weight_kg': 2400,
        'cargo_type': _cargo(ru, 2),
        'created_at': '2026-09-27T05:10:00Z',
        'accepted_at': '2026-09-27T05:22:00Z',
        'completed_at': '2026-09-27T14:25:00Z',
      },
      {
        'id': 20344,
        'order_number': 'AX-20344',
        'status': 10,
        'total_price': '640000',
        'currency': 'UZS',
        'pickup_address': _a(ru, 'Toshkent, Mirzo Ulug\'bek, Buyuk Ipak yo\'li 52', 'Ташкент, Мирзо Улугбек, Буюк Ипак йули 52'),
        'delivery_address': _a(ru, 'Andijon, Navoiy shoh ko\'chasi 7', 'Андижан, пр. Навои 7'),
        'cargo_weight_kg': 900,
        'cargo_type': _cargo(ru, 3),
        'created_at': '2026-09-24T03:00:00Z',
        'accepted_at': '2026-09-24T03:12:00Z',
        'completed_at': '2026-09-24T11:40:00Z',
      },
    ];

const _fiscal = [
  {
    'id': 302,
    'receipt_type': 0,
    'is_refund': false,
    'status': 'accepted',
    'receipt_seq': 1842,
    'terminal_id': 'UZ191211502383',
    'fiscal_sign': '381602947215',
    'qr_code_url': 'https://ofd.soliq.uz/epi?t=UZ191211502383&r=1842&c=20260927192500&s=381602947215',
    'amount': 920000,
    'issued_at': '2026-09-27T14:25:00Z',
  },
];

const _wallet = {'balance': '4750000', 'blocked_amount': '380000', 'currency': 'UZS'};

const _me = {
  'id': 1,
  'first_name': 'Aziz',
  'last_name': 'Karimov',
  'middle_name': 'Anvarovich',
  'phone_number': '+998901234567',
};

List<Map<String, dynamic>> _transactions(bool ru) => [
      {
        'id': 5,
        'transaction_type': 2,
        'amount': '-1450000',
        'order_id': 20481,
        'description': _a(ru, 'Buyurtma to\'lovi #AX-20481', 'Оплата заказа #AX-20481'),
        'created_at': '2026-09-30T05:31:00Z',
      },
      {
        'id': 4,
        'transaction_type': 1,
        'amount': '3000000',
        'description': _a(ru, 'Karta orqali to\'ldirish', 'Пополнение с карты'),
        'created_at': '2026-09-29T12:04:00Z',
      },
      {
        'id': 3,
        'transaction_type': 2,
        'amount': '-920000',
        'order_id': 20390,
        'description': _a(ru, 'Buyurtma to\'lovi #AX-20390', 'Оплата заказа #AX-20390'),
        'created_at': '2026-09-27T05:22:00Z',
      },
      {
        'id': 2,
        'transaction_type': 1,
        'amount': '5000000',
        'description': _a(ru, 'Karta orqali to\'ldirish', 'Пополнение с карты'),
        'created_at': '2026-09-20T10:00:00Z',
      },
    ];

Map<String, dynamic> _feedOrder(bool ru, int id, String price, String km, int kg, int cargo,
        String from, String fromRu, String to, String toRu,
        {double lat = 41.2650, double lng = 69.2160}) =>
    {
      'pickup_lat': lat,
      'pickup_lng': lng,
      'id': id,
      'order_number': 'AX-$id',
      'status': 2,
      'total_price': price,
      'driver_income_amount': (double.parse(price) * 0.85).round().toString(),
      'currency': 'UZS',
      'pickup_address': _a(ru, from, fromRu),
      'delivery_address': _a(ru, to, toRu),
      'distance_km': km,
      'cargo_weight_kg': kg,
      'cargo_type': _cargo(ru, cargo),
      'created_at': '2026-10-01T04:10:00Z',
    };

List<Map<String, dynamic>> _driverFeed(bool ru) => [
      _feedOrder(ru, 20512, '1200000', '312.0', 2200, 1, 'Toshkent, Sergeli 6-mavze', 'Ташкент, Сергели 6',
          'Samarqand, Siyob bozori', 'Самарканд, Сиабский базар', lat: 41.2290, lng: 69.2050),
      _feedOrder(ru, 20515, '560000', '118.5', 800, 2, 'Toshkent, Yashnobod, Qorasuv', 'Ташкент, Яшнабад, Карасу',
          'Guliston, Mustaqillik ko\'chasi 3', 'Гулистан, ул. Мустакиллик 3', lat: 41.3290, lng: 69.3340),
      _feedOrder(ru, 20519, '240000', '22.4', 350, 3, 'Toshkent, Chilonzor 19-kvartal', 'Ташкент, Чиланзар 19',
          'Toshkent, Bektemir sanoat zonasi', 'Ташкент, Бектемир промзона', lat: 41.2860, lng: 69.2040),
    ];

List<Map<String, dynamic>> _driverScheduled(bool ru) => [
      {
        ..._feedOrder(ru, 20530, '1850000', '545.0', 5000, 4, 'Toshkent, Olmazor, Qoraqamish', 'Ташкент, Алмазар, Каракамыш',
            'Buxoro, G\'ijduvon yo\'li 12', 'Бухара, Гиждуванская 12'),
        'scheduled_pickup_at': '2026-10-02T03:00:00Z',
      },
    ];
