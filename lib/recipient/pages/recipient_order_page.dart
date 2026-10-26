import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../core/api/api_exception.dart';
import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';
import '../../core/location/map_markers.dart';
import '../../core/location/yandex_point.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/slide_button.dart';
import '../recipient_api.dart';

/// Qabul qiluvchi uchun bitta yuk: holat, xaritada haydovchi, yuk va
/// haydovchi ma'lumoti. Haydovchi "Topshirdim" bosgach — "Yukni qabul qildim".
class RecipientOrderPage extends StatefulWidget {
  const RecipientOrderPage({super.key, required this.order});

  final RecipientOrder order;

  @override
  State<RecipientOrderPage> createState() => _RecipientOrderPageState();
}

class _RecipientOrderPageState extends State<RecipientOrderPage> {
  late RecipientOrder _order = widget.order;
  RecipientDriverLocation? _location;
  YandexMapController? _map;
  BitmapDescriptor? _pinA;
  BitmapDescriptor? _pinB;
  BitmapDescriptor? _driverIcon;
  Timer? _ticker;

  LatLng get _pickup => LatLng(_order.pickupLat, _order.pickupLng);
  LatLng get _delivery => LatLng(_order.deliveryLat, _order.deliveryLng);

  @override
  void initState() {
    super.initState();
    _prepareIcons();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_order.isActive) _refresh();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _prepareIcons() async {
    final a = await MapMarkers.abPin('A', AppPalette.ink);
    final b = await MapMarkers.abPin('B', AppPalette.orange);
    final driver = await MapMarkers.driverArrow(AppPalette.orange);
    if (!mounted) return;
    setState(() {
      _pinA = a;
      _pinB = b;
      _driverIcon = driver;
    });
  }

  Future<void> _refresh() async {
    try {
      final order = await RecipientApi.instance.order(_order.id);
      final location = order.trackable ? await RecipientApi.instance.driverLocation(order.id) : null;
      if (!mounted) return;
      setState(() {
        _order = order;
        _location = location;
      });
    } catch (_) {
      // Tarmoq uzilishi — keyingi tikda qayta urinamiz.
    }
  }

  Future<void> _finish() async {
    try {
      final order = await RecipientApi.instance.finish(_order.id);
      if (!mounted) return;
      setState(() {
        _order = order;
        _location = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('recipient.finished'))));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.firstFieldMessage)));
      await _refresh();
    }
  }

  void _fit() {
    final pts = [_pickup, _delivery, if (_location != null) LatLng(_location!.latitude, _location!.longitude)];
    _map?.moveCamera(
      CameraUpdate.newGeometry(Geometry.fromBoundingBox(boundingBoxOf(pts))),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.4),
    );
  }

  PlacemarkMapObject _pin(String id, LatLng p, BitmapDescriptor icon, {double scale = 0.75}) {
    return PlacemarkMapObject(
      mapId: MapObjectId(id),
      point: latLngToPoint(p),
      opacity: 1,
      icon: PlacemarkIcon.single(PlacemarkIconStyle(image: icon, scale: scale, isFlat: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final o = _order;
    final loc = _location;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('recipient.order_title', {'number': o.orderNumber})),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: I18n.t('common.refresh'), onPressed: _refresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AlixCard(
              tone: AlixSurfaceTone.ink,
              child: Text(
                I18n.t('recipient.status.${o.status}'),
                style: t.titleMedium?.copyWith(color: AppPalette.darkOn),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 280,
                child: YandexMap(
                  nightModeEnabled: Theme.of(context).brightness == Brightness.dark,
                  onMapCreated: (c) {
                    _map = c;
                    _fit();
                  },
                  mapObjects: [
                    if (_pinA != null) _pin('pickup', _pickup, _pinA!),
                    if (_pinB != null) _pin('delivery', _delivery, _pinB!),
                    if (loc != null && o.trackable && _driverIcon != null)
                      _pin('driver', LatLng(loc.latitude, loc.longitude), _driverIcon!, scale: 0.7),
                  ],
                ),
              ),
            ),
            if (o.canFinish) ...[
              const SizedBox(height: 16),
              AlixBanner(message: I18n.t('recipient.finish_hint'), tone: AlixTone.warning),
              const SizedBox(height: 12),
              SlideButton(label: I18n.t('recipient.finish_slide'), icon: Icons.task_alt_rounded, onSlide: _finish),
            ],
            const SizedBox(height: 16),
            AlixCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Row(I18n.t('recipient.from'), o.pickupAddress),
                  _Row(I18n.t('recipient.to'), o.deliveryAddress),
                  _Row(
                    I18n.t('recipient.cargo'),
                    [o.cargoType, I18n.t('recipient.kg', {'w': _weight(o.cargoWeightKg)})].whereType<String>().join(' · '),
                  ),
                  if (o.senderName != null) _Row(I18n.t('recipient.sender'), o.senderName!),
                ],
              ),
            ),
            if (o.driverName != null) ...[
              const SizedBox(height: 12),
              AlixCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Row(I18n.t('recipient.driver'), o.driverName!),
                    if (o.plateNumber != null)
                      _Row(I18n.t('recipient.vehicle'), [o.vehicleName, o.plateNumber].whereType<String>().join(' · ')),
                    if (o.driverPhone != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.call_rounded),
                        label: Text(I18n.t('recipient.call_driver')),
                        onPressed: () => launchUrl(Uri.parse('tel:+${o.driverPhone!.replaceAll(RegExp(r'\D'), '')}')),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _weight(double w) => w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: t.bodyLarge),
        ],
      ),
    );
  }
}
