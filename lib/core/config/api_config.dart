import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Mahalliy Laravel / API.
///
/// **CORS** — brauzer qoidasi; so‘rov `Origin` bilan ketadi, backend `config/cors.php`da ruxsat berishi kerak.
/// Wildcard `http://localhost:*` origin sifatida ishlamaydi; Laravel namunasi: `laravel/config/cors.php`
/// (`allowed_origins_patterns`).
///
/// **Eslatma:** Flutter web `http://localhost:<flutter-port>`, API `http://localhost:8000` — **ikki xil origin**
/// (port farqi), shuning uchun `allowed_origins_patterns` (localhost / 127.0.0.1 / [::1] + port) baribir kerak;
/// hozirgi `cors.php` shunga mos.
///
/// - **Android emulator**: `http://10.0.2.2:8000` (hostning `127.0.0.1` i).
/// - **Web (Chrome)**: default `http://localhost:8000` — brauzer `http://0.0.0.0:8000` ga ishonchli ulanmaydi.
/// - **iOS simulator / desktop**: default `http://0.0.0.0:8000` — `php artisan serve --host=0.0.0.0 --port=8000` bilan mos.
/// - Boshqa URL kerak bo‘lsa: `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000`
/// - Har doim **`--dart-define=API_BASE_URL=...`** berilgan bo‘lsa, u ustun.
class ApiConfig {
  ApiConfig._();

  static const int defaultPort = 8000;

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv.replaceAll(RegExp(r'/+$'), '');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$defaultPort';
    }
    if (kIsWeb) {
      return 'http://localhost:$defaultPort';
    }
    return 'http://0.0.0.0:$defaultPort';
  }
}
