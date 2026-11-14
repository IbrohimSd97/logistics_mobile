import 'dart:async';

import 'package:app_links/app_links.dart' as al;
import 'package:flutter/foundation.dart';

import '../push/push_service.dart';

/// SMS'dagi qabul qiluvchi havolasini ilovada ochadi.
///
/// Qabul qilinadigan havolalar:
///   - `https://admin.alix.uz/t/{token}` — iOS Universal Link / Android App Link;
///   - `alix://t/{token}` — kuzatish sahifasidagi "Ilovada ochish" tugmasi.
///
/// Havola push bosilgandek navbatga qo'yiladi (`PushService`): ilova yopiq
/// bo'lsa yoki foydalanuvchi hali kirmagan bo'lsa — asosiy sahifa ochilgach
/// (`markAppReady`) buyurtma sahifasi ochiladi.
class DeepLinkService {
  DeepLinkService._();
  static final instance = DeepLinkService._();

  static final _token = RegExp(r'^[A-Za-z0-9]{40}$');
  StreamSubscription<Uri>? _sub;

  void init() {
    if (_sub != null) return;
    try {
      // v6+: oqim ilovani ochgan (initial) havolani ham beradi.
      _sub = al.AppLinks().uriLinkStream.listen(_handle, onError: (Object e) => debugPrint('DeepLink: $e'));
    } catch (e) {
      debugPrint('DeepLink init: $e');
    }
  }

  void _handle(Uri uri) {
    final token = recipientToken(uri);
    if (token == null) return;
    PushService.instance.handleExternal({'type': 'recipient_link', 'token': token});
  }

  /// `/t/{token}` (https) yoki `alix://t/{token}` dan tokenni ajratadi.
  static String? recipientToken(Uri uri) {
    final segments = [
      if (uri.scheme == 'alix' && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    if (segments.length < 2 || segments[0] != 't') return null;
    final token = segments[1];
    return _token.hasMatch(token) ? token : null;
  }
}
