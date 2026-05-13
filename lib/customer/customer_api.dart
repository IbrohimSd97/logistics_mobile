import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api/api_exception.dart';
import '../core/api/http_response_codec.dart';
import '../core/config/api_config.dart';
import '../core/session/session_store.dart';
import 'customer_models.dart';

class CustomerApi {
  CustomerApi._();
  static final CustomerApi instance = CustomerApi._();

  final _session = SessionStore();

  Future<String> _requireBearer() async {
    final t = await _session.getRefreshToken();
    if (t == null || t.isEmpty) {
      throw ApiException('Kirish sessiyasi yo‘q. Qayta kiring.');
    }
    return t;
  }

  Map<String, String> _jsonAuth(String token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _decodeResponse(http.Response res) {
    return decodeJsonEnvelopeOrThrow(res);
  }

  /// GET /api/customer/me — driver step1 prefill uchun
  Future<CustomerProfile?> me() async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/me');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decodeResponse(res);
    return CustomerProfile.fromMap(map['data'] as Map<String, dynamic>?);
  }

  /// GET /api/customer/tariff/lists
  Future<List<TariffItem>> tariffLists() async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/tariff/lists');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decodeResponse(res);
    final data = map['data'];
    final list = mapListFrom(data is Map<String, dynamic> ? data['items'] ?? data : data);
    return list.map(TariffItem.fromMap).whereType<TariffItem>().toList();
  }

  /// POST /api/customer/orders/create — cargo_type_id (preferred) yoki tariff_id
  Future<CreateOrderResult> createOrder({
    int? cargoTypeId,
    int? tariffId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String deliveryAddress,
    required double deliveryLat,
    required double deliveryLng,
    required int cargoWeightKg,
    String? comment,
  }) async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/orders/create');
    final body = <String, dynamic>{
      if (cargoTypeId != null) 'cargo_type_id': cargoTypeId,
      if (tariffId != null) 'tariff_id': tariffId,
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'delivery_address': deliveryAddress,
      'delivery_lat': deliveryLat,
      'delivery_lng': deliveryLng,
      'cargo_weight_kg': cargoWeightKg,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };
    final res = await http.post(
      url,
      headers: _jsonAuth(token),
      body: jsonEncode(body),
    );
    final map = _decodeResponse(res);
    final data = map['data'] as Map<String, dynamic>?;
    if (data == null) throw ApiException('Javobda data yo‘q');
    final id = _int(data['order_id']);
    if (id == null) throw ApiException('order_id yo‘q');
    return CreateOrderResult(
      orderId: id,
      orderNumber: data['order_number']?.toString(),
      status: _int(data['status']),
      distanceKm: data['distance_km']?.toString(),
      basePrice: data['base_price']?.toString(),
      totalPrice: data['total_price']?.toString(),
      currency: data['currency']?.toString(),
    );
  }

  /// GET /api/customer/wallet
  Future<WalletSnapshot> wallet() async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/wallet');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decodeResponse(res);
    return WalletSnapshot.fromData(map['data']) ?? const WalletSnapshot();
  }

  /// GET /api/customer/wallet/transactions
  Future<List<WalletTransaction>> walletTransactions() async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/wallet/transactions');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decodeResponse(res);
    final list = mapListFrom(map['data']);
    return list.map(WalletTransaction.fromMap).toList();
  }

  /// GET /api/customer/orders/current-orders
  Future<List<CustomerOrder>> currentOrders() async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/orders/current-orders');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decodeResponse(res);
    final list = mapListFrom(map['data']);
    return list.map(CustomerOrder.fromMap).whereType<CustomerOrder>().toList();
  }

  /// GET /api/customer/orders/archive-list
  Future<List<CustomerOrder>> archiveOrders() async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/orders/archive-list');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decodeResponse(res);
    final list = mapListFrom(map['data']);
    return list.map(CustomerOrder.fromMap).whereType<CustomerOrder>().toList();
  }

  /// GET /api/customer/orders/{id}/documents
  Future<Map<String, dynamic>> orderDocuments(int orderId) async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/orders/$orderId/documents');
    final res = await http.get(url, headers: _jsonAuth(token));
    return _decodeResponse(res);
  }

  /// POST /api/customer/orders/cancel — backend `cancel_reason` kutadi.
  Future<void> cancelOrder(int orderId, {String? reason}) async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/orders/cancel');
    final res = await http.post(
      url,
      headers: _jsonAuth(token),
      body: jsonEncode({
        'order_id': orderId,
        if (reason != null && reason.isNotEmpty) 'cancel_reason': reason,
      }),
    );
    _decodeResponse(res);
  }

  /// POST /api/customer/orders/pay-from-wallet
  Future<WalletPaymentResult> payOrderFromWallet(int orderId) async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/orders/pay-from-wallet');
    final res = await http.post(
      url,
      headers: _jsonAuth(token),
      body: jsonEncode({'order_id': orderId}),
    );
    final map = _decodeResponse(res);
    final data = map['data'];
    final r = WalletPaymentResult.fromMap(data is Map<String, dynamic> ? data : null);
    if (r == null) throw ApiException('Javobda data yo‘q');
    return r;
  }

  /// POST /api/customer/orders/finish
  Future<void> finishOrder(int orderId) async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/orders/finish');
    final res = await http.post(
      url,
      headers: _jsonAuth(token),
      body: jsonEncode({'order_id': orderId}),
    );
    _decodeResponse(res);
  }

  /// POST /api/customer/orders/status-update (TZ 4.1)
  Future<void> statusUpdate(int orderId, int status) async {
    final token = await _requireBearer();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/customer/orders/status-update');
    final res = await http.post(
      url,
      headers: _jsonAuth(token),
      body: jsonEncode({'order_id': orderId, 'status': status}),
    );
    _decodeResponse(res);
  }

  int? _int(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
