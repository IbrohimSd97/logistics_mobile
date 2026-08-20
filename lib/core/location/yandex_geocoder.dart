import 'package:latlong2/latlong.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import 'yandex_point.dart';

/// Manzil qidiruvi natijasi — ekranlar `LatLng` bilan ishlaydi, shuning uchun
/// Yandex `Point` shu chegarada `LatLng`ga o'giriladi.
class GeoHit {
  const GeoHit({required this.title, required this.subtitle, required this.point});

  /// Qisqa nom — ro'yxatda birinchi qator (masalan "Bunyodkor ko'chasi, 12").
  final String title;

  /// To'liq manzil — ikkinchi qator.
  final String subtitle;

  final LatLng point;

  /// Tanlanganda manzil maydoniga yoziladigan matn.
  String get fullAddress => subtitle.isNotEmpty ? subtitle : title;
}

/// Yandex Geocoder (MapKit `full` variant). Nominatim o'rniga — O'zbekiston
/// manzillari uchun sezilarli aniqroq va ilova tili bilan mos javob beradi.
///
/// `full` variant bo'lmasa (`android/gradle.properties` →
/// `yandexMapkit.variant`), bu kanallar ro'yxatdan o'tmaydi va chaqiruvlar
/// xato beradi — shuning uchun har bir metod xatoni yutib, bo'sh natija
/// qaytaradi: xarita ishlashda davom etadi, faqat manzil topilmaydi.
class YandexGeocoder {
  const YandexGeocoder._();

  /// Toshkent markazi — qidiruvni shahar atrofiga og'irlash uchun.
  static const _tashkent = Point(latitude: 41.311081, longitude: 69.240562);

  /// Qidiruv hududi: O'zbekiston (taxminiy bbox).
  static final _uzbekistan = BoundingBox(
    northEast: const Point(latitude: 45.6, longitude: 73.2),
    southWest: const Point(latitude: 37.1, longitude: 55.9),
  );

  /// Koordinata → manzil (reverse geocoding). Topilmasa `null`.
  static Future<String?> reverse(LatLng p) async {
    try {
      final (_, resultFuture) = await YandexSearch.searchByPoint(
        point: latLngToPoint(p),
        searchOptions: const SearchOptions(
          searchType: SearchType.geo,
          geometry: false,
          resultPageSize: 1,
        ),
      );
      final result = await resultFuture;

      final items = result.items;
      if (items == null || items.isEmpty) return null;

      return _addressOf(items.first) ?? items.first.name;
    } catch (_) {
      return null;
    }
  }

  /// Matn → manzillar ro'yxati (forward geocoding). Xato bo'lsa bo'sh ro'yxat.
  static Future<List<GeoHit>> search(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    try {
      final (_, resultFuture) = await YandexSearch.searchByText(
        searchText: q,
        geometry: Geometry.fromBoundingBox(_uzbekistan),
        searchOptions: SearchOptions(
          // `none` — server o'zi hal qiladi: ham manzil, ham obyekt nomi
          // ("Chorsu bozori") bo'yicha topadi. Yuk manzili ikkalasi ham
          // bo'lishi mumkin.
          searchType: SearchType.none,
          geometry: false,
          resultPageSize: limit,
          userPosition: _tashkent,
        ),
      );
      final result = await resultFuture;

      final items = result.items ?? const [];

      return items
          .map((item) {
            final point = item.geometry
                .map((g) => g.point)
                .whereType<Point>()
                .firstOrNull;
            if (point == null) return null;

            return GeoHit(
              title: item.name,
              subtitle: _addressOf(item) ?? '',
              point: pointToLatLng(point),
            );
          })
          .whereType<GeoHit>()
          .take(limit)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Toponim metadata'sидan to'liq manzil matnini oladi.
  static String? _addressOf(SearchItem item) {
    final formatted = item.toponymMetadata?.address.formattedAddress;
    if (formatted != null && formatted.isNotEmpty) return formatted;

    final bizAddress = item.businessMetadata?.address.formattedAddress;
    if (bizAddress != null && bizAddress.isNotEmpty) return bizAddress;

    return null;
  }
}
