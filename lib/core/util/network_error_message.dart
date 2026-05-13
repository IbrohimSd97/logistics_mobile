import 'package:flutter/foundation.dart' show kIsWeb;

bool _looksLikeBrowserNetworkFailure(Object error) {
  final lower = error.toString().toLowerCase();
  return lower.contains('failed to fetch') ||
      lower.contains('clientexception') ||
      lower.contains('xmlhttprequest');
}

/// SnackBar uchun qisqa matn (2–4 qator).
String formatNetworkFailureShort(Object error, {required String url}) {
  final raw = error.toString();

  final buf = StringBuffer();
  buf.writeln('Serverga ulanib bo‘lmadi.');
  buf.writeln(url);

  if (kIsWeb && _looksLikeBrowserNetworkFailure(error)) {
    buf.writeln('Web: CORS yoki server javob bermayapti.');
    buf.write('«Batafsil» — sozlash qadamlari.');
  } else {
    buf.writeln(raw.length > 140 ? '${raw.substring(0, 140)}…' : raw);
  }
  return buf.toString().trim();
}

/// Dialogda ko‘rsatiladigan to‘liq yo‘riqnoma (Laravel mahalliy misollar — 8000 port).
String networkFailureDetailGuide(String apiBaseUrl) {
  final appBase = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  return '''
Chrome (web)da so‘rovlar boshqa origin/portdan ketadi; CORSda `http://localhost:*` kabi wildcard ishlamaydi.

Ilova default API: `http://0.0.0.0:8000` (`serve --host=0.0.0.0` bilan). Chrome’da `0.0.0.0` ishlamasa: `flutter run --dart-define=API_BASE_URL=http://localhost:8000`

Laravel: `config/cors.php` ichida `allowed_origins_patterns` — `http://localhost`, `http://127.0.0.1`, `http://[::1]` uchun istalgan portni regex bilan qabul qiling.

O‘zgarishdan keyin: `php artisan config:clear`

Server: `php artisan serve --host=0.0.0.0 --port=8000`

Tekshiruv: brauzerda GET
http://localhost:8000/up
javob kodi 200 bo‘lishi kerak.

Postman: POST http://localhost:8000/api/auth/otp-send (JSON body).

Kim tomonda (umuman): CORS — brauzer qoidasi + backend `cors.php`; Flutter maxsus "xato" qilmaydi, oddiy HTTP so‘rov yuboradi. Ulanmayapti desa — server ishlamayotgani yoki CORS yo‘q.

Joriy ilova API manzili (so‘rov ketadigan): $appBase
'''.trim();
}
