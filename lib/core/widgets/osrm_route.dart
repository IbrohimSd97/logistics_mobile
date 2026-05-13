import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM public router'dan haqiqiy yo'l geometrini olib keladi.
/// Xato bo'lsa to'g'ri chiziq qaytadi (fallback).
class OsrmRoute {
  const OsrmRoute({required this.points, required this.distanceMeters});

  final List<LatLng> points;
  final double distanceMeters;

  double get distanceKm => distanceMeters / 1000.0;

  static Future<OsrmRoute> fetch(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&alternatives=false&steps=false',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = body['routes'];
        if (routes is List && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final geom = r['geometry'] as Map<String, dynamic>?;
          final coords = geom?['coordinates'];
          final dist = (r['distance'] as num?)?.toDouble() ?? 0;
          if (coords is List) {
            final points = coords
                .whereType<List>()
                .where((p) => p.length >= 2)
                .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
                .toList();
            if (points.length >= 2) {
              return OsrmRoute(points: points, distanceMeters: dist);
            }
          }
        }
      }
    } catch (_) {
      // fallthrough
    }
    // Fallback — to'g'ri chiziq
    final straight = const Distance().as(LengthUnit.Meter, from, to);
    return OsrmRoute(points: [from, to], distanceMeters: straight);
  }
}
