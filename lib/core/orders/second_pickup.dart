/// Ikkinchi olib ketish nuqtasi (A → A2 → B) — server `pickup2` obyekti.
///
/// `stage` (haydovchi A'ga yetib kelgandan keyin):
///   `at_pickup1` — A'da yuklanmoqda;
///   `to_pickup2` — A'dan chiqdi, A2 ga ketmoqda;
///   `at_pickup2` — A2 da yuklanmoqda (keyin "yo'lga chiqdim").
class SecondPickup {
  const SecondPickup({
    required this.address,
    required this.lat,
    required this.lng,
    this.stage,
    this.leftPickup1At,
    this.arrivedAt,
  });

  final String address;
  final double lat;
  final double lng;
  final String? stage;
  final DateTime? leftPickup1At;
  final DateTime? arrivedAt;

  bool get headingToPickup2 => stage == 'to_pickup2';
  bool get atPickup2 => stage == 'at_pickup2';
  bool get atPickup1 => stage == 'at_pickup1';

  static SecondPickup? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final lat = double.tryParse('${raw['lat']}');
    final lng = double.tryParse('${raw['lng']}');
    if (lat == null || lng == null) return null;
    DateTime? dt(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    final s = raw['stage']?.toString();
    return SecondPickup(
      address: raw['address']?.toString() ?? '',
      lat: lat,
      lng: lng,
      stage: (s == null || s.isEmpty || s == 'null') ? null : s,
      leftPickup1At: dt(raw['left_pickup1_at']),
      arrivedAt: dt(raw['arrived_at']),
    );
  }
}
