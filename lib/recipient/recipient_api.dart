import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api/api_exception.dart';
import '../core/api/http_response_codec.dart';
import '../core/config/api_config.dart';
import '../core/i18n/i18n.dart';
import '../core/session/session_store.dart';

/// Yuk qabul qiluvchisiga ko'rinadigan buyurtma (`/api/recipient/orders`).
/// Narx va to'lov bu yerda yo'q — faqat yuk, haydovchi va holat.
class RecipientOrder {
  const RecipientOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.canFinish,
    required this.trackable,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.cargoWeightKg,
    this.cargoType,
    this.comment,
    this.senderName,
    this.driverName,
    this.driverPhone,
    this.vehicleName,
    this.plateNumber,
  });

  final int id;
  final String orderNumber;
  final int status;
  final bool canFinish;
  final bool trackable;
  final String pickupAddress;
  final String deliveryAddress;
  final double pickupLat;
  final double pickupLng;
  final double deliveryLat;
  final double deliveryLng;
  final double cargoWeightKg;
  final String? cargoType;
  final String? comment;
  final String? senderName;
  final String? driverName;
  final String? driverPhone;
  final String? vehicleName;
  final String? plateNumber;

  /// Hali yakunlanmagan / bekor qilinmagan.
  bool get isActive => status < 10;

  static RecipientOrder? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = int.tryParse('${raw['id']}');
    if (id == null) return null;
    double d(Object? v) => double.tryParse('$v') ?? 0;
    String? s(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty || t == 'null' ? null : t;
    }

    final pickup = raw['pickup'] is Map ? raw['pickup'] as Map : const {};
    final delivery = raw['delivery'] is Map ? raw['delivery'] as Map : const {};
    final driver = raw['driver'] is Map ? raw['driver'] as Map : const {};
    final vehicle = raw['vehicle'] is Map ? raw['vehicle'] as Map : const {};
    return RecipientOrder(
      id: id,
      orderNumber: s(raw['order_number']) ?? '$id',
      status: int.tryParse('${raw['status']}') ?? 0,
      canFinish: raw['can_finish'] == true,
      trackable: raw['trackable'] == true,
      pickupAddress: s(raw['pickup_address']) ?? '',
      deliveryAddress: s(raw['delivery_address']) ?? '',
      pickupLat: d(pickup['lat']),
      pickupLng: d(pickup['lng']),
      deliveryLat: d(delivery['lat']),
      deliveryLng: d(delivery['lng']),
      cargoWeightKg: d(raw['cargo_weight_kg']),
      cargoType: s(raw['cargo_type']),
      comment: s(raw['comment']),
      senderName: s(raw['sender_name']),
      driverName: s(driver['name']),
      driverPhone: s(driver['phone']),
      vehicleName: s(vehicle['name']),
      plateNumber: s(vehicle['plate_number']),
    );
  }
}

class RecipientDriverLocation {
  const RecipientDriverLocation({required this.latitude, required this.longitude, required this.ageSeconds});

  final double latitude;
  final double longitude;
  final int ageSeconds;
}

/// Qabul qiluvchining STIR/PINFL bo'yicha nomi (buyurtma formasida).
class RecipientLookup {
  const RecipientLookup({required this.status, this.name, this.message});

  /// found | not_found | unavailable
  final String status;
  final String? name;
  final String? message;

  bool get found => status == 'found' && (name ?? '').isNotEmpty;
}

class RecipientApi {
  RecipientApi._();
  static final RecipientApi instance = RecipientApi._();

  final _session = SessionStore();

  Future<Map<String, String>> _headers() async {
    final t = await _session.getRefreshToken();
    if (t == null || t.isEmpty) throw ApiException('Kirish sessiyasi yo‘q. Qayta kiring.');
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Accept-Language': I18n.instance.code,
      'Authorization': 'Bearer $t',
    };
  }

  Uri _url(String path) => Uri.parse('${ApiConfig.baseUrl}/api/recipient/orders$path');

  /// GET /api/recipient/orders — shu raqamga yuborilgan yuklar (yangisi birinchi).
  Future<List<RecipientOrder>> orders() async {
    final res = await http.get(_url(''), headers: await _headers());
    final data = decodeJsonEnvelopeOrThrow(res)['data'];
    return data is List ? data.map(RecipientOrder.fromMap).whereType<RecipientOrder>().toList() : const [];
  }

  Future<RecipientOrder> order(int id) async {
    final res = await http.get(_url('/$id'), headers: await _headers());
    return RecipientOrder.fromMap(decodeJsonEnvelopeOrThrow(res)['data']) ?? (throw ApiException('Javobda data yo‘q'));
  }

  /// Haydovchi joylashuvi — yuk yo'lda bo'lmasa yoki hali yo'q bo'lsa null.
  Future<RecipientDriverLocation?> driverLocation(int id) async {
    final res = await http.get(_url('/$id/driver-location'), headers: await _headers());
    if (res.statusCode == 404) return null;
    final data = decodeJsonEnvelopeOrThrow(res)['data'];
    if (data is! Map) return null;
    final lat = double.tryParse('${data['latitude']}');
    final lng = double.tryParse('${data['longitude']}');
    if (lat == null || lng == null) return null;
    return RecipientDriverLocation(latitude: lat, longitude: lng, ageSeconds: int.tryParse('${data['age_seconds']}') ?? 0);
  }

  /// POST /api/recipient/orders/{id}/finish — "Qabul qildim".
  Future<RecipientOrder> finish(int id) async {
    final res = await http.post(_url('/$id/finish'), headers: await _headers());
    return RecipientOrder.fromMap(decodeJsonEnvelopeOrThrow(res)['data']) ?? (throw ApiException('Javobda data yo‘q'));
  }

  /// POST /api/customer/recipient-lookup — buyurtma formasi uchun.
  Future<RecipientLookup> lookup(String tin) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/customer/recipient-lookup'),
      headers: await _headers(),
      body: jsonEncode({'tin': tin}),
    );
    final map = decodeJsonEnvelopeOrThrow(res);
    final data = map['data'];
    final recipient = data is Map ? data['recipient'] : null;
    return RecipientLookup(
      status: data is Map ? '${data['status']}' : 'unavailable',
      name: recipient is Map ? recipient['name']?.toString() : null,
      message: map['message']?.toString(),
    );
  }
}
