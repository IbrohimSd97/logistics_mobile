import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../theme/app_palette.dart';
import 'gradient_button.dart';

/// Map orqali manzil tanlash sahifasi.
/// OpenStreetMap tile'lari + Nominatim geocoding (bepul, API key kerak emas).
///
/// Qaytaradi: [LocationPickerResult]? — null bo'lsa user cancelladi.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.title = 'Manzilni tanlash',
    this.initialLatLng,
    this.initialAddress,
  });

  final String title;
  final LatLng? initialLatLng;
  final String? initialAddress;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class LocationPickerResult {
  const LocationPickerResult({
    required this.latLng,
    required this.address,
  });

  final LatLng latLng;
  final String address;
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _toshkent = LatLng(41.311081, 69.240562);

  final _mapCtrl = MapController();
  final _searchCtrl = TextEditingController();
  Timer? _reverseDebounce;

  LatLng _center = _toshkent;
  String _address = '';
  bool _resolving = false;

  // Search results dropdown
  List<_NominatimHit> _searchResults = [];
  bool _searching = false;

  static const _userAgent = 'ALIX-Logistics/1.0 (mening_ilovam)';

  @override
  void initState() {
    super.initState();
    if (widget.initialLatLng != null) _center = widget.initialLatLng!;
    if ((widget.initialAddress ?? '').isNotEmpty) {
      _address = widget.initialAddress!;
      _searchCtrl.text = widget.initialAddress!;
    } else {
      // Boshlang'ich joylashuv uchun reverse geocode
      _scheduleReverse(_center);
    }
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    _mapCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scheduleReverse(LatLng p) {
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 350), () => _reverseGeocode(p));
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _resolving = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${p.latitude}&lon=${p.longitude}&format=json&accept-language=uz,ru,en',
      );
      final res = await http.get(url, headers: {'User-Agent': _userAgent});
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = (body['display_name'] as String?) ?? '';
        setState(() {
          _address = addr;
          _resolving = false;
        });
      } else {
        setState(() => _resolving = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolving = false);
    }
  }

  Future<void> _searchAddress(String query) async {
    final q = query.trim();
    if (q.length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(q)}&format=json&limit=6&accept-language=uz,ru,en',
      );
      final res = await http.get(url, headers: {'User-Agent': _userAgent});
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final hits = list
            .whereType<Map<String, dynamic>>()
            .map(_NominatimHit.fromMap)
            .whereType<_NominatimHit>()
            .toList();
        setState(() {
          _searchResults = hits;
          _searching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _searching = false;
      });
    }
  }

  void _pickHit(_NominatimHit h) {
    setState(() {
      _center = h.latLng;
      _address = h.displayName;
      _searchCtrl.text = h.displayName;
      _searchResults = [];
    });
    _mapCtrl.move(h.latLng, 15.5);
  }

  void _confirm() {
    Navigator.of(context).pop(
      LocationPickerResult(latLng: _center, address: _address),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              minZoom: 4,
              maxZoom: 18,
              onPositionChanged: (camera, hasGesture) {
                if (!hasGesture) return;
                _center = camera.center;
                _scheduleReverse(camera.center);
              },
              onTap: (tap, latlng) {
                _center = latlng;
                _mapCtrl.move(latlng, _mapCtrl.camera.zoom);
                setState(() {});
                _scheduleReverse(latlng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    // CartoDB dark tiles (OSM compatible) — dark mode uchun yaxshi ko'rinadi
                    ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mening_ilovam',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
            ],
          ),
          // Center pin (markerni xarita o'rtasiga sahna ustidan qo'yamiz)
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_pin,
                  size: 48,
                  color: AppPalette.tealDeep,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black45, offset: Offset(0, 4)),
                  ],
                ),
              ),
            ),
          ),
          // Yuqorida search
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(14),
                  color: cs.surfaceContainerHigh,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Manzilni qidirish (kamida 3 belgi)',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (_searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null),
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => _searchAddress(v),
                    onSubmitted: (v) => _searchAddress(v),
                  ),
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(14),
                    color: cs.surfaceContainerHigh,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, i) => Divider(height: 1, color: cs.outlineVariant),
                        itemBuilder: (_, i) {
                          final h = _searchResults[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined, size: 20),
                            title: Text(h.displayName,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () => _pickHit(h),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Pastki panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: cs.primary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _resolving
                                  ? 'Manzil aniqlanmoqda…'
                                  : (_address.isEmpty ? 'Tanlangan joy' : _address),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: cs.onSurface,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      GradientButton(
                        label: 'Tasdiqlash',
                        icon: Icons.check_rounded,
                        onPressed: _confirm,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NominatimHit {
  const _NominatimHit({required this.displayName, required this.latLng});

  final String displayName;
  final LatLng latLng;

  static _NominatimHit? fromMap(Map<String, dynamic> m) {
    final lat = double.tryParse('${m['lat']}');
    final lon = double.tryParse('${m['lon']}');
    if (lat == null || lon == null) return null;
    final name = (m['display_name'] as String?) ?? '';
    if (name.isEmpty) return null;
    return _NominatimHit(displayName: name, latLng: LatLng(lat, lon));
  }
}
