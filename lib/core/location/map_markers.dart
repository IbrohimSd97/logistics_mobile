import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import 'yandex_point.dart';

/// Yandex `PlacemarkMapObject` uchun marker rasmlarini runtime'da Canvas bilan
/// chizadi (PNG asset shart emas). Eski flutter_map custom-widget markerlariga
/// vizual mos: A/B doira-pin va driver navigatsiya strelkasi.
class MapMarkers {
  /// A/B nuqta pini: rangli doira, oq hoshiya, o'rtasida harf.
  static Future<BitmapDescriptor> abPin(String label, Color color) async {
    const double s = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(s / 2, s / 2);
    const r = 30.0;

    canvas.drawCircle(
      center + const Offset(0, 3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(center, r - 5, Paint()..color = color);

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
      ),
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    return _toBitmap(recorder, s);
  }

  /// Driver markeri: rangli doira + oq navigatsiya uchburchagi (yuqoriga).
  /// Screen-aligned (noRotation) — heading-up rejimida map aylansa, strelka
  /// doim "yuqori = oldinga" ko'rinadi.
  static Future<BitmapDescriptor> driverArrow(Color color) async {
    const double s = 84;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(s / 2, s / 2);
    const r = 26.0;

    canvas.drawCircle(
      center + const Offset(0, 3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(center, r - 4, Paint()..color = color);

    final path = ui.Path()
      ..moveTo(center.dx, center.dy - 13)
      ..lineTo(center.dx - 9, center.dy + 11)
      ..lineTo(center.dx, center.dy + 5)
      ..lineTo(center.dx + 9, center.dy + 11)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);

    return _toBitmap(recorder, s);
  }

  static Future<BitmapDescriptor> _toBitmap(ui.PictureRecorder recorder, double size) async {
    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}

/// Nuqtalar ro'yxatini o'rab turgan chegara (bbox), ozgina "padding" bilan
/// kengaytirilgan — Yandex `newGeometry` ni chetlarga yopishtirmaslik uchun.
BoundingBox boundingBoxOf(List<LatLng> pts, {double padFraction = 0.15}) {
  var minLat = pts.first.latitude, maxLat = pts.first.latitude;
  var minLng = pts.first.longitude, maxLng = pts.first.longitude;
  for (final p in pts) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  final latPad = ((maxLat - minLat).abs() * padFraction) + 0.002;
  final lngPad = ((maxLng - minLng).abs() * padFraction) + 0.002;
  return BoundingBox(
    northEast: Point(latitude: maxLat + latPad, longitude: maxLng + lngPad),
    southWest: Point(latitude: minLat - latPad, longitude: minLng - lngPad),
  );
}

/// LatLng ro'yxatini Yandex Point ro'yxatiga o'giradi (polyline uchun).
List<Point> latLngListToPoints(List<LatLng> pts) => pts.map(latLngToPoint).toList();
