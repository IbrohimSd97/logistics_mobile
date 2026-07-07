import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../i18n/i18n.dart';

/// Joriy GPS joylashuvini olish uchun yagona yordamchi.
///
/// Oqim: (1) qurilmada joylashuv xizmati o'chiq bo'lsa — yoqishni so'raydi va
/// tizim sozlamalarini ochadi; (2) ruxsat berilmagan bo'lsa — so'raydi;
/// (3) hammasi joyida bo'lsa joriy [LatLng] ni qaytaradi. Har qanday bosqich
/// muvaffaqiyatsiz tugasa `null` qaytaradi va sababini snackbar bilan ko'rsatadi.
class CurrentLocation {
  CurrentLocation._();

  /// Bir martalik joylashuv o'qish — **ANR-xavfsiz**.
  ///
  /// Avval `getLastKnownPosition()` (kesh) qaytariladi — u GPS oqimini
  /// boshlamaydi, demak geolocator NMEA listener'ini ro'yxatga olmaydi/olib
  /// tashlamaydi. Bu muhim: geolocator GPS'ni to'xtatganда `removeNmeaListener`
  /// ni ASOSIY OQIMDA sinxron binder chaqiruvi bilan bajaradi va tizim
  /// joylashuv xizmati sekin bo'lsa (uzoq suspend/emulator) 5s+ bloklanib ANR
  /// beradi. Oxirgi ma'lum joylashuv bo'lmagandagina yangi fix so'raladi
  /// (Dart `.timeout()` emas — geolocator'ning ichki `timeLimit`i bilan, chunki
  /// `.timeout()` so'rovni bekor qilib o'sha bloklovchi to'xtatishni chaqiradi).
  static Future<Position?> oneShot({
    Duration timeLimit = const Duration(seconds: 6),
  }) async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    } catch (_) {}
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<LatLng?> ensureAndGet(BuildContext context) async {
    // 1) Joylashuv xizmati yoniqmi? O'chiq bo'lsa — yoqishni so'raymiz.
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return null;
      final wantsEnable = await _askEnableService(context);
      if (wantsEnable != true) return null;
      await Geolocator.openLocationSettings();
      // Foydalanuvchi sozlamadan qaytgach yana tekshiramiz.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          _snack(context, I18n.t('location.service_disabled'));
        }
        return null;
      }
    }

    // 2) Ruxsat tekshiruvi/so'rovi.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      if (context.mounted) _snack(context, I18n.t('location.permission_denied'));
      return null;
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _snack(context, I18n.t('location.permission_denied_forever'));
      }
      return null;
    }

    // 3) Joriy joylashuvni olamiz (ANR-xavfsiz: oxirgi ma'lum → yangi fix).
    final pos = await oneShot();
    if (pos != null) return LatLng(pos.latitude, pos.longitude);
    if (context.mounted) _snack(context, I18n.t('location.unavailable'));
    return null;
  }

  static Future<bool?> _askEnableService(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('location.enable_title')),
        content: Text(I18n.t('location.enable_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(I18n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(I18n.t('location.enable_action')),
          ),
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
