/// ALIX Logistics API.
///
/// **Production**: barcha platformalar uchun default `https://alix.uz`.
/// Mahalliy ishlab chiqish kerak bo‘lsa, `--dart-define=API_BASE_URL=...` orqali
/// localhost'ga yo‘naltiriladi (u har doim ustun):
///   - Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8080`
///   - Web (Chrome):     `--dart-define=API_BASE_URL=http://localhost:8080`
///   - iOS sim / desktop:`--dart-define=API_BASE_URL=http://0.0.0.0:8080`
///
/// **CORS** (faqat web) — backend `config/cors.php`da `https://alix.uz` origin'iga ruxsat berishi kerak.
class ApiConfig {
  ApiConfig._();

  /// Production API domeni — barcha platformalar uchun default.
  static const String prodBaseUrl = 'https://alix.uz';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv.replaceAll(RegExp(r'/+$'), '');
    }
    return prodBaseUrl;
  }
}
