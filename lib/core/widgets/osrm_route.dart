import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM router'dan haqiqiy yo'l geometrini olib keladi.
/// Bir nechta serverni navbat bilan sinab ko'radi; barchasi ishlamasa `null`
/// qaytaradi — chaqiruvchi tomon to'g'ri chiziq chizmasligi uchun.
class OsrmRoute {
  const OsrmRoute({
    required this.points,
    required this.distanceMeters,
    this.nextTurnMeters,
    this.nextTurnInstruction,
  });

  final List<LatLng> points;
  final double distanceMeters;

  /// Birinchi maneuver gacha bo'lgan masofa (m). OSRM `steps[0].distance`.
  /// `null` — agar steps so'ralmagan yoki yo'q bo'lsa.
  final double? nextTurnMeters;

  /// Keyingi maneuver turini qisqacha tasvirlovchi belgi
  /// (masalan, "left", "right", "straight"). `null` bo'lsa ko'rsatilmaydi.
  final String? nextTurnInstruction;

  double get distanceKm => distanceMeters / 1000.0;

  /// Sinaladigan OSRM endpointlar — birinchisi rasmiy, keyingilari mirror.
  /// Birinchisi javobsiz qolsa keyingisi sinab ko'riladi.
  static const List<String> _hosts = [
    'https://router.project-osrm.org',
    'https://routing.openstreetmap.de/routed-car',
  ];

  static Future<OsrmRoute?> fetch(LatLng from, LatLng to) async {
    for (final host in _hosts) {
      // Har bir host uchun 2 marta urinish (transient error'lar uchun).
      for (int attempt = 0; attempt < 2; attempt++) {
        final r = await _tryFetch(host, from, to);
        if (r != null) return r;
        // qisqa kutib, keyingi urinish
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    return null;
  }

  static Future<OsrmRoute?> _tryFetch(String host, LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        '$host/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&alternatives=false&steps=true',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final r = routes.first as Map<String, dynamic>;
      final geom = r['geometry'] as Map<String, dynamic>?;
      final coords = geom?['coordinates'];
      final dist = (r['distance'] as num?)?.toDouble() ?? 0;
      if (coords is! List) return null;
      final points = coords
          .whereType<List>()
          .where((p) => p.length >= 2)
          .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
          .toList();
      if (points.length < 2) return null;

      // Birinchi step + maneuverni topish (turn-by-turn navigatsiya uchun).
      double? nextTurnM;
      String? nextTurnType;
      final legs = r['legs'];
      if (legs is List && legs.isNotEmpty) {
        final firstLeg = legs.first;
        if (firstLeg is Map<String, dynamic>) {
          final steps = firstLeg['steps'];
          if (steps is List && steps.isNotEmpty) {
            // Birinchi step — joriy nuqtadan keyingi maneuvergacha.
            final s0 = steps.first;
            if (s0 is Map<String, dynamic>) {
              nextTurnM = (s0['distance'] as num?)?.toDouble();
              final mvr = s0['maneuver'];
              if (mvr is Map<String, dynamic>) {
                final modifier = mvr['modifier'] as String?;
                final type = mvr['type'] as String?;
                nextTurnType = modifier ?? type;
              }
            }
          }
        }
      }

      return OsrmRoute(
        points: points,
        distanceMeters: dist,
        nextTurnMeters: nextTurnM,
        nextTurnInstruction: nextTurnType,
      );
    } catch (_) {
      return null;
    }
  }
}
