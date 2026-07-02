import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/cancel_reasons_api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/location/map_markers.dart';
import '../../core/location/yandex_point.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/deadline_banner.dart';
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

class _DriverOrderDetailPageState extends State<DriverOrderDetailPage>
    with I18nObserverMixin<DriverOrderDetailPage> {
  static const _toshkent = LatLng(41.311081, 69.240562);

  bool _busy = false;
  bool _reloading = false;
  late DriverOrder _order;
  YandexMapController? _mapCtrl;
  double _lastZoom = 12;
  BitmapDescriptor? _aPin;
  BitmapDescriptor? _bPin;
  BitmapDescriptor? _driverIcon;

  /// Bottom sheet'ning hozirgi balandligi (0..1). Recenter FAB shu qiymatga
  /// qarab map'ning ko'rinib turgan qismida turishi uchun ishlatiladi.
  double _sheetExtent = 0.5;

  OsrmRoute? _route;
  bool _routeLoading = false;
  Timer? _waitTicker;

  /// Driverning real vaqt joylashuvi (GPS oqimidan). Map markeri va route
  /// boshlang'ich nuqtasi sifatida ishlatiladi. `null` bo'lsa, fallback —
  /// `widget.initialDriverLocation` yoki saqlab qo'yilgan `accept_lat/lng`.
  LatLng? _currentDriverLocation;

  /// Driver tezligi (km/h) — Position.speed (m/s) dan hisoblab olamiz.
  /// HUD da ko'rsatiladi.
  double _currentSpeedKmh = 0;

  /// Driverning hozirgi yo'nalishi (gradus, 0=N, 90=E, 180=S, 270=W).
  /// Avval `pos.heading`'dan olinadi; agar GPS heading bermasa (emulator,
  /// stansiyali GPS) — ketma-ket lokatsiyalardan bearing hisoblanadi.
  /// Map'ni "yuqori = driver oldida" qilib aylantirish uchun ishlatiladi.
  double _currentHeading = 0;

  /// Heading hisoblash uchun oldingi lokatsiya (oxirgi tasdiqlangan).
  LatLng? _prevHeadingLoc;

  /// Auto-follow holati — true bo'lsa har bir GPS yangilanishida map driver
  /// pozitsiyasiga avto-recenter bo'ladi. Foydalanuvchi qo'lda map'ni siljitsa
  /// false ga tushadi (FAB tap → yana true).
  bool _followDriver = true;

  // GPS oqimi: doimo ochiladi (driver harakatini map'da ko'rsatish va
  // status==5 da pickup'dan 100m uzoqlashganda avtomat InTransit uchun).
  StreamSubscription<Position>? _gpsSub;
  bool _autoTransitionTriggered = false;
  static const double _autoTransitionDistanceM = 100.0;

  /// OSRM ni qayta chaqirishda throttle: oxirgi route boshlangan
  /// nuqta. Driver bundan ≥ 500 m uzoqlashsa qayta hisoblanadi.
  LatLng? _lastRouteFromLoc;
  static const double _routeRecalcDistanceM = 500.0;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _currentDriverLocation = widget.initialDriverLocation;
    _loadMarkers();
    _refetchRoute();
    _waitTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _startGpsStream();
  }

  @override
  void dispose() {
    _waitTicker?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  /// Yandex Placemark markerlarini (A/B pin, driver strelka) bir marta chizamiz.
  Future<void> _loadMarkers() async {
    final a = await MapMarkers.abPin('A', AppPalette.success);
    final b = await MapMarkers.abPin('B', AppPalette.dangerLight);
    final drv = await MapMarkers.driverArrow(AppPalette.teal);
    if (!mounted) return;
    setState(() {
      _aPin = a;
      _bPin = b;
      _driverIcon = drv;
    });
  }

  /// Kamerani nuqtaga olib boradi ([azimuth] berilsa heading-up aylantiradi).
  void _moveCamera(LatLng p, {double? zoom, double azimuth = 0}) {
    _mapCtrl?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLngToPoint(p), zoom: zoom ?? _lastZoom, azimuth: azimuth),
      ),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.4),
    );
  }

  void _fitToPoints(List<LatLng> pts) {
    if (_mapCtrl == null || pts.length < 2) return;
    _mapCtrl!.moveCamera(
      CameraUpdate.newGeometry(Geometry.fromBoundingBox(boundingBoxOf(pts))),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.4),
    );
  }

  /// GPS oqimini ochib, har bir yangilanishda:
  ///   1) `_currentDriverLocation`'ni yangilab, map markerini siljitamiz va
  ///      agar route hali yo'q bo'lsa ([_stageRoute]'ga qarab) qaytadan chizamiz.
  ///   2) Agar status==5 (Loading) bo'lsa va pickup'dan 100m uzoqlashilsa,
  ///      avtomat `InTransit` (status=6)'ga o'tkazamiz.
  Future<void> _startGpsStream() async {
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

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // 5m'dan kichik o'zgarishlarni e'tiborga olmaymiz
      ),
    ).listen((pos) async {
      final newLoc = LatLng(pos.latitude, pos.longitude);
      final hadNoLoc = _currentDriverLocation == null;
      // Speed: m/s → km/h (manfiy yoki NaN bo'lsa 0)
      final speedKmh = (pos.speed.isFinite && pos.speed > 0) ? pos.speed * 3.6 : 0.0;

      // ── Heading hisoblash ──
      // 1-priority: GPS-ning o'zi bergan heading (mobile qurilmada eng aniq).
      // 2-fallback: ketma-ket ikki lokatsiya orasidagi bearing — emulator yoki
      // GPS heading bermagan qurilmalarda ishlaydi. Tezlik 1 km/h dan past
      // bo'lsa heading shovqinli bo'ladi — oldingi qiymatni saqlaymiz.
      double? incomingHeading;
      if (pos.heading.isFinite && pos.heading >= 0 && pos.heading <= 360) {
        incomingHeading = pos.heading;
      } else if (_prevHeadingLoc != null) {
        final movedM = Geolocator.distanceBetween(
          _prevHeadingLoc!.latitude, _prevHeadingLoc!.longitude,
          newLoc.latitude, newLoc.longitude,
        );
        // Faqat sezilarli harakatda hisoblaymiz (GPS shovqinidan farqlash uchun).
        if (movedM >= 5) {
          incomingHeading = _bearingDegrees(_prevHeadingLoc!, newLoc);
        }
      }
      if (incomingHeading != null && speedKmh >= 1.0) {
        _currentHeading = incomingHeading;
        _prevHeadingLoc = newLoc;
      } else if (_prevHeadingLoc == null) {
        _prevHeadingLoc = newLoc;
      }

      if (mounted) {
        setState(() {
          _currentDriverLocation = newLoc;
          _currentSpeedKmh = speedKmh;
        });
      }
      // Auto-follow: faol bosqichlarda (Accepted → Delivered) — map doimo
      // driver pozitsiyasiga ergashadi. Turn-by-turn: driver markazda,
      // xarita yo'l bo'ylab siljiydi VA driver yo'nalishi yuqoriga qaratiladi
      // (map -heading'ga aylantiriladi).
      final s = _order.status;
      final isActiveStage = s != null && s >= 3 && s <= 9 && s != 10 && s != 11;
      if (_followDriver && isActiveStage) {
        // Birinchi GPS yangilanishida (hadNoLoc) navigatsiya zoomiga (16,
        // ko'cha darajasi) o'tamiz. Keyin foydalanuvchi zoomni o'zgartirsa,
        // saqlanadi. Heading-up: xaritani yo'nalish (azimuth)'ga aylantiramiz.
        final targetZoom = hadNoLoc ? 16.0 : (_lastZoom < 13 ? 16.0 : _lastZoom);
        _moveCamera(newLoc, zoom: targetZoom, azimuth: _currentHeading);
      }

      // Agar accepted bo'lsa va hozirgacha route bo'lmagan bo'lsa,
      // dastlabki driver lokatsiyasi kelganda A nuqtagacha route'ni chizamiz.
      if (hadNoLoc && (_order.status == 3 || _order.status == 4)) {
        _refetchRoute();
      }

      // Active bosqichlarda (3/4 — A ga, 6/7 — B ga) driver harakatlanganda
      // OSRM marshrutni qayta hisoblaymiz. 500m'dan ortiq siljishdan keyin
      // chaqirib, OSRM serverini ortiqcha urmaymiz.
      if ((s == 3 || s == 4 || s == 6 || s == 7) && _lastRouteFromLoc != null) {
        final moved = Geolocator.distanceBetween(
          _lastRouteFromLoc!.latitude,
          _lastRouteFromLoc!.longitude,
          newLoc.latitude,
          newLoc.longitude,
        );
        if (moved >= _routeRecalcDistanceM) {
          _refetchRoute();
        }
      }

      // Status==5 → pickup'dan 100m uzoqlashganda InTransit
      final pickupLatLng = _pickup;
      if (!_autoTransitionTriggered && _order.status == 5 && pickupLatLng != null) {
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
            _refetchRoute();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(I18n.t('driver.detail.auto_transit_msg'))),
            );
          } catch (e) {
            _autoTransitionTriggered = false;
          }
        }
      }
    }, onError: (_) {});
  }

  /// Map'ni driverning hozirgi joylashuviga (yoki fallback'ga) markazlaydi va
  /// auto-follow rejimini yoqadi. Heading-up bilan birga aylantiriladi. Zoom
  /// navigatsiya darajasi (16).
  void _recenterToDriver() {
    final loc = _currentDriverLocation ?? _pickup ?? _delivery ?? _toshkent;
    _moveCamera(loc, zoom: 16, azimuth: _currentHeading);
    if (!_followDriver) {
      setState(() => _followDriver = true);
    }
  }

  /// Ikki nuqta orasidagi yo'nalish (gradus, 0=N, soat strelkasi bo'yicha).
  /// GPS heading bermagan emulator/qurilmalar uchun fallback.
  static double _bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2)
        - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final theta = math.atan2(y, x);
    return ((theta * 180 / math.pi) + 360) % 360;
  }

  LatLng? get _pickup => (_order.pickupLat != null && _order.pickupLng != null)
      ? LatLng(_order.pickupLat!, _order.pickupLng!)
      : null;

  LatLng? get _delivery => (_order.deliveryLat != null && _order.deliveryLng != null)
      ? LatLng(_order.deliveryLat!, _order.deliveryLng!)
      : null;

  /// Driverning hozirgi yoki saqlab qo'yilgan accept nuqtasi.
  /// Real GPS bo'lsa shu o'qiladi, aks holda backend `accept_lat/lng`,
  /// bo'lmasa `widget.initialDriverLocation`.
  LatLng? get _acceptPoint =>
      _currentDriverLocation ??
      ((_order.acceptLat != null && _order.acceptLng != null)
          ? LatLng(_order.acceptLat!, _order.acceptLng!)
          : widget.initialDriverLocation);

  /// Bosqichga qarab qaysi nuqtadan qaysi nuqtagacha chiziq ko'rsatamiz.
  /// - status==2 (Active, hali qabul qilinmagan): chiziq yo'q (faqat A pin va driver pin)
  /// - status==3/4 (Accepted/ArrivedPickup): driver (current) → A (pickup)
  /// - status==5 (Loading): chiziq yo'q
  /// - status==6/7 (InTransit/ArrivedDelivery): driver (current) → B (delivery)
  ///   Driver harakatlanganda real yo'l bo'yicha qayta chiziladi.
  /// - boshqa: chiziq yo'q
  (LatLng?, LatLng?) get _stageRoute {
    final s = _order.status;
    if (s == 3 || s == 4) {
      final from = _acceptPoint ?? _pickup;
      return (from, _pickup);
    }
    if (s == 6 || s == 7) {
      final from = _acceptPoint ?? _pickup;
      return (from, _delivery);
    }
    return (null, null);
  }

  Future<void> _refetchRoute() async {
    final (from, to) = _stageRoute;
    if (from == null || to == null) {
      setState(() => _route = null);
      return;
    }
    setState(() => _routeLoading = true);
    _lastRouteFromLoc = from;
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
      _fitToPoints(route.points);
      return;
    }
    // Route yo'q (status==2 yoki hali yuklanmagan) — A va driverni qamragan
    // hudud yoki pickup'ga yaqinlashtiramiz.
    final p = _pickup;
    final drv = _currentDriverLocation ?? _acceptPoint;
    final pts = <LatLng>[
      if (p != null) p,
      if (drv != null) drv,
    ];
    if (pts.length >= 2) {
      _fitToPoints(pts);
    } else if (p != null) {
      _moveCamera(p, zoom: 14);
    } else if (drv != null) {
      _moveCamera(drv, zoom: 14);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    final msg = e is ApiException
        ? e.firstFieldMessage
        : I18n.t('driver.detail.network_error_label', {'msg': '$e'});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Buyurtmani server'dan qayta yuklash — active/scheduled/archive ro'yxatlari
  /// va current-order'dan bittasini ID bo'yicha topadi. Backend hozircha alohida
  /// `GET orders/{id}` endpoint chiqarmagani uchun shu yo'l ishlatiladi.
  Future<void> _reloadOrder() async {
    if (_reloading) return;
    setState(() => _reloading = true);
    try {
      final results = await Future.wait<List<DriverOrder>>([
        DriverApi.instance.activeOrders().catchError((_) => <DriverOrder>[]),
        DriverApi.instance.scheduledOrders().catchError((_) => <DriverOrder>[]),
        DriverApi.instance.archiveOrders().catchError((_) => <DriverOrder>[]),
      ]);
      final all = <DriverOrder>[...results[0], ...results[1], ...results[2]];
      DriverOrder? found;
      for (final o in all) {
        if (o.id == _order.id) {
          found = o;
          break;
        }
      }
      // current-order ham bo'lishi mumkin (radius feed ID emas, lekin sinaymiz).
      if (found == null) {
        try {
          final cur = await DriverApi.instance.currentOrder();
          if (cur != null && cur.id == _order.id) found = cur;
        } catch (_) {}
      }
      if (!mounted) return;
      if (found != null) {
        setState(() => _order = found!);
        unawaited(_refetchRoute());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('driver.detail.order_not_found'))),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
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
      // status==5 boshlanganda auto-transition flagini qayta tiklaymiz
      // (GPS oqimi doimo ochiq turadi).
      if (newStatus == 5) {
        _autoTransitionTriggered = false;
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
        label: I18n.t('order.detail.created'),
        iconData: Icons.add_circle_outline_rounded,
        timeIso: o.createdAt,
      ),
      TimelineStep(
        label: I18n.t('order.status.accepted_short'),
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
        label: I18n.t('driver.detail.in_transit_step'),
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
        label: I18n.t('order.status.cancelled_short'),
        iconData: Icons.cancel_rounded,
        timeIso: o.cancelledAt,
        note: _renderCancelReason(o),
      ));
    }
    return steps;
  }

  /// Bekor qilingan buyurtmaning sababini ko'rinadigan satrga aylantiradi:
  ///   - catalog sabab → joriy lokaldagi nom;
  ///   - "Boshqa" → "<label>: <custom matn>";
  ///   - faqat eski matn → shu matn.
  String? _renderCancelReason(DriverOrder o) {
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
    // Joriy GPS lokatsiyasini avtomatik aniqlaymiz — pop-up tasdiqlash yo'q.
    // Avval real GPS'dan one-shot fix olishga harakat qilamiz, agar bo'lmasa
    // oqimdan kelgan oxirgi lokatsiya yoki initialDriverLocation'ga qaytamiz.
    LatLng? acceptLoc = _currentDriverLocation ?? widget.initialDriverLocation;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          ).timeout(const Duration(seconds: 6));
          acceptLoc = LatLng(pos.latitude, pos.longitude);
          if (mounted) setState(() => _currentDriverLocation = acceptLoc);
        }
      }
    } catch (_) {
      // GPS olinmasa, mavjud fallback bilan davom etamiz
    }

    if (acceptLoc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('driver.detail.location_unknown'))),
      );
      return;
    }

    await _doAction(
      () => DriverApi.instance.acceptOrder(
        orderId: _order.id,
        acceptLat: acceptLoc!.latitude,
        acceptLng: acceptLoc.longitude,
      ),
      newStatus: 3,
    );
    // Qabul qilingach detail sahifasida qolamiz (route avtomat A gacha chiziladi)
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
    final picked = await _askCancelReason();
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await DriverApi.instance.cancelOrder(
        orderId: _order.id,
        cancelReasonId: picked.reasonId,
        customText: picked.customText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('driver.detail.order_cancelled_msg'))),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<_CancelReasonChoice?> _askCancelReason() async {
    List<CancelReason> reasons;
    try {
      reasons = await DriverApi.instance.cancelReasons();
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

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _order.status;
    final isFinal = s == 9 || s == 10 || s == 11 || s == 12;
    final isActiveStage = s != null && s >= 3 && !isFinal;

    final p = _pickup;
    final d = _delivery;
    final hasAB = p != null && d != null;

    // Faol bosqichlarda (Accepted+) driver pozitsiyasiga, undan oldin A↔B
    // o'rtasiga markazlaymiz. Bu birinchi GPS kelmasa ham driver "atrofini"
    // ko'rsatish uchun (turn-by-turn navigatsiya tuyg'usi).
    final LatLng initialCenter;
    if (isActiveStage && _currentDriverLocation != null) {
      initialCenter = _currentDriverLocation!;
    } else if (hasAB) {
      initialCenter = LatLng((p.latitude + d.latitude) / 2, (p.longitude + d.longitude) / 2);
    } else {
      initialCenter = p ?? d ?? _toshkent;
    }

    // Faqat aniq OSRM route bo'lsa chizamiz. Default holat (status 2 yoki yo'q
    // route) — faqat pinlar, A↔B to'g'ri chiziq emas (talab bo'yicha).
    final routePoints = _route?.points;

    final mapObjects = <MapObject>[
      if (routePoints != null && routePoints.length >= 2)
        PolylineMapObject(
          mapId: const MapObjectId('route'),
          polyline: Polyline(points: latLngListToPoints(routePoints)),
          strokeColor: AppPalette.teal,
          strokeWidth: 5,
          outlineColor: Colors.white.withValues(alpha: 0.9),
          outlineWidth: 2,
        ),
      // A pin doim (mavjud bo'lsa). B pin — faqat InTransit/Unloading bosqichlari.
      if (p != null && _aPin != null) _abPlacemark(p, isStart: true),
      if (d != null && _bPin != null && (s == 6 || s == 7 || s == 8 || s == 9 || s == 10))
        _abPlacemark(d, isStart: false),
      // Driver hozirgi joylashuvi — final holatlardan tashqari doim ko'rinadi.
      if (s != 9 && s != 10 && s != 11 && s != 12 && _driverIcon != null)
        _driverPlacemark(_currentDriverLocation ?? _acceptPoint ?? p ?? _toshkent),
    ];

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
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) {
            if ((n.extent - _sheetExtent).abs() > 0.005) {
              setState(() => _sheetExtent = n.extent);
            }
            return false;
          },
          child: Stack(
          children: [
            Positioned.fill(
              child: YandexMap(
                nightModeEnabled: isDark,
                mapObjects: mapObjects,
                onMapCreated: (controller) {
                  _mapCtrl = controller;
                  controller.moveCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: latLngToPoint(initialCenter),
                        zoom: isActiveStage ? 16.0 : 12.0,
                      ),
                    ),
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // Faol bosqichda navigatsiya tuyg'usini buzmaymiz; boshqa
                    // hollarda butun marshrutni kameraga sig'diramiz.
                    if (!isActiveStage) _fitMapToRoute();
                  });
                },
                onCameraPositionChanged: (position, reason, finished) {
                  _lastZoom = position.zoom;
                  // Foydalanuvchi qo'lda surса auto-follow'ni o'chiramiz. Yandex
                  // gesture'ni dasturiy harakatdan ajratadi (reason).
                  if (reason == CameraUpdateReason.gestures && _followDriver) {
                    setState(() => _followDriver = false);
                  }
                },
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
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(I18n.t('order.detail.route_calculating')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Navigatsiya HUD — top-center'da: tezlik / keyingi burilish /
            // qolgan masofa. Faqat active driver bosqichlarida ko'rinadi.
            if ((s == 3 || s == 4 || s == 6 || s == 7) && _route != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 16,
                right: 16,
                child: _NavHud(
                  speedKmh: _currentSpeedKmh,
                  nextTurnMeters: _route!.nextTurnMeters,
                  nextTurnInstruction: _route!.nextTurnInstruction,
                  remainingMeters: _route!.distanceMeters,
                ),
              ),
            // Map'ning o'ng pastki burchagida joylashgan "current location" FAB.
            // Bottom-sheet bilan birga harakatlanadi — har doim sheet'ning
            // tepasidan biroz balandda turadi, ko'rinmay qolmasligi uchun.
            // Follow-driver FAB — yoqilgan bo'lsa primaryContainer foni va
            // to'la "my_location" iconi; o'chgan (foydalanuvchi qo'lda pan
            // qilgan) bo'lsa neytral fon va "location_searching" iconi.
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).size.height * _sheetExtent + 12,
              child: Material(
                color: _followDriver ? cs.primaryContainer : cs.surface,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _recenterToDriver,
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
                                        _order.orderNumber ?? I18n.t('customer.order_number_fallback', {'id': _order.id}),
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
                                label: I18n.t('driver.detail.loading_wait_label'),
                              ),
                            if (s == 8 && _order.unloadingStartedAt != null && _order.cargoType != null)
                              _WaitCountdown(
                                startedAtIso: _order.unloadingStartedAt!,
                                freeMinutes: _order.cargoType!.deliveryFreeWaitMinutes,
                                paidPrice: _order.cargoType!.deliveryPaidWaitPrice,
                                paidIntervalMin: _order.cargoType!.deliveryPaidWaitIntervalMin,
                                label: I18n.t('driver.detail.unloading_wait_label'),
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
                                        I18n.t('driver.detail.client_finish_hint'),
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
                                      Expanded(
                                        child: Text(
                                          I18n.t('driver.detail.order_actions_unavailable'),
                                          style: const TextStyle(height: 1.4),
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
                                  label: Text(I18n.t('common.cancel')),
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
      ),
    );
  }

  Widget _slideForStatus(int? s) {
    switch (s) {
      case 2:
        return SlideButton(
          label: I18n.t('driver.detail.accept_slide'),
          icon: Icons.check_rounded,
          onSlide: _accept,
        );
      case 3:
        return SlideButton(
          label: I18n.t('driver.detail.arrived_pickup_slide'),
          icon: Icons.pin_drop_rounded,
          onSlide: _arrivedPickup,
        );
      case 5:
        return SlideButton(
          label: I18n.t('driver.detail.in_transit_slide'),
          icon: Icons.local_shipping_rounded,
          onSlide: _inTransit,
        );
      case 6:
        return SlideButton(
          label: I18n.t('driver.detail.arrived_delivery_slide'),
          icon: Icons.location_on_rounded,
          onSlide: _arrivedDelivery,
        );
      case 8:
        return SlideButton(
          label: I18n.t('driver.detail.delivered_slide'),
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

  PlacemarkMapObject _abPlacemark(LatLng point, {required bool isStart}) {
    return PlacemarkMapObject(
      mapId: MapObjectId(isStart ? 'pickup' : 'delivery'),
      point: latLngToPoint(point),
      opacity: 1,
      icon: PlacemarkIcon.single(PlacemarkIconStyle(
        image: (isStart ? _aPin : _bPin)!,
        anchor: const Offset(0.5, 0.5),
        scale: 1,
      )),
    );
  }

  /// Driver marker — screen-aligned (noRotation): map heading-up'ga
  /// aylantirilgani uchun navigatsiya strelkasi doim "yuqori = oldinga".
  PlacemarkMapObject _driverPlacemark(LatLng point) {
    return PlacemarkMapObject(
      mapId: const MapObjectId('driver'),
      point: latLngToPoint(point),
      opacity: 1,
      icon: PlacemarkIcon.single(PlacemarkIconStyle(
        image: _driverIcon!,
        anchor: const Offset(0.5, 0.5),
        rotationType: RotationType.noRotation,
        scale: 1,
      )),
    );
  }
}

/// Navigatsiya HUD — map ustida top-center'da turadigan yarim shaffof card.
/// Driver tezligi, keyingi burilishgacha masofa va manzilgacha qolgan
/// masofani ko'rsatadi.
class _NavHud extends StatelessWidget {
  const _NavHud({
    required this.speedKmh,
    required this.nextTurnMeters,
    required this.nextTurnInstruction,
    required this.remainingMeters,
  });

  final double speedKmh;
  final double? nextTurnMeters;
  final String? nextTurnInstruction;
  final double remainingMeters;

  /// OSRM maneuver modifier (`left`, `right`, `straight`, `slight left`, ...)
  /// uchun mos ikon va o'zbekcha qisqa matn.
  (IconData, String) _maneuverPresentation() {
    final m = (nextTurnInstruction ?? '').toLowerCase();
    if (m.contains('left')) return (Icons.turn_left_rounded, I18n.t('driver.detail.maneuver_left'));
    if (m.contains('right')) return (Icons.turn_right_rounded, I18n.t('driver.detail.maneuver_right'));
    if (m.contains('uturn')) return (Icons.u_turn_left_rounded, I18n.t('driver.detail.maneuver_uturn'));
    if (m.contains('roundabout') || m.contains('rotary')) {
      return (Icons.rotate_right_rounded, I18n.t('driver.detail.maneuver_roundabout'));
    }
    if (m.contains('arrive')) return (Icons.flag_rounded, I18n.t('driver.detail.maneuver_arrive'));
    return (Icons.straight_rounded, I18n.t('driver.detail.maneuver_straight'));
  }

  String _fmtMeters(double m) {
    if (m < 1000) return '${m.round()} m';
    final km = m / 1000.0;
    if (km < 10) return '${km.toStringAsFixed(1)} ${I18n.t('common.km')}';
    return '${km.round()} ${I18n.t('common.km')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (mIcon, mLabel) = _maneuverPresentation();
    return Material(
      color: cs.surface.withValues(alpha: 0.92),
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Tezlik
            _HudCell(
              icon: Icons.speed_rounded,
              big: '${speedKmh.round()}',
              small: I18n.t('driver.detail.hud_speed_unit'),
              color: cs.primary,
            ),
            _hudDivider(cs),
            // Keyingi burilish
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(mIcon, color: cs.primary, size: 28),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nextTurnMeters != null
                            ? _fmtMeters(nextTurnMeters!)
                            : '—',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        mLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _hudDivider(cs),
            // Qolgan masofa
            _HudCell(
              icon: Icons.flag_rounded,
              big: _fmtMeters(remainingMeters),
              small: I18n.t('driver.detail.hud_remaining_label'),
              color: AppPalette.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudDivider(ColorScheme cs) => Container(
        width: 1,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: cs.outlineVariant.withValues(alpha: 0.5),
      );
}

class _HudCell extends StatelessWidget {
  const _HudCell({
    required this.icon,
    required this.big,
    required this.small,
    required this.color,
  });

  final IconData icon;
  final String big;
  final String small;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              big,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              small,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
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
        text = I18n.t('driver.detail.stage_pickup', {'km': distanceKm != null ? distanceKm!.toStringAsFixed(1) : '—'});
        icon = Icons.pin_drop_rounded;
        break;
      case 5:
        text = I18n.t('driver.detail.stage_loading');
        icon = Icons.downloading_rounded;
        break;
      case 6:
        text = I18n.t('driver.detail.stage_in_transit', {'km': distanceKm != null ? distanceKm!.toStringAsFixed(1) : '—'});
        icon = Icons.local_shipping_rounded;
        break;
      case 7:
      case 8:
        text = I18n.t('driver.detail.stage_unloading');
        icon = Icons.unarchive_rounded;
        break;
      case 9:
        text = I18n.t('driver.detail.stage_delivered_waiting');
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
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                fmtHHMMSS(remainingSec),
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
    // Backend driver_income_amount'ni faqat buyurtma yakunlanganda (settle)
    // to'ldiradi; undan oldin DB default "0.00" qaytadi. Shuning uchun uni
    // faqat haqiqatan settle bo'lgan (>0) holatda ishlatamiz, aks holda
    // estimate: total - komissiyalar (avto hisoblanadi, "0 so'm" ko'rinmaydi).
    final rawSettledIncome = _n(order.driverIncomeAmount);
    final isSettled = order.driverIncomeAmount != null && rawSettledIncome > 0;
    final settledIncome = isSettled ? rawSettledIncome : (total - projectAmt - companyAmt);
    final netIncome = settledIncome - penalty;

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
                I18n.t('order.price_breakdown'),
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
                    I18n.t('driver.detail.estimate_badge'),
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
            label: I18n.t('order.total_price'),
            value: total,
            isMain: true,
          ),
          const SizedBox(height: 6),
          _IncomeRow(
            label: '${I18n.t('order.commission_project')} (${_formatPct(projectPct)})',
            value: -projectAmt,
            isDeduction: true,
          ),
          const SizedBox(height: 6),
          _IncomeRow(
            label: '${I18n.t('order.commission_avtopark')} (${_formatPct(companyPct)})',
            value: -companyAmt,
            isDeduction: true,
          ),
          if (penalty > 0) ...[
            const SizedBox(height: 6),
            _IncomeRow(
              label: I18n.t('order.late_penalty'),
              value: -penalty,
              isDeduction: true,
            ),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 10),
          _IncomeRow(
            label: I18n.t('order.driver_earnings'),
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
          '${_formatMoney(value.toString())} ${I18n.t('common.uzs_symbol')}',
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
