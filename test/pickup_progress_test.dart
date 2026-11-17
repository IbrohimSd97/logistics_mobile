import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/orders/pickup_points.dart';

void main() {
  final t = DateTime(2026, 11, 17, 10);
  PickupPoint pt(int seq, {DateTime? a, DateTime? l}) =>
      PickupPoint(seq: seq, address: 'A$seq', lat: 41, lng: 69, arrivedAt: a, leftAt: l);

  test('nuqtalar yo\'q — bosqich yo\'q', () {
    expect(PickupProgress.compute(points: const [], arrivedAtA: true, pickup1LeftAt: null), isNull);
  });

  test('A → A2 → A3 bosqichlari server bilan bir xil', () {
    var p = PickupProgress.compute(points: [pt(2), pt(3)], arrivedAtA: true, pickup1LeftAt: null)!;
    expect((p.stage, p.seq, p.next, p.total), ('at_pickup', 1, 'leave', 3));

    p = PickupProgress.compute(points: [pt(2), pt(3)], arrivedAtA: true, pickup1LeftAt: t)!;
    expect((p.stage, p.seq, p.next), ('to_pickup', 2, 'arrive'));

    p = PickupProgress.compute(points: [pt(2, a: t), pt(3)], arrivedAtA: true, pickup1LeftAt: t)!;
    expect((p.stage, p.seq, p.next), ('at_pickup', 2, 'leave'));

    p = PickupProgress.compute(points: [pt(2, a: t, l: t), pt(3)], arrivedAtA: true, pickup1LeftAt: t)!;
    expect((p.stage, p.seq, p.next), ('to_pickup', 3, 'arrive'));

    p = PickupProgress.compute(points: [pt(2, a: t, l: t), pt(3, a: t)], arrivedAtA: true, pickup1LeftAt: t)!;
    expect((p.stage, p.seq, p.next, p.label), ('at_pickup', 3, 'in_transit', 'A3'));
  });

  test('server JSON dan o\'qish', () {
    final list = PickupPoint.listFrom([
      {'seq': 3, 'address': 'X', 'lat': 41.1, 'lng': 69.1, 'arrived_at': null},
      {'seq': 2, 'address': 'Y', 'lat': '41.2', 'lng': '69.2', 'arrived_at': '2026-11-17T05:00:00Z'},
    ]);
    expect(list.map((e) => e.label), ['A2', 'A3']);
    expect(list.first.arrivedAt, isNotNull);
    final pr = PickupProgress.fromMap({'stage': 'to_pickup', 'seq': 2, 'total': 3, 'next': 'arrive'})!;
    expect(pr.canArrive, isTrue);
  });
}
