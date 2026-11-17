/// Bir nechta olib ketish nuqtasi (A → A2 … A5 → B).
///
/// Server: `pickups` — qo'shimcha nuqtalar (A2…A5), `pickup1_left_at` — A'dan
/// jo'nagan vaqt, `pickup_progress` — haydovchi bosqichi.
library;

/// Qo'shimcha olib ketish nuqtalari soni chegarasi (A bilan jami 5 ta).
const maxExtraPickups = 4;

class PickupPoint {
  const PickupPoint({
    required this.seq,
    required this.address,
    required this.lat,
    required this.lng,
    this.arrivedAt,
    this.leftAt,
  });

  /// 2..5 (A = 1 — buyurtmaning asosiy pickup'i).
  final int seq;
  final String address;
  final double lat;
  final double lng;
  final DateTime? arrivedAt;
  final DateTime? leftAt;

  String get label => 'A$seq';

  PickupPoint copyWith({DateTime? arrivedAt, DateTime? leftAt}) => PickupPoint(
        seq: seq,
        address: address,
        lat: lat,
        lng: lng,
        arrivedAt: arrivedAt ?? this.arrivedAt,
        leftAt: leftAt ?? this.leftAt,
      );

  static List<PickupPoint> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <PickupPoint>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final lat = double.tryParse('${e['lat']}');
      final lng = double.tryParse('${e['lng']}');
      if (lat == null || lng == null) continue;
      out.add(PickupPoint(
        seq: int.tryParse('${e['seq']}') ?? out.length + 2,
        address: e['address']?.toString() ?? '',
        lat: lat,
        lng: lng,
        arrivedAt: parsePickupTime(e['arrived_at']),
        leftAt: parsePickupTime(e['left_at']),
      ));
    }
    out.sort((a, b) => a.seq.compareTo(b.seq));
    return out;
  }
}

/// Haydovchi olib ketish bosqichi (faqat qo'shimcha nuqtalar bo'lsa va A'ga yetgach).
class PickupProgress {
  const PickupProgress({required this.stage, required this.seq, required this.total, required this.next});

  /// `at_pickup` — nuqtada yuklayapti; `to_pickup` — keyingi nuqtaga ketyapti.
  final String stage;

  /// 1 = A, 2..5 = A2..A5.
  final int seq;
  final int total;

  /// `leave` | `arrive` | `in_transit`.
  final String next;

  bool get atPickup => stage == 'at_pickup';
  bool get toPickup => stage == 'to_pickup';
  bool get canLeave => next == 'leave';
  bool get canArrive => next == 'arrive';
  bool get readyForTransit => next == 'in_transit';
  String get label => seq == 1 ? 'A' : 'A$seq';

  static PickupProgress? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final stage = raw['stage']?.toString();
    final next = raw['next']?.toString();
    if (stage == null || next == null) return null;
    return PickupProgress(
      stage: stage,
      seq: int.tryParse('${raw['seq']}') ?? 1,
      total: int.tryParse('${raw['total']}') ?? 1,
      next: next,
    );
  }

  /// Server bilan bir xil mantiq — optimistik UI uchun (server javobi bilan almashadi).
  static PickupProgress? compute({
    required List<PickupPoint> points,
    required bool arrivedAtA,
    required DateTime? pickup1LeftAt,
  }) {
    if (points.isEmpty || !arrivedAtA) return null;
    final total = points.length + 1;
    if (pickup1LeftAt == null) return PickupProgress(stage: 'at_pickup', seq: 1, total: total, next: 'leave');
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final last = i == points.length - 1;
      if (p.arrivedAt == null) return PickupProgress(stage: 'to_pickup', seq: p.seq, total: total, next: 'arrive');
      if (last || p.leftAt == null) {
        return PickupProgress(stage: 'at_pickup', seq: p.seq, total: total, next: last ? 'in_transit' : 'leave');
      }
    }
    return PickupProgress(stage: 'at_pickup', seq: total, total: total, next: 'in_transit');
  }
}

DateTime? parsePickupTime(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty || s == 'null') return null;
  return DateTime.tryParse(s)?.toLocal();
}
