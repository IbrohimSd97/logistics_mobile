import 'package:latlong2/latlong.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

/// App ichida koordinata tipi sifatida `latlong2.LatLng` ishlatiladi (u butun
/// ilovada — GPS, OSRM, order modellari — tarqalgan). Yandex xaritasi esa
/// `Point` kutadi. Bu yordamchilar FAQAT xarita chegarasida ikkalasini
/// bir-biriga o'giradi, shunda qolgan kod o'zgarmaydi.
Point latLngToPoint(LatLng p) => Point(latitude: p.latitude, longitude: p.longitude);

LatLng pointToLatLng(Point p) => LatLng(p.latitude, p.longitude);
