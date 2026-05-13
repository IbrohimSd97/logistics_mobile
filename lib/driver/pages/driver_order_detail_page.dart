import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/deadline_banner.dart';
import '../../core/widgets/location_picker_page.dart';
import '../../core/widgets/order_timeline.dart';
import '../../core/widgets/osrm_route.dart';
import '../../core/widgets/slide_button.dart';
import '../../screens/driver_main_shell.dart' show statusLabelDriver;
import '../driver_api.dart';
import '../driver_models.dart';

class DriverOrderDetailPage extends StatefulWidget {
  const DriverOrderDetailPage({
    super.key,
    required this.order,
    this.initialDriverLocation,
  });

  final DriverOrder order;
  final LatLng? initialDriverLocation;

  @override
  State<DriverOrderDetailPage> createState() => _DriverOrderDetailPageState();
}

class _DriverOrderDetailPageState extends State<DriverOrderDetailPage> {
  static const _toshkent = LatLng(41.311081, 69.240562);

  bool _busy = false;
  late DriverOrder _order;
  final MapController _mapCtrl = MapController();

  OsrmRoute? _route;
  bool _routeLoading = false;
  Timer? _waitTicker;

  // Auto-transition: status==5 (Loading) bo'lganda GPS oqimini ochib,
  // pickup'dan 100m uzoqlashganda avtomat in-transit'ga o'tkazadi.
  StreamSubscription<Position>? _gpsSub;
  bool _autoTransitionTriggered = false;
  static const double _autoTransitionDistanceM = 100.0;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _refetchRoute();
    _waitTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _maybeStartAutoTransitionTracker();
  }

  @override
  void dispose() {
    _waitTicker?.cancel();
    _gpsSub?.cancel();
    _mapCtrl.dispose();
    super.dispose();
  }

  /// Status==5 (Loading) bo'lsa GPS oqimini ochamiz. Pickup'dan 100m uzoqlashilsa,
  /// avtomat InTransit (status=6)ga o'tkazamiz. Permission yo'q bo'lsa jimgina o'tib ketamiz.
  Future<void> _maybeStartAutoTransitionTracker() async {
    if (_order.status != 5 || _pickup == null) return;
    if (_gpsSub != null) return;

    // Permission tekshiruv
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
    } catch (_) {
      return;
    }

    final pickupLatLng = _pickup!;
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10m'dan kichik o'zgarishlarni e'tiborga olmaymiz
      ),
    ).listen((pos) async {
      if (_autoTransitionTriggered || _order.status != 5) return;
      final dist = Geolocator.distanceBetween(
        pickupLatLng.latitude,
        pickupLatLng.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist >= _autoTransitionDistanceM) {
        _autoTransitionTriggered = true;
        try {
          await DriverApi.instance.inTransit(_order.id);
          if (!mounted) return;
          setState(() => _order = _orderWithStatus(6));
          await _gpsSub?.cancel();
          _gpsSub = null;
          _refetchRoute();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pickup\'dan 100m uzoqlashdingiz — yo\'lda status faollashtirildi.')),
          );
        } catch (e) {
          _autoTransitionTriggered = false;
        }
      }
    }, onError: (_) {});
  }

  LatLng? get _pickup => (_order.pickupLat != null && _order.pickupLng != null)
      ? LatLng(_order.pickupLat!, _order.pickupLng!)
      : null;

  LatLng? get _delivery => (_order.deliveryLat != null && _order.deliveryLng != null)
      ? LatLng(_order.deliveryLat!, _order.deliveryLng!)
      : null;

  LatLng? get _acceptPoint => (_order.acceptLat != null && _order.acceptLng != null)
      ? LatLng(_order.acceptLat!, _order.acceptLng!)
      : widget.initialDriverLocation;

  /// Bosqichga qarab qaysi nuqtadan qaysi nuqtagacha chiziq ko'rsatamiz.
  /// - status==3 (Accepted): driver → A (pickup)
  /// - status==6 (InTransit): A → B (delivery)
  /// - boshqa: A → B (umumiy ko'rinish)
  (LatLng?, LatLng?) get _stageRoute {
    final s = _order.status;
    if (s == 3 || s == 4) {
      final from = _acceptPoint ?? _pickup;
      return (from, _pickup);
    }
    if (s == 5) {
      // Loading — pickup'da turibmiz, marshrut yo'q
      return (null, null);
    }
    if (s == 6) {
      return (_pickup, _delivery);
    }
    if (s == 7 || s == 8 || s == 9) {
      return (null, null);
    }
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

  void _showError(Object e) {
    if (!mounted) return;
    final msg = e is ApiException ? e.firstFieldMessage : 'Tarmoq xatosi: $e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _doAction(Future<void> Function() fn, {required int newStatus}) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _order = _orderWithStatus(newStatus);
      });
      // status o'zgargach yangi bosqich uchun route'ni qayta olamiz
      _refetchRoute();
      // Auto-transition tracker — status==5 boshlanganda yoqamiz, boshqasiga o'tsa uchiramiz
      if (newStatus == 5) {
        _autoTransitionTriggered = false;
        _maybeStartAutoTransitionTracker();
      } else {
        await _gpsSub?.cancel();
        _gpsSub = null;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(e);
      rethrow;
    }
  }

  List<TimelineStep> _timelineStepsDriver(DriverOrder o) {
    final steps = <TimelineStep>[
      TimelineStep(
        label: 'Yaratilgan',
        iconData: Icons.add_circle_outline_rounded,
        timeIso: o.createdAt,
      ),
      TimelineStep(
        label: 'Qabul qilingan',
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
        label: 'Yo\'lga chiqdi',
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

  double? _calcPenaltyPerHour(CargoTypeMini c) {
    final price = num.tryParse(c.deliveryPaidWaitPrice ?? '');
    final interval = c.deliveryPaidWaitIntervalMin;
    if (price == null || interval <= 0) return null;
    return price.toDouble() * 60.0 / interval;
  }

  DriverOrder _orderWithStatus(int newStatus) {
    return DriverOrder(
      id: _order.id,
      orderNumber: _order.orderNumber,
      status: newStatus,
      totalPrice: _order.totalPrice,
      basePrice: _order.basePrice,
      distanceKm: _order.distanceKm,
      distanceM: _order.distanceM,
      currency: _order.currency,
      pickupAddress: _order.pickupAddress,
      pickupLat: _order.pickupLat,
      pickupLng: _order.pickupLng,
      deliveryAddress: _order.deliveryAddress,
      deliveryLat: _order.deliveryLat,
      deliveryLng: _order.deliveryLng,
      acceptLat: _order.acceptLat,
      acceptLng: _order.acceptLng,
      cargoWeightKg: _order.cargoWeightKg,
      comment: _order.comment,
      createdAt: _order.createdAt,
      cargoType: _order.cargoType,
      acceptedAt: _order.acceptedAt,
      arrivedPickupAt: _order.arrivedPickupAt,
      loadingStartedAt: newStatus == 5 ? DateTime.now().toIso8601String() : _order.loadingStartedAt,
      inTransitAt: _order.inTransitAt,
      arrivedDeliveryAt: _order.arrivedDeliveryAt,
      unloadingStartedAt: newStatus == 8 ? DateTime.now().toIso8601String() : _order.unloadingStartedAt,
      deliveredAt: newStatus == 9 ? DateTime.now().toIso8601String() : _order.deliveredAt,
      deliveryDeadlineAt: _order.deliveryDeadlineAt,
      slaHoursSnapshot: _order.slaHoursSnapshot,
      latePenaltyAmount: _order.latePenaltyAmount,
    );
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _accept() async {
    final pick = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute<LocationPickerResult>(
        builder: (_) => LocationPickerPage(
          title: 'Joriy joylashuvingizni tasdiqlang',
          initialLatLng: widget.initialDriverLocation,
        ),
      ),
    );
    if (pick == null || !mounted) return;
    await _doAction(
      () => DriverApi.instance.acceptOrder(
        orderId: _order.id,
        acceptLat: pick.latLng.latitude,
        acceptLng: pick.latLng.longitude,
      ),
      newStatus: 3,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _arrivedPickup() async =>
      _doAction(() => DriverApi.instance.arrivedPickup(_order.id), newStatus: 5);

  Future<void> _inTransit() async =>
      _doAction(() => DriverApi.instance.inTransit(_order.id), newStatus: 6);

  Future<void> _arrivedDelivery() async =>
      _doAction(() => DriverApi.instance.arrivedDelivery(_order.id), newStatus: 8);

  Future<void> _delivered() async =>
      _doAction(() => DriverApi.instance.delivered(_order.id), newStatus: 9);

  Future<void> _cancel() async {
    final reason = await _askCancelReason();
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await DriverApi.instance.cancelOrder(orderId: _order.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buyurtma bekor qilindi.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<String?> _askCancelReason() => showDialog<String>(
        context: context,
        builder: (ctx) => const _CancelReasonDialog(),
      );

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _order.status;
    final isFinal = s == 9 || s == 10 || s == 11 || s == 12;

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
                      if ((s == 3 || s == 4) && _acceptPoint != null)
                        _driverMarker(_acceptPoint!),
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
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
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
                      // ── Fixed drag handle ──
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

                      // ── Scrollable content ──
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
                                      _StatusChip(status: s),
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
                            _StageHint(status: s, distanceKm: _route?.distanceKm),
                            const SizedBox(height: 14),
                            // Deadline banner — accept'dan keyin doim ko'rinadi
                            if (_order.deliveryDeadlineAt != null && (s ?? 0) >= 3)
                              DeadlineBanner(
                                deadlineAtIso: _order.deliveryDeadlineAt!,
                                slaHours: _order.slaHoursSnapshot,
                                deliveredAtIso: _order.deliveredAt,
                                latePenaltyAmount: _order.latePenaltyAmount,
                                penaltyPerHour: _order.cargoType != null
                                    ? _calcPenaltyPerHour(_order.cargoType!)
                                    : null,
                                isDriver: true,
                              ),
                            if (s == 5 && _order.loadingStartedAt != null && _order.cargoType != null)
                              _WaitCountdown(
                                startedAtIso: _order.loadingStartedAt!,
                                freeMinutes: _order.cargoType!.pickupFreeWaitMinutes,
                                paidPrice: _order.cargoType!.pickupPaidWaitPrice,
                                paidIntervalMin: _order.cargoType!.pickupPaidWaitIntervalMin,
                                label: 'Yuklash — kutish vaqti',
                              ),
                            if (s == 8 && _order.unloadingStartedAt != null && _order.cargoType != null)
                              _WaitCountdown(
                                startedAtIso: _order.unloadingStartedAt!,
                                freeMinutes: _order.cargoType!.deliveryFreeWaitMinutes,
                                paidPrice: _order.cargoType!.deliveryPaidWaitPrice,
                                paidIntervalMin: _order.cargoType!.deliveryPaidWaitIntervalMin,
                                label: 'Tushirish — kutish vaqti',
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
                            _IncomeBreakdown(order: _order),
                            const SizedBox(height: 14),
                            OrderTimeline(steps: _timelineStepsDriver(_order)),
                            if (s == 9) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cs.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.hourglass_top_rounded, color: cs.onTertiaryContainer),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Mijoz "Finish" bossa, summa hamyoningizga o‘tadi.',
                                        style: TextStyle(color: cs.onTertiaryContainer, height: 1.35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      // ── Fixed bottom action area ──
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFinal)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_outline_rounded, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Bu buyurtma bo‘yicha amallar mavjud emas.',
                                          style: TextStyle(height: 1.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                _slideForStatus(s),
                              if (s == 3) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _busy ? null : _cancel,
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Bekor qilish'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: cs.error,
                                    side: BorderSide(color: cs.error.withValues(alpha: 0.6)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ],
                            ],
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

  Widget _slideForStatus(int? s) {
    switch (s) {
      case 2:
        return SlideButton(
          label: 'Qabul qilish uchun suring',
          icon: Icons.check_rounded,
          onSlide: _accept,
        );
      case 3:
        return SlideButton(
          label: 'Pickup\'ga keldim — suring',
          icon: Icons.pin_drop_rounded,
          onSlide: _arrivedPickup,
        );
      case 5:
        return SlideButton(
          label: 'Yo\'lga chiqdim — suring',
          icon: Icons.local_shipping_rounded,
          onSlide: _inTransit,
        );
      case 6:
        return SlideButton(
          label: 'Delivery\'ga keldim — suring',
          icon: Icons.location_on_rounded,
          onSlide: _arrivedDelivery,
        );
      case 8:
        return SlideButton(
          label: 'Yuk tushirildi — suring',
          icon: Icons.task_alt_rounded,
          onSlide: _delivered,
        );
      default:
        return const SizedBox.shrink();
    }
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

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
      child: Text(
        statusLabelDriver(status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _StageHint extends StatelessWidget {
  const _StageHint({required this.status, this.distanceKm});

  final int? status;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String? text;
    IconData icon = Icons.route_rounded;
    switch (status) {
      case 3:
      case 4:
        text = 'A nuqtagacha ${distanceKm != null ? distanceKm!.toStringAsFixed(1) : '—'} km — pickup\'ga yetib boring';
        icon = Icons.pin_drop_rounded;
        break;
      case 5:
        text = 'Pickup\'da yuklash bosqichi';
        icon = Icons.downloading_rounded;
        break;
      case 6:
        text = 'B nuqtagacha ${distanceKm != null ? distanceKm!.toStringAsFixed(1) : '—'} km — yetkazib boring';
        icon = Icons.local_shipping_rounded;
        break;
      case 7:
      case 8:
        text = 'Delivery\'da tushirish bosqichi';
        icon = Icons.unarchive_rounded;
        break;
      case 9:
        text = 'Yuk yetkazildi — mijoz tasdiqlashini kutamiz';
        icon = Icons.hourglass_top_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: cs.onPrimaryContainer, height: 1.35, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
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
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                fmtMMSS(remainingSec),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isPaid ? AppPalette.dangerLight : AppPalette.success,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
      child: SizedBox(
        height: 10,
        child: Row(
          children: List.generate(
            1,
            (_) => Container(width: 2, height: 10, color: cs.outlineVariant),
          ),
        ),
      ),
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

class _IncomeBreakdown extends StatelessWidget {
  const _IncomeBreakdown({required this.order});

  final DriverOrder order;

  num _n(String? s) => num.tryParse(s ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final total = _n(order.totalPrice);
    final projectPct = _n(order.projectCommissionPct);
    final companyPct = _n(order.companyCommissionPct);
    final projectAmt = order.projectCommissionAmount != null
        ? _n(order.projectCommissionAmount)
        : (total * projectPct / 100);
    final companyAmt = order.companyCommissionAmount != null
        ? _n(order.companyCommissionAmount)
        : (total * companyPct / 100);
    final penalty = _n(order.latePenaltyAmount);
    final settledIncome = order.driverIncomeAmount != null
        ? _n(order.driverIncomeAmount)
        : (total - projectAmt - companyAmt);
    final netIncome = settledIncome - penalty;

    final isSettled = order.driverIncomeAmount != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Foyda hisoboti',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              if (!isSettled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Taxminiy',
                    style: TextStyle(
                      color: cs.onTertiaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _IncomeRow(
            label: 'Buyurtma narxi',
            value: total,
            isMain: true,
          ),
          const SizedBox(height: 6),
          _IncomeRow(
            label: 'Loyiha komissiyasi (${_formatPct(projectPct)})',
            value: -projectAmt,
            isDeduction: true,
          ),
          const SizedBox(height: 6),
          _IncomeRow(
            label: 'Avtopark komissiyasi (${_formatPct(companyPct)})',
            value: -companyAmt,
            isDeduction: true,
          ),
          if (penalty > 0) ...[
            const SizedBox(height: 6),
            _IncomeRow(
              label: 'Kechikish jarimasi',
              value: -penalty,
              isDeduction: true,
            ),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 10),
          _IncomeRow(
            label: 'Sof foyda',
            value: netIncome,
            isMain: true,
            highlight: true,
          ),
        ],
      ),
    );
  }

  String _formatPct(num pct) {
    if (pct == 0) return '0%';
    return '${pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1)}%';
  }
}

class _IncomeRow extends StatelessWidget {
  const _IncomeRow({
    required this.label,
    required this.value,
    this.isMain = false,
    this.isDeduction = false,
    this.highlight = false,
  });

  final String label;
  final num value;
  final bool isMain;
  final bool isDeduction;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = highlight
        ? cs.primary
        : (isDeduction ? cs.error : cs.onSurface);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isMain ? cs.onSurface : cs.onSurfaceVariant,
              fontWeight: isMain ? FontWeight.w700 : FontWeight.w500,
              fontSize: isMain ? 14 : 13,
            ),
          ),
        ),
        Text(
          '${_formatMoney(value.toString())} so\'m',
          style: TextStyle(
            color: color,
            fontWeight: isMain ? FontWeight.w800 : FontWeight.w600,
            fontSize: highlight ? 16 : (isMain ? 14 : 13),
          ),
        ),
      ],
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
