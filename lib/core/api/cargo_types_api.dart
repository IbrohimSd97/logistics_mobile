import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'http_response_codec.dart';
import '../config/api_config.dart';

class CargoType {
  const CargoType({
    required this.id,
    required this.name,
    this.description,
    this.pickupFreeWaitMinutes = 0,
    this.pickupPaidWaitPrice,
    this.pickupPaidWaitIntervalMin = 10,
    this.deliveryFreeWaitMinutes = 0,
    this.deliveryPaidWaitPrice,
    this.deliveryPaidWaitIntervalMin = 10,
    this.pricePerKm,
    this.minOrderPrice,
    this.compensationPricePerKm,
  });

  final int id;
  final String name;
  final String? description;
  final int pickupFreeWaitMinutes;
  final String? pickupPaidWaitPrice;
  final int pickupPaidWaitIntervalMin;
  final int deliveryFreeWaitMinutes;
  final String? deliveryPaidWaitPrice;
  final int deliveryPaidWaitIntervalMin;
  final String? pricePerKm;
  final String? minOrderPrice;
  final String? compensationPricePerKm;

  static int? _int(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static CargoType? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = _int(m['id']);
    if (id == null) return null;
    return CargoType(
      id: id,
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString(),
      pickupFreeWaitMinutes: _int(m['pickup_free_wait_minutes']) ?? 0,
      pickupPaidWaitPrice: m['pickup_paid_wait_price']?.toString(),
      pickupPaidWaitIntervalMin: _int(m['pickup_paid_wait_interval_min']) ?? 10,
      deliveryFreeWaitMinutes: _int(m['delivery_free_wait_minutes']) ?? 0,
      deliveryPaidWaitPrice: m['delivery_paid_wait_price']?.toString(),
      deliveryPaidWaitIntervalMin: _int(m['delivery_paid_wait_interval_min']) ?? 10,
      pricePerKm: m['price_per_km']?.toString(),
      minOrderPrice: m['min_order_price']?.toString(),
      compensationPricePerKm: m['compensation_price_per_km']?.toString(),
    );
  }
}

class CargoTypesApi {
  const CargoTypesApi();

  /// GET /api/cargo-types — autentifikatsiyasiz.
  Future<List<CargoType>> list() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/cargo-types');
    final res = await http.get(url, headers: const {'Accept': 'application/json'});
    final map = decodeJsonEnvelopeOrThrow(res);
    final raw = map['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CargoType.fromMap)
        .whereType<CargoType>()
        .toList();
  }
}
