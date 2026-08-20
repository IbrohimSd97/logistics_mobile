import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import 'yandex_point.dart';

/// Yandex Driving Router orqali haqiqiy yo'l geometriyasi.
///
/// OSRM'dan farqi: Yandex tirbandlikni hisobga oladi ([durationWithTrafficSec])
/// va O'zbekiston yo'llarini yaxshiroq biladi. Xato bo'lsa `null` qaytadi —
/// chaqiruvchi to'g'ri chiziq chizmasligi uchun.
///
/// `full` variant kerak (`android/gradle.properties` → `yandexMapkit.variant`).
class MapRoute {
  const MapRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSec,
    required this.durationWithTrafficSec,
    this.nextTurnMeters,
    this.nextTurnInstruction,
  });

  final List<LatLng> points;
  final double distanceMeters;

  /// Tirbandliksiz yo'l vaqti (soniya).
  final double durationSec;

  /// Tirbandlik bilan yo'l vaqti (soniya) — driver ETA'si uchun shu ishlatiladi.
  final double durationWithTrafficSec;

  /// Keyingi burilishgacha masofa (m). Geometriyadan hisoblanadi.
  final double? nextTurnMeters;

  /// Burilish turi: `left`, `right`, `straight`.
  final String? nextTurnInstruction;

  double get distanceKm => distanceMeters / 1000.0;

  int get durationMin => (durationWithTrafficSec / 60).round();

  static Future<MapRoute?> fetch(LatLng from, LatLng to) async {
    try {
      final (_, resultFuture) = await YandexDriving.requestRoutes(
        points: [
          RequestPoint(
            point: latLngToPoint(from),
            requestPointType: RequestPointType.wayPoint,
          ),
          RequestPoint(
            point: latLngToPoint(to),
            requestPointType: RequestPointType.wayPoint,
          ),
        ],
        drivingOptions: const DrivingOptions(routesCount: 1),
      );
      final result = await resultFuture;

      final routes = result.routes;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first;
      final points = route.geometry.points.map(pointToLatLng).toList();
      if (points.length < 2) return null;

      final weight = route.metadata.weight;
      final turn = _nextTurn(points);

      return MapRoute(
        points: points,
        distanceMeters: (weight.distance.value ?? 0).toDouble(),
        durationSec: (weight.time.value ?? 0).toDouble(),
        durationWithTrafficSec:
            (weight.timeWithTraffic.value ?? weight.time.value ?? 0).toDouble(),
        nextTurnMeters: turn?.$1,
        nextTurnInstruction: turn?.$2,
      );
    } catch (_) {
      return null;
    }
  }

  /// Marshrut boshidan birinchi sezilarli burilishni topadi.
  ///
  /// Plugin Yandex'ning maneuver annotatsiyalarini ochmaydi, shuning uchun
  /// burilish geometriyadan aniqlanadi: ketma-ket segmentlar orasidagi burchak
  /// `turnThresholdDeg` dan oshsa — bu burilish.
  ///
  /// @return (burilishgacha masofa (m), yo'nalish) yoki `null`.
  static (double, String)? _nextTurn(List<LatLng> points) {
    const distance = Distance();
    const turnThresholdDeg = 35.0;

    var travelled = 0.0;

    for (var i = 1; i < points.length - 1; i++) {
      travelled += distance(points[i - 1], points[i]);

      final incoming = _bearing(points[i - 1], points[i]);
      final outgoing = _bearing(points[i], points[i + 1]);

      // [-180, 180] oralig'iga normallashtirilgan burchak farqi.
      var delta = (outgoing - incoming) % 360;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;

      if (delta.abs() >= turnThresholdDeg) {
        return (travelled, delta > 0 ? 'right' : 'left');
      }

      // Juda uzoqdagi burilish navigatsiya uchun foydasiz.
      if (travelled > 5000) break;
    }

    return null;
  }

  static double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
