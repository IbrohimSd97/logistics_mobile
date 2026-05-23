import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'http_response_codec.dart';
import '../config/api_config.dart';
import '../i18n/i18n.dart';

/// Buyurtma bekor qilish sababi (catalog row).
///
/// Backend tomonidan `name_uz` va `name_ru` ikkala ham keladi — clientda
/// joriy tilga qarab `displayName` ni qaytaramiz.
///
/// `isOther=true` qator — UI uchun "Boshqa" varianti; tanlanganda qo'lda
/// matn maydoni ochiladi va backendga `cancel_reason` matn maydoni bilan
/// birga jo'natiladi (id ham albatta jo'natiladi).
class CancelReason {
  const CancelReason({
    required this.id,
    required this.code,
    required this.nameUz,
    required this.nameRu,
    required this.isOther,
    required this.sortOrder,
  });

  final int id;
  final String code;
  final String nameUz;
  final String nameRu;
  final bool isOther;
  final int sortOrder;

  /// Joriy locale bo'yicha ko'rsatiladigan nom.
  String get displayName {
    final code = I18n.instance.code;
    if (code == 'ru') return nameRu;
    return nameUz;
  }

  static int? _int(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static CancelReason? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = _int(m['id']);
    if (id == null) return null;
    return CancelReason(
      id: id,
      code: m['code']?.toString() ?? '',
      nameUz: m['name_uz']?.toString() ?? '',
      nameRu: m['name_ru']?.toString() ?? '',
      isOther: m['is_other'] == true,
      sortOrder: _int(m['sort_order']) ?? 0,
    );
  }
}

/// Order-detail javobidagi `cancel_reason_info` nested objectning client
/// tarafidagi vakili. `info` qator topilsa, displayName uni ishlatadi; aks
/// holda fallback `rawText` (orders.cancel_reason matn ustuni) ko'rsatiladi.
class OrderCancelReasonView {
  const OrderCancelReasonView({this.info, this.rawText});

  /// Backenddagi `cancel_reason_info` (eager-loaded catalog row).
  final CancelReason? info;
  /// Backenddagi `cancel_reason` (custom matn — Boshqa yoki legacy).
  final String? rawText;

  bool get hasAny => info != null || (rawText != null && rawText!.isNotEmpty);
}

class CancelReasonsApi {
  const CancelReasonsApi._({required String path, required Future<String> Function() tokenFn})
      : _path = path,
        _tokenFn = tokenFn;

  final String _path;
  final Future<String> Function() _tokenFn;

  /// Customer uchun `/api/customer/cancel-reasons`.
  factory CancelReasonsApi.customer({required Future<String> Function() tokenFn}) {
    return CancelReasonsApi._(path: '/api/customer/cancel-reasons', tokenFn: tokenFn);
  }

  /// Driver uchun `/api/driver/cancel-reasons`.
  factory CancelReasonsApi.driver({required Future<String> Function() tokenFn}) {
    return CancelReasonsApi._(path: '/api/driver/cancel-reasons', tokenFn: tokenFn);
  }

  Future<List<CancelReason>> list() async {
    final token = await _tokenFn();
    final url = Uri.parse('${ApiConfig.baseUrl}$_path');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Accept-Language': I18n.instance.code,
      'Authorization': 'Bearer $token',
    });
    final map = decodeJsonEnvelopeOrThrow(res);
    final raw = map['data'];
    if (raw is! List) return const [];
    final items = raw
        .whereType<Map<String, dynamic>>()
        .map(CancelReason.fromMap)
        .whereType<CancelReason>()
        .toList();
    // Backend allaqachon sort_order bo'yicha qaytaradi, lekin har holda
    // himoya qilamiz (custom backend versiyalari bilan ishlasin).
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }
}
