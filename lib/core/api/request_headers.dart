import '../i18n/i18n.dart';

/// API'ga yuboriladigan standart header'lar. Joriy ilova tili
/// `Accept-Language`da yuboriladi — backend (Laravel) shu asosda javob
/// matn-xabarlarini lokalizatsiya qiladi.
///
/// Foydalanish:
/// ```dart
/// http.get(url, headers: jsonAuthHeaders(token));
/// ```
Map<String, String> jsonAuthHeaders(String token) => {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Accept-Language': I18n.instance.code,
      'Authorization': 'Bearer $token',
    };

Map<String, String> jsonHeaders() => {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Accept-Language': I18n.instance.code,
    };

Map<String, String> formAuthHeaders(String token) => {
      'Accept': 'application/json',
      'Accept-Language': I18n.instance.code,
      'Authorization': 'Bearer $token',
    };

Map<String, String> formHeaders() => {
      'Accept': 'application/json',
      'Accept-Language': I18n.instance.code,
    };
