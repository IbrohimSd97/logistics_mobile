import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/cancel_reasons_api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/deadline_banner.dart';
import '../../core/widgets/order_timeline.dart';
import '../../core/widgets/osrm_route.dart';
import '../../core/widgets/slide_button.dart';
import '../customer_api.dart';
import '../customer_models.dart';
import 'customer_order_create_page.dart';

class CustomerOrderDetailPage extends StatefulWidget {
  const CustomerOrderDetailPage({super.key, required this.order});

  final CustomerOrder order;

  @override
  State<CustomerOrderDetailPage> createState() => _CustomerOrderDetailPageState();
}

class _CustomerOrderDetailPageState extends State<CustomerOrderDetailPage>
    with I18nObserverMixin<CustomerOrderDetailPage> {
  static const _toshkent = LatLng(41.311081, 69.240562);

  bool _busy = false;
  bool _reloading = false;
  late CustomerOrder _order;
  final MapController _mapCtrl = MapController();
  OsrmRoute? _route;
  bool _routeLoading = false;
  Timer? _ticker;

  /// Driver'ning oxirgi GPS pozitsiyasi (backend'dan har 15 soniyada poll
  /// qilinadi). null bo'lsa eski statik `_acceptPoint` ishlatiladi.
  LatLng? _liveDriverLocation;
  Timer? _driverPollTimer;
  static const Duration _driverPollInterval = Duration(seconds: 15);

  /// Driver yo'nalishi (gradus) — ketma-ket polling natijalaridan hisoblanadi.
  /// Map'ni `-heading`'ga aylantirib heading-up rejimini amalga oshirish uchun.
  double _driverHeading = 0;
  LatLng? _prevDriverPollLoc;

  /// Customer xaritada driverga ergashish rejimi — driver pozitsiyasi
  /// yangilanganda map markazlashadi va aylanadi. Foydalanuvchi pan qilsa
  /// off bo'ladi; recenter FAB qaytadan yoqadi.
  bool _followDriver = true;
  DateTime? _lastProgrammaticCameraChange;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _refetchRoute();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _startDriverLocationPolling();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _driverPollTimer?.cancel();
    _mapCtrl.dispose();
    super.dispose();
  }

  /// Driver ko'rinishi kerak bo'lgan bosqichlarda har 15 soniyada
  /// backend'dan oxirgi lokatsiyani so'raymiz. Final/oldingi statuslarda
  /// poll qilmaymiz — bekorga server'ga so'rov yuborilmasin.
  void _startDriverLocationPolling() {
    _driverPollTimer?.cancel();
    // Darhol bir marta tortib olamiz, keyin har interval'da takrorlaymiz.
    _fetchDriverLocation();
    _driverPollTimer = Timer.periodic(_driverPollInterval, (_) {
      if (!mounted) return;
      _fetchDriverLocation();
    });
  }

  /// Rejali buyurtmada olib ketish vaqti hali kelmagan bo'lsa true.
  /// Bu paytda customer driverning joylashuvini ko'rmasligi kerak
  /// (privacy + foydasiz — driver hali harakatga chiqmagan).
  bool get _isScheduledBeforePickup {
    final iso = _order.scheduledPickupAt;
    if (iso == null) return false;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return false;
    return dt.isAfter(DateTime.now());
  }

  Future<void> _fetchDriverLocation() async {
    final s = _order.status;
    // Driver yo'lda bo'ladigan bosqichlar
    final isActive = s == 3 || s == 4 || s == 5 || s == 6 || s == 7 || s == 8;
    // Rejali buyurtmada vaqt kelmaguncha driver locationi ko'rinmasin —
    // server poll'lariga ham hojat yo'q.
    if (!isActive || _isScheduledBeforePickup) {
      if (_liveDriverLocation != null) {
        setState(() => _liveDriverLocation = null);
      }
      return;
    }
    try {
      final loc = await CustomerApi.instance.driverLocation(_order.id);
      if (!mounted) return;
      if (loc != null) {
        final newLoc = LatLng(loc.latitude, loc.longitude);

        // Ikki poll orasidagi yo'nalish (bearing) — driver harakat qilgandagina
        // heading saqlanadi. Juda kichik siljish — GPS shovqini deb e'tibordan
        // qoldiramiz.
        if (_prevDriverPollLoc != null) {
          final distance = _haversine(_prevDriverPollLoc!, newLoc);
          if (distance >= 10) {
            _driverHeading = _bearingDegrees(_prevDriverPollLoc!, newLoc);
            _prevDriverPollLoc = newLoc;
          }
        } else {
          _prevDriverPollLoc = newLoc;
        }

        setState(() => _liveDriverLocation = newLoc);

        // Heading-up follow: faol bosqichda map'ni driver'ga moslab
        // `-heading`'ga aylantiramiz.
        if (_followDriver && isActive) {
          try {
            final z = _mapCtrl.camera.zoom;
            final targetZoom = z < 13 ? 15.0 : z;
            _lastProgrammaticCameraChange = DateTime.now();
            _mapCtrl.moveAndRotate(newLoc, targetZoom, -_driverHeading);
          } catch (_) {
            // map hali ready emas
          }
        }
      }
    } catch (_) {
      // Sokin — keyingi tick qayta urinadi.
    }
  }

  /// Ikki nuqta orasidagi yo'nalish (gradus, 0=N).
  static double _bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2)
        - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return ((math.atan2(y, x) * 180 / math.pi) + 360) % 360;
  }

  static double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2)
        + math.cos(a.latitude * math.pi / 180)
            * math.cos(b.latitude * math.pi / 180)
            * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
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
    // Customer ko'rinishi — har doim A→B (olib ketish → yetkazib berish) yo'lini
    // chizamiz. Driver pozitsiyasi alohida marker bilan ko'rsatiladi, ammo
    // undan A gacha yo'l chizilmaydi (chunki bu customerga ortiqcha shovqin).
    // Loading/Unloading bosqichlarida (5, 8) ham A↔B saqlanadi (yo'l yashirilmas).
    if (s == 9 || s == 10 || s == 11 || s == 12) {
      // Yakunlangan/bekor qilingan — sentimental sifatida A↔B saqlanadi.
      return (_pickup, _delivery);
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

  /// Ichki map'ni A (pickup) nuqtaga markazlaydi va yaqinlashtiradi.
  /// Tashqi navigatsiya ilovasini ochmaydi — foydalanuvchi shu app ichida
  /// nuqtani aniq ko'rishi uchun.
  void _navigateToPickup() {
    final p = _pickup;
    if (p == null) return;
    _mapCtrl.move(p, 16.0);
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
        return I18n.t('order.status.new');
      case 2:
        return I18n.t('order.status.active');
      case 3:
        return I18n.t('order.status.accepted_full');
      case 4:
        return I18n.t('order.status.pickup_at');
      case 5:
        return I18n.t('order.status.loading_short');
      case 6:
        return I18n.t('order.status.in_transit_short');
      case 7:
        return I18n.t('order.status.delivery_at');
      case 8:
        return I18n.t('order.status.unloading');
      case 9:
        return I18n.t('order.status.delivered_short');
      case 10:
        return I18n.t('order.status.finished_short');
      case 11:
        return I18n.t('order.status.cancelled_short');
      case 12:
        return I18n.t('order.status.failed_short');
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
        label: I18n.t('order.detail.created'),
        iconData: Icons.add_circle_outline_rounded,
        timeIso: o.createdAt,
      ),
      TimelineStep(
        label: I18n.t('order.detail.accepted'),
        iconData: Icons.check_rounded,
        timeIso: o.acceptedAt,
      ),
      TimelineStep(
        label: I18n.t('order.detail.arrived_pickup'),
        iconData: Icons.pin_drop_rounded,
        timeIso: o.arrivedPickupAt,
      ),
      TimelineStep(
        label: I18n.t('order.detail.loading_started'),
        iconData: Icons.downloading_rounded,
        timeIso: o.loadingStartedAt,
      ),
      TimelineStep(
        label: I18n.t('order.detail.in_transit_label'),
        iconData: Icons.local_shipping_rounded,
        timeIso: o.inTransitAt,
      ),
      TimelineStep(
        label: I18n.t('order.detail.arrived_delivery'),
        iconData: Icons.location_on_rounded,
        timeIso: o.arrivedDeliveryAt,
      ),
      TimelineStep(
        label: I18n.t('order.detail.unloading_started'),
        iconData: Icons.unarchive_rounded,
        timeIso: o.unloadingStartedAt,
      ),
      TimelineStep(
        label: I18n.t('order.detail.delivered'),
        iconData: Icons.task_alt_rounded,
        timeIso: o.deliveredAt,
      ),
      TimelineStep(
        label: I18n.t('order.detail.finished'),
        iconData: Icons.verified_rounded,
        timeIso: o.completedAt,
      ),
    ];
    if ((o.cancelledAt ?? '').isNotEmpty) {
      steps.add(TimelineStep(
        label: I18n.t('order.detail.cancelled'),
        iconData: Icons.cancel_rounded,
        timeIso: o.cancelledAt,
        note: _renderCancelReason(o),
      ));
    }
    return steps;
  }

  /// Bekor qilingan buyurtmaning sababini ko'rinadigan satrga aylantiradi:
  /// - catalog sabab tanlangan bo'lsa joriy lokaldagi nom;
  /// - "Boshqa" tanlangan bo'lsa: "<label>: <custom matn>";
  /// - faqat eski matn bo'lsa (cancel_reason_id=NULL): shu matnning o'zi.
  String? _renderCancelReason(CustomerOrder o) {
    final info = o.cancelReasonInfo;
    final raw = o.cancelReason?.trim();
    if (info != null) {
      final code = I18n.instance.code;
      final label = code == 'ru' ? info.nameRu : info.nameUz;
      if (info.isOther && raw != null && raw.isNotEmpty) {
        return '$label: $raw';
      }
      return label;
    }
    return (raw != null && raw.isNotEmpty) ? raw : null;
  }

  void _showError(Object e) {
    if (!mounted) return;
    final msg = e is ApiException
        ? e.firstFieldMessage
        : I18n.t('order.detail.network_error_label', {'msg': '$e'});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await CustomerApi.instance.finishOrder(_order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('order.detail.order_finished_msg'))),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _cancel() async {
    final picked = await _askCancelReason();
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await CustomerApi.instance.cancelOrder(
        _order.id,
        cancelReasonId: picked.reasonId,
        customText: picked.customText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('order.detail.cancelled_msg'))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<_CancelReasonChoice?> _askCancelReason() async {
    // Sabablar ro'yxatini avval yuklab olamiz (cache'lanadi). Network xato
    // bo'lsa snackbar bilan xabar va dialog ochilmaydi.
    List<CancelReason> reasons;
    try {
      reasons = await CustomerApi.instance.cancelReasons();
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('order.cancel.load_failed'))),
      );
      return null;
    }
    if (!mounted) return null;
    return showDialog<_CancelReasonChoice>(
      context: context,
      builder: (ctx) => _CancelReasonDialog(reasons: reasons),
    );
  }

  /// Buyurtmani takrorlash — order create page'ni shu order ma'lumotlari bilan
  /// to'ldirilgan holda ochadi. Detail page yopiladi va orders tab'iga qaytadi.
  void _repeatOrder() {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerOrderCreatePage(
          prefillCargoTypeId: _order.cargoType?.id,
          prefillPickupAddress: _order.pickupAddress,
          prefillPickupLat: _order.pickupLat,
          prefillPickupLng: _order.pickupLng,
          prefillDeliveryAddress: _order.deliveryAddress,
          prefillDeliveryLat: _order.deliveryLat,
          prefillDeliveryLng: _order.deliveryLng,
          prefillCargoWeightKg: _order.cargoWeightKg,
          prefillComment: _order.comment,
        ),
      ),
    );
  }

  /// Buyurtmani server'dan qayta yuklash — current va archive ro'yxatlarini
  /// chaqirib, mos ID'ni topadi. Backend hozircha alohida `GET orders/{id}`
  /// endpoint chiqarmagani uchun shu yo'l ishlatiladi. Ma'lumotni yangilab
  /// route'ni va driver location'ni qayta ishga tushiramiz.
  Future<void> _reloadOrder() async {
    if (_reloading) return;
    setState(() => _reloading = true);
    try {
      final list = await Future.wait<List<CustomerOrder>>([
        CustomerApi.instance.currentOrders(),
        CustomerApi.instance.archiveOrders(),
      ]);
      final all = <CustomerOrder>[...list[0], ...list[1]];
      CustomerOrder? found;
      for (final o in all) {
        if (o.id == _order.id) {
          found = o;
          break;
        }
      }
      if (!mounted) return;
      if (found != null) {
        setState(() => _order = found!);
        await _refetchRoute();
        unawaited(_fetchDriverLocation());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('order.detail.not_found'))),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.firstFieldMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t('common.network_error')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _reloading = false);
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

  /// Driver markeri customer xaritasi uchun. Map heading-up'ga aylantirilgan
  /// bo'lsa, `rotate: true` orqali marker screen-aligned ushlanadi va
  /// navigatsiya arrow doim "yuqori = oldinga" ko'rinadi.
  Marker _driverMarker(LatLng point) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      alignment: Alignment.center,
      rotate: true,
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.teal,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
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
          _circleIconButton(
            _reloading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
            _reloading ? () {} : _reloadOrder,
          ),
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
                  initialRotation: 0,
                  minZoom: 4,
                  maxZoom: 18,
                  // Rotation gesture'lari yoqilgan — foydalanuvchi 2 barmoq
                  // bilan o'zi map'ni aylantirishi mumkin.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onMapReady: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToRoute());
                  },
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture && _followDriver) {
                      final last = _lastProgrammaticCameraChange;
                      if (last != null &&
                          DateTime.now().difference(last).inMilliseconds < 200) {
                        return;
                      }
                      setState(() => _followDriver = false);
                    }
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
                      // Driver markeri — real-vaqt poll'dan kelgan lokatsiya
                      // ustunlik qiladi, fallback — accept_lat/lng (statik).
                      // Faqat driver yo'lda bo'lgan bosqichlarda ko'rsatamiz.
                      // Rejali buyurtmada olib ketish vaqti kelmaguncha
                      // driver locationi customerga ko'rinmaydi.
                      if ((s == 3 || s == 4 || s == 6 || s == 7 || s == 8) &&
                          !_isScheduledBeforePickup &&
                          (_liveDriverLocation ?? _acceptPoint) != null)
                        _driverMarker((_liveDriverLocation ?? _acceptPoint)!),
                    ],
                  ),
                ],
              ),
            ),
            if (_routeLoading)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text(I18n.t('order.detail.route_calculating')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // "A nuqtaga yo'l boshlash" tugmasi — map'ning o'ng pastida,
            // pastki sheet ustida (sheet'ning minimal balandligi ~0.22 ekran +
            // navigatsiya bezab). Foydalanuvchi tezda tashqi maps ilovasini ochadi.
            if (_pickup != null)
              Positioned(
                right: 14,
                bottom: MediaQuery.of(context).size.height * 0.22 + 14,
                child: SafeArea(
                  child: FloatingActionButton.extended(
                    heroTag: 'nav_to_pickup',
                    onPressed: _navigateToPickup,
                    icon: const Icon(Icons.directions_rounded),
                    label: Text(I18n.t('order.detail.nav_to_a')),
                  ),
                ),
              ),
            // Driver mavjud va faol bosqichda bo'lsa — follow-driver FAB
            // (turn-by-turn rejimi yoqilgan/o'chgan vizual ko'rsatkichi).
            if ((s == 3 || s == 4 || s == 6 || s == 7 || s == 8) &&
                !_isScheduledBeforePickup &&
                _liveDriverLocation != null)
              Positioned(
                right: 14,
                bottom: MediaQuery.of(context).size.height * 0.22 + 84,
                child: Material(
                  color: _followDriver ? cs.primaryContainer : cs.surface,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      _lastProgrammaticCameraChange = DateTime.now();
                      _mapCtrl.moveAndRotate(
                        _liveDriverLocation!, 15, -_driverHeading,
                      );
                      if (!_followDriver) {
                        setState(() => _followDriver = true);
                      }
                    },
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        _followDriver ? Icons.my_location_rounded : Icons.location_searching_rounded,
                        color: _followDriver ? cs.onPrimaryContainer : cs.primary,
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
                                        _order.orderNumber ?? I18n.t('customer.order_number_fallback', {'id': _order.id}),
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
                                      _order.currency ?? I18n.t('common.uzs'),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_order.scheduledPickupAt != null) ...[
                              _ScheduledPickupBanner(
                                scheduledAtIso: _order.scheduledPickupAt!,
                              ),
                              const SizedBox(height: 10),
                            ],
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
                                label: I18n.t('order.detail.loading_wait_label'),
                              ),
                            if (s == 8 && _order.unloadingStartedAt != null && _order.cargoType != null)
                              _WaitCountdown(
                                startedAtIso: _order.unloadingStartedAt!,
                                freeMinutes: _order.cargoType!.deliveryFreeWaitMinutes,
                                paidPrice: _order.cargoType!.deliveryPaidWaitPrice,
                                paidIntervalMin: _order.cargoType!.deliveryPaidWaitIntervalMin,
                                label: I18n.t('order.detail.unloading_wait_label'),
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
                                    label: I18n.t('order.detail.address_pickup'),
                                    address: _order.pickupAddress ?? '—',
                                  ),
                                  const SizedBox(height: 8),
                                  const _DottedDivider(),
                                  const SizedBox(height: 8),
                                  _AddressRow(
                                    isStart: false,
                                    label: I18n.t('order.detail.address_delivery'),
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
                                    label: I18n.t('order.detail.distance_label'),
                                    value: _order.distanceKm != null ? '${_order.distanceKm} ${I18n.t('common.km')}' : '—',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatTile(
                                    icon: Icons.scale_rounded,
                                    label: I18n.t('order.detail.cargo_label'),
                                    value: _order.cargoWeightKg != null ? '${_order.cargoWeightKg} ${I18n.t('common.kg')}' : '—',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatTile(
                                    icon: Icons.category_outlined,
                                    label: I18n.t('order.detail.type_label'),
                                    value: _order.cargoType?.name ?? '—',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Narx tafsilotlari: jami, loyiha komissiyasi va avtopark
                            // komissiyasi (foiz + summa). Driver Accept qilmaguncha
                            // company_* qiymatlari 0; project_* esa order yaratilganda
                            // belgilanadi (Project default 5%).
                            _PriceBreakdownCard(order: _order),
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
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.lock_outline_rounded),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(I18n.t('order.detail.order_closed'),
                                                  style: const TextStyle(height: 1.4)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Buyurtmani takrorlash — order create page'ni
                                      // shu order ma'lumotlari bilan to'ldirib ochadi.
                                      FilledButton.icon(
                                        onPressed: _repeatOrder,
                                        icon: const Icon(Icons.repeat_rounded),
                                        label: Text(I18n.t('order.detail.repeat_order')),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size.fromHeight(48),
                                        ),
                                      ),
                                    ],
                                  )
                                : _canFinish
                                    ? SlideButton(
                                        label: I18n.t('order.detail.finish_slide'),
                                        icon: Icons.task_alt_rounded,
                                        onSlide: _finish,
                                      )
                                    : OutlinedButton.icon(
                                        onPressed: _busy ? null : _cancel,
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: Text(I18n.t('order.detail.cancel_btn')),
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

/// Rejali olib ketish vaqti banner — order.scheduled_pickup_at bo'lsa
/// detail sahifa tepasida (DeadlineBanner'dan oldin) ko'rsatiladi.
/// Sana, soat va countdown bir qarashda ko'rinadi.
class _ScheduledPickupBanner extends StatefulWidget {
  const _ScheduledPickupBanner({required this.scheduledAtIso});

  final String scheduledAtIso;

  @override
  State<_ScheduledPickupBanner> createState() => _ScheduledPickupBannerState();
}

class _ScheduledPickupBannerState extends State<_ScheduledPickupBanner> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Countdown bir daqiqada bir marta yangilansin (60 sek aniqlik yetarli).
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _fmtFull(DateTime dt) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _countdown(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return I18n.t('order.detail.countdown_passed');
    if (diff.inDays >= 1) {
      final hh = diff.inHours.remainder(24);
      return I18n.t('order.detail.countdown_days_hours', {'d': diff.inDays, 'h': hh});
    }
    if (diff.inHours >= 1) {
      return I18n.t('order.detail.countdown_hours_minutes',
          {'h': diff.inHours, 'm': diff.inMinutes.remainder(60)});
    }
    return I18n.t('order.detail.countdown_minutes', {'m': diff.inMinutes});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dt = DateTime.tryParse(widget.scheduledAtIso)?.toLocal();
    if (dt == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_rounded, color: cs.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.t('order.detail.scheduled_pickup_label'),
                  style: TextStyle(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtFull(dt),
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _countdown(dt),
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

    String fmtHHMMSS(int totalSec) {
      final abs = totalSec.abs();
      final hh = abs ~/ 3600;
      final mm = (abs % 3600) ~/ 60;
      final ss = abs % 60;
      final sign = totalSec < 0 ? '-' : '';
      return '$sign${hh.toString().padLeft(2, '0')}:'
          '${mm.toString().padLeft(2, '0')}:'
          '${ss.toString().padLeft(2, '0')}';
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
                fmtHHMMSS(remainingSec),
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
                ? I18n.t('order.detail.paid_waiting_started', {'amount': _money(extraCost.toString())})
                : I18n.t('order.detail.free_waiting', {'minutes': freeMinutes}),
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

/// Dialog natijasi — tanlangan sabab IDsi va (Boshqa tanlansa) custom matn.
class _CancelReasonChoice {
  const _CancelReasonChoice({required this.reasonId, this.customText});
  final int reasonId;
  final String? customText;
}

class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog({required this.reasons});

  final List<CancelReason> reasons;

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  int? _selectedId;
  final _otherCtrl = TextEditingController();
  String? _pickErr;
  String? _otherErr;

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  bool get _selectedIsOther {
    if (_selectedId == null) return false;
    final r = widget.reasons.firstWhere(
      (e) => e.id == _selectedId,
      orElse: () => widget.reasons.first,
    );
    return r.isOther;
  }

  void _submit() {
    if (_selectedId == null) {
      setState(() => _pickErr = I18n.t('order.cancel.pick_required'));
      return;
    }
    String? custom;
    if (_selectedIsOther) {
      final v = _otherCtrl.text.trim();
      if (v.length < 3) {
        setState(() => _otherErr = I18n.t('order.cancel.other_required'));
        return;
      }
      custom = v;
    }
    Navigator.pop(context, _CancelReasonChoice(reasonId: _selectedId!, customText: custom));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(I18n.t('order.cancel.pick_title')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in widget.reasons)
                RadioListTile<int>(
                  value: r.id,
                  groupValue: _selectedId,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.displayName),
                  onChanged: (v) => setState(() {
                    _selectedId = v;
                    _pickErr = null;
                    if (!_selectedIsOther) _otherErr = null;
                  }),
                ),
              if (_pickErr != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(_pickErr!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                ),
              if (_selectedIsOther)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _otherCtrl,
                    autofocus: true,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: I18n.t('order.cancel.other_hint'),
                      errorText: _otherErr,
                    ),
                    onChanged: (_) {
                      if (_otherErr != null) setState(() => _otherErr = null);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(I18n.t('common.close'))),
        FilledButton(onPressed: _submit, child: Text(I18n.t('order.cancel.confirm_btn'))),
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

String _formatPct(num pct) {
  if (pct == 0) return '0%';
  return '${pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1)}%';
}

/// Customer order detail uchun narx tafsiloti karta:
/// jami, loyiha komissiyasi, avtopark komissiyasi va (mavjud bo'lsa) jarima.
/// Foiz va summa har biri ko'rinadi — agar summa hali yo'q (driver hali
/// Accept qilmagan) bo'lsa, foizdan total bilan hisoblab ko'rsatamiz.
class _PriceBreakdownCard extends StatelessWidget {
  const _PriceBreakdownCard({required this.order});

  final CustomerOrder order;

  num _n(String? s) => num.tryParse(s ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = order.currency ?? I18n.t('common.uzs');

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

    return AnimatedBuilder(
      animation: I18n.instance,
      builder: (_, __) {
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
                  Icon(Icons.receipt_long_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    I18n.t('order.price_breakdown'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _BreakdownRow(
                label: I18n.t('order.total_price'),
                value: total,
                currency: currency,
                isMain: true,
              ),
              const SizedBox(height: 6),
              _BreakdownRow(
                label: '${I18n.t('order.commission_project')} (${_formatPct(projectPct)})',
                value: projectAmt,
                currency: currency,
                muted: true,
              ),
              const SizedBox(height: 6),
              _BreakdownRow(
                label: '${I18n.t('order.commission_avtopark')} (${_formatPct(companyPct)})',
                value: companyAmt,
                currency: currency,
                muted: true,
              ),
              if (penalty > 0) ...[
                const SizedBox(height: 6),
                _BreakdownRow(
                  label: I18n.t('order.late_penalty'),
                  value: penalty,
                  currency: currency,
                  isDeduction: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.currency,
    this.isMain = false,
    this.isDeduction = false,
    this.muted = false,
  });

  final String label;
  final num value;
  final String currency;
  final bool isMain;
  final bool isDeduction;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDeduction
        ? cs.error
        : (muted ? cs.onSurfaceVariant : cs.onSurface);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted ? cs.onSurfaceVariant : cs.onSurface,
              fontWeight: isMain ? FontWeight.w700 : FontWeight.w500,
              fontSize: isMain ? 14 : 13,
            ),
          ),
        ),
        Text(
          '${_formatMoney(value.toString())} $currency',
          style: TextStyle(
            color: color,
            fontWeight: isMain ? FontWeight.w800 : FontWeight.w600,
            fontSize: isMain ? 14 : 13,
          ),
        ),
      ],
    );
  }
}
