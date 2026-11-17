import 'dart:async';

/// Server sessiyani bekor qilganda (401 — masalan kompaniya admini xodimni
/// o'chirdi yoki token muddati tugadi) ilovani login sahifasiga qaytarish.
///
/// `http_response_codec` avtorizatsiyali so'rovga 401 kelsa [notify] chaqiradi;
/// [handler] `main.dart` da o'rnatiladi (sessiyani tozalab, LoginScreen ochadi).
class SessionExpiry {
  SessionExpiry._();

  static Future<void> Function()? handler;
  static bool _busy = false;

  static void notify() {
    if (_busy || handler == null) return;
    _busy = true;
    unawaited(handler!().whenComplete(() {
      Future<void>.delayed(const Duration(seconds: 3), () => _busy = false);
    }));
  }
}
