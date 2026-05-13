import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/deadline_banner.dart';
import '../../core/widgets/order_timeline.dart';
import '../../core/widgets/osrm_route.dart';
import '../../core/widgets/slide_button.dart';
import '../customer_api.dart';
import '../customer_models.dart';

class CustomerOrderDetailPage extends StatefulWidget {
  const CustomerOrderDetailPage({super.key, required this.order});

  final CustomerOrder order;

  @override
  State<CustomerOrderDetailPage> createState() => _CustomerOrderDetailPageState();
}

class _CustomerOrderDetailPageState extends State<CustomerOrderDetailPage> {
  static const _toshkent = LatLng(41.311081, 69.240562);

  bool _busy = false;
  late CustomerOrder _order;
  final MapController _mapCtrl = MapController();
  OsrmRoute? _route;
  bool _routeLoading = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _refetchRoute();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _mapCtrl.dispose();
    super.dispose();
  }

  LatLng? get _pickup => (_order.pickupLat != null && _order.pickupLng != null)
      ? LatLng(_order.pickupLat!, _order.pickupLng!)
      : null;

  LatLng? get _delivery => (_order.deliveryLat != null && _order.deliveryLng != null)
      ? LatLng(_order.deliveryLat!, _order.deliveryLng!)
      : null;

  LatLng? get _acceptPoint => (_order.acceptLat != null && _order.acceptLng != null)
      ? LatLng(_order.acceptLat!, _order.acceptLng!)
      : null;

  (LatLng?, LatLng?) get _stageRoute {
    final s = _order.status;
    if (s == 3 || s == 4) {
      return (_acceptPoint ?? _pickup, _pickup);
    }
    if (s == 5 || s == 7 || s == 8 || s == 9) return (null, null);
    if (s == 6) return (_pickup, _delivery);
    return (_pickup, _delivery);
  }

  Future<void> _refetchRoute() async {
    final (from, to) = _stageRoute;
    if (from == null || to == null) {
      setState(() => _route = null);
      return;
    }
    setState(() => _routeLoading = true);
    final r = await OsrmRoute.fetch(from, to);
    if (!mounted) return;
    setState(() {
      _route = r;
      _routeLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToRoute());
  }

  void _fitMapToRoute() {
    final route = _route;
    if (route != null && route.points.length >= 2) {
      final bounds = LatLngBounds.fromPoints(route.points);
      _mapCtrl.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(64)));
      return;
    }
    final p = _pickup;
    final d = _delivery;
    if (p != null && d != null) {
      _mapCtrl.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([p, d]),
          padding: const EdgeInsets.all(64),
        ),
      );
    }
  }

  String _statusLabel(int? s) {
    switch (s) {
      case 1:
        return 'Yangi';
      case 2:
        return 'Faol';
      case 3:
        return 'Qabul qilindi';
      case 4:
        return 'Pickup’da';
      case 5:
        return 'Yuklanmoqda';
      case 6:
        return 'Yo‘lda';
      case 7:
        return 'Delivery’da';
      case 8:
        return 'Tushirilmoqda';
      case 9:
        return 'Yetkazildi';
      case 10:
        return 'Yakunlandi';
      case 11:
        return 'Bekor qilingan';
      case 12:
        return 'Muvaffaqiyatsiz';
      default:
        return '—';
    }
  }

  bool get _isFinal {
    final s = _order.status;
    return s == 10 || s == 11 || s == 12;
  }

  bool get _canFinish => _order.status == 9;

  bool get _canCancel {
    final s = _order.status;
    return s == 1 || s == 2 || s == 3 || s == 5;
  }

  double? _calcPenaltyPerHour(CargoTypeMini c) {
    final price = num.tryParse(c.deliveryPaidWaitPrice ?? '');
    final interval = c.deliveryPaidWaitIntervalMin;
    if (price == null || interval <= 0) return null;
    return price.toDouble() * 60.0 / interval;
  }

  List<TimelineStep> _timelineStepsCustomer(CustomerOrder o) {
    final steps = <TimelineStep>[
      TimelineStep(
        label: 'Yaratilgan',
        iconData: Icons.add_circle_outline_rounded,
        timeIso: o.createdAt,
      ),
      TimelineStep(
        label: 'Qabul qilindi',
        iconData: Icons.check_rounded,
        timeIso: o.acceptedAt,
      ),
      TimelineStep(
        label: 'Pickup\'ga yetib keldi',
        iconData: Icons.pin_drop_rounded,
        timeIso: o.arrivedPickupAt,
      ),
      TimelineStep(
        label: 'Yuklash boshlandi',
        iconData: Icons.downloading_rounded,
        timeIso: o.loadingStartedAt,
      ),
      TimelineStep(
        label: 'Yo\'lda',
        iconData: Icons.local_shipping_rounded,
        timeIso: o.inTransitAt,
      ),
      TimelineStep(
        label: 'Delivery\'ga yetib keldi',
        iconData: Icons.location_on_rounded,
        timeIso: o.arrivedDeliveryAt,
      ),
      TimelineStep(
        label: 'Tushirish boshlandi',
        iconData: Icons.unarchive_rounded,
        timeIso: o.unloadingStartedAt,
      ),
      TimelineStep(
        label: 'Yetkazildi',
        iconData: Icons.task_alt_rounded,
        timeIso: o.deliveredAt,
      ),
      TimelineStep(
        label: 'Yakunlandi',
        iconData: Icons.verified_rounded,
        timeIso: o.completedAt,
      ),
    ];
    if ((o.cancelledAt ?? '').isNotEmpty) {
      steps.add(TimelineStep(
        label: 'Bekor qilingan',
        iconData: Icons.cancel_rounded,
        timeIso: o.cancelledAt,
        note: o.cancelReason,
      ));
    }
    return steps;
  }

  void _showError(Object e) {
    if (!mounted) return;
    final msg = e is ApiException ? e.firstFieldMessage : 'Tarmoq xatosi: $e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await CustomerApi.instance.finishOrder(_order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buyurtma yakunlandi.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _cancel() async {
    final reason = await _askCancelReason();
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await CustomerApi.instance.cancelOrder(_order.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bekor qilindi.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<String?> _askCancelReason() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const _CancelReasonDialog(),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Marker _routeMarker(LatLng point, {required bool isStart}) {
    final color = isStart ? AppPalette.success : AppPalette.dangerLight;
    return Marker(
      point: point,
      width: 44,
      height: 56,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                isStart ? 'A' : 'B',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Container(width: 2, height: 8, color: color),
        ],
      ),
    );
  }

  Marker _driverMarker(LatLng point) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.teal,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _order.status;
    final p = _pickup;
    final d = _delivery;
    final hasAB = p != null && d != null;
    final initialCenter = hasAB
        ? LatLng((p.latitude + d.latitude) / 2, (p.longitude + d.longitude) / 2)
        : (p ?? d ?? _toshkent);
    final routePoints = _route?.points ?? (hasAB ? [p, d] : null);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.darkOn,
        elevation: 0,
        leading: _circleIconButton(Icons.arrow_back_rounded, () => Navigator.of(context).pop()),
        actions: [
          _circleIconButton(Icons.center_focus_strong_rounded, _fitMapToRoute),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: 12,
                  minZoom: 4,
                  maxZoom: 18,
                  onMapReady: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToRoute());
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.mening_ilovam',
                    subdomains: const ['a', 'b', 'c', 'd'],
                  ),
                  if (routePoints != null && routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: AppPalette.teal,
                          strokeWidth: 5,
                          borderColor: Colors.white.withValues(alpha: 0.9),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (p != null) _routeMarker(p, isStart: true),
                      if (d != null) _routeMarker(d, isStart: false),
                      if ((s == 3 || s == 4) && _acceptPoint != null) _driverMarker(_acceptPoint!),
                    ],
                  ),
                ],
              ),
            ),
            if (_routeLoading)
              const Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Yo‘l hisoblanmoqda…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.22,
              maxChildSize: 0.95,
              snap: true,
              snapSizes: const [0.22, 0.5, 0.95],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Fixed drag handle
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: cs.outlineVariant,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),

                      // Scrollable content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _order.orderNumber ?? 'Buyurtma #${_order.id}',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      _StatusChip(label: _statusLabel(s), status: s),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatMoney(_order.totalPrice),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: cs.primary,
                                          ),
                                    ),
                                    Text(
                                      _order.currency ?? 'UZS',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_order.deliveryDeadlineAt != null && (s ?? 0) >= 3)
                              DeadlineBanner(
                                deadlineAtIso: _order.deliveryDeadlineAt!,
                                slaHours: _order.slaHoursSnapshot,
                                deliveredAtIso: _order.deliveredAt,
                                latePenaltyAmount: _order.latePenaltyAmount,
                                penaltyPerHour: _order.cargoType != null
                                    ? _calcPenaltyPerHour(_order.cargoType!)
                                    : null,
                                isDriver: false,
                              ),
                            if (s == 5 && _order.loadingStartedAt != null && _order.cargoType != null)
                              _WaitCountdown(
                                startedAtIso: _order.loadingStartedAt!,
                                freeMinutes: _order.cargoType!.pickupFreeWaitMinutes,
                                paidPrice: _order.cargoType!.pickupPaidWaitPrice,
                                paidIntervalMin: _order.cargoType!.pickupPaidWaitIntervalMin,
                                label: 'Yuklash kutish vaqti',
                              ),
                            if (s == 8 && _order.unloadingStartedAt != null && _order.cargoType != null)
                              _WaitCountdown(
                                startedAtIso: _order.unloadingStartedAt!,
                                freeMinutes: _order.cargoType!.deliveryFreeWaitMinutes,
                                paidPrice: _order.cargoType!.deliveryPaidWaitPrice,
                                paidIntervalMin: _order.cargoType!.deliveryPaidWaitIntervalMin,
                                label: 'Tushirish kutish vaqti',
                              ),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Column(
                                children: [
                                  _AddressRow(
                                    isStart: true,
                                    label: 'Olib ketish',
                                    address: _order.pickupAddress ?? '—',
                                  ),
                                  const SizedBox(height: 8),
                                  const _DottedDivider(),
                                  const SizedBox(height: 8),
                                  _AddressRow(
                                    isStart: false,
                                    label: 'Yetkazish',
                                    address: _order.deliveryAddress ?? '—',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatTile(
                                    icon: Icons.straighten_rounded,
                                    label: 'Masofa',
                                    value: _order.distanceKm != null ? '${_order.distanceKm} km' : '—',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatTile(
                                    icon: Icons.scale_rounded,
                                    label: 'Yuk',
                                    value: _order.cargoWeightKg != null ? '${_order.cargoWeightKg} kg' : '—',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatTile(
                                    icon: Icons.category_outlined,
                                    label: 'Tur',
                                    value: _order.cargoType?.name ?? '—',
                                  ),
                                ),
                              ],
                            ),
                            if ((_order.comment ?? '').isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.tertiaryContainer.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.comment_outlined, size: 18, color: cs.onTertiaryContainer),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _order.comment!,
                                        style: TextStyle(color: cs.onTertiaryContainer, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            OrderTimeline(steps: _timelineStepsCustomer(_order)),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      // Fixed bottom action area
                      if (_isFinal || _canFinish || _canCancel)
                        Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            border: Border(
                              top: BorderSide(color: cs.outlineVariant, width: 0.6),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          child: SafeArea(
                            top: false,
                            child: _isFinal
                                ? Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.lock_outline_rounded),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text('Bu buyurtma yopiq.',
                                              style: TextStyle(height: 1.4)),
                                        ),
                                      ],
                                    ),
                                  )
                                : _canFinish
                                    ? SlideButton(
                                        label: 'Yakunlash uchun suring',
                                        icon: Icons.task_alt_rounded,
                                        onSlide: _finish,
                                      )
                                    : OutlinedButton.icon(
                                        onPressed: _busy ? null : _cancel,
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Bekor qilish'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: cs.error,
                                          side: BorderSide(color: cs.error.withValues(alpha: 0.6)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});

  final String label;
  final int? status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    switch (status) {
      case 2:
        bg = AppPalette.amber;
        fg = const Color(0xFF111827);
        break;
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
      case 8:
        bg = cs.primary;
        fg = cs.onPrimary;
        break;
      case 9:
      case 10:
        bg = AppPalette.success;
        fg = Colors.white;
        break;
      case 11:
      case 12:
        bg = AppPalette.dangerLight;
        fg = Colors.white;
        break;
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _WaitCountdown extends StatelessWidget {
  const _WaitCountdown({
    required this.startedAtIso,
    required this.freeMinutes,
    required this.paidPrice,
    required this.paidIntervalMin,
    required this.label,
  });

  final String startedAtIso;
  final int freeMinutes;
  final String? paidPrice;
  final int paidIntervalMin;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final started = DateTime.tryParse(startedAtIso);
    if (started == null) return const SizedBox.shrink();
    final elapsed = DateTime.now().toUtc().difference(started.toUtc());
    final freeSeconds = freeMinutes * 60;
    final remainingSec = freeSeconds - elapsed.inSeconds;
    final isPaid = remainingSec <= 0;
    final overSec = isPaid ? -remainingSec : 0;
    final paidIntervalSec = paidIntervalMin * 60;
    final paidIntervals = paidIntervalSec > 0 ? (overSec / paidIntervalSec).ceil() : 0;
    final priceNum = num.tryParse(paidPrice ?? '') ?? 0;
    final extraCost = paidIntervals * priceNum;

    String fmtMMSS(int totalSec) {
      final abs = totalSec.abs();
      final mm = abs ~/ 60;
      final ss = abs % 60;
      return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPaid ? AppPalette.dangerLight.withValues(alpha: 0.15) : AppPalette.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid ? AppPalette.dangerLight : AppPalette.success,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPaid ? Icons.payments_rounded : Icons.timer_rounded,
                color: isPaid ? AppPalette.dangerLight : AppPalette.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(
                fmtMMSS(remainingSec),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isPaid ? AppPalette.dangerLight : AppPalette.success,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isPaid
                ? 'Pullik kutish boshlangan. Qo\'shimcha: ${_money(extraCost.toString())} so\'m'
                : 'Bepul kutish vaqti — $freeMinutes daq.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _money(String raw) {
    final n = num.tryParse(raw);
    if (n == null) return raw;
    final i = n.round();
    final s = i.toString();
    final buf = StringBuffer();
    for (int k = 0; k < s.length; k++) {
      if (k > 0 && (s.length - k) % 3 == 0) buf.write(' ');
      buf.write(s[k]);
    }
    return buf.toString();
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.isStart, required this.label, required this.address});

  final bool isStart;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isStart ? AppPalette.success : AppPalette.dangerLight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              isStart ? 'A' : 'B',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DottedDivider extends StatelessWidget {
  const _DottedDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 11),
      child: Container(width: 2, height: 10, color: cs.outlineVariant),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog();

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  final _ctrl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.length < 3) {
      setState(() => _err = 'Sababni kamida 3 belgi kiriting');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bekor qilish sababi'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: 'Sabab *', errorText: _err),
        onChanged: (_) {
          if (_err != null) setState(() => _err = null);
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Yopish')),
        FilledButton(onPressed: _submit, child: const Text('Yuborish')),
      ],
    );
  }
}

String _formatMoney(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final n = num.tryParse(raw);
  if (n == null) return raw;
  final i = n.round();
  final neg = i < 0;
  final s = i.abs().toString();
  final buf = StringBuffer();
  for (int k = 0; k < s.length; k++) {
    if (k > 0 && (s.length - k) % 3 == 0) buf.write(' ');
    buf.write(s[k]);
  }
  return neg ? '-$buf' : buf.toString();
}
