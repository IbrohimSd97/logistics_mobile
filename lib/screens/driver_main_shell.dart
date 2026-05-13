import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/api/api_exception.dart';
import '../core/api/auth_api.dart';
import '../core/api/cargo_types_api.dart';
import '../core/session/session_store.dart';
import '../core/theme/theme_controller.dart';
import '../customer/customer_api.dart';
import '../customer/pages/customer_physical_registration_page.dart';
import '../driver/driver_api.dart';
import '../driver/driver_models.dart';
import '../driver/pages/driver_order_detail_page.dart';
import 'customer_main_shell.dart';
import 'login_screen.dart';

/// Faollashtirilgan haydovchi asosiy oqimi.
class DriverMainShell extends StatefulWidget {
  const DriverMainShell({
    super.key,
    required this.phoneDisplay,
    required this.userId,
    required this.userType,
  });

  final String phoneDisplay;
  final int userId;
  final String userType;

  @override
  State<DriverMainShell> createState() => _DriverMainShellState();
}

class _DriverMainShellState extends State<DriverMainShell> {
  int _index = 0;
  static const _titles = ['Bosh sahifa', 'Buyurtmalar', 'Hamyon', 'Profil'];
  int _refreshTick = 0;

  void _bumpRefresh() {
    if (!mounted) return;
    setState(() => _refreshTick++);
  }

  Future<void> _logout() async {
    await SessionStore().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// Driver → Customer rejim. Customer record bo'lsa shellga o'tkazadi, bo'lmasa registratsiyaga.
  Future<void> _switchToCustomer() async {
    final session = SessionStore();
    // Avval customer profilni so'raymiz
    try {
      final profile = await CustomerApi.instance.me();
      if (profile != null && mounted) {
        // Customer record bor — CustomerMainShellga o'tamiz
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => CustomerMainShell(
              phoneDisplay: widget.phoneDisplay,
              userId: widget.userId,
              hasRefreshSession: true,
            ),
          ),
        );
        return;
      }
    } on ApiException catch (e) {
      // 404 yoki forbidden — customer record yo'q. Registratsiyani boshlaymiz.
      if (e.statusCode != 404 && e.statusCode != 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.firstFieldMessage)),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tarmoq xatosi: $e')),
      );
      return;
    }

    // Customer record yo'q — registratsiya uchun temp_token kerak
    if (!mounted) return;
    String? temp = await session.getTempRegistrationToken();
    final refresh = await session.getRefreshToken();
    if ((temp == null || temp.isEmpty) && refresh != null && refresh.isNotEmpty) {
      try {
        temp = await const AuthApi().issueTempTokenFromRefresh(refresh);
        await session.saveTempRegistrationToken(temp);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Temp token: $e')),
        );
        return;
      }
    }
    if (!mounted) return;
    if (temp == null || temp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessiya topilmadi.')),
      );
      return;
    }
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CustomerPhysicalRegistrationPage(phoneDisplay: widget.phoneDisplay),
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CustomerMainShell(
            phoneDisplay: widget.phoneDisplay,
            userId: widget.userId,
            hasRefreshSession: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Chiqish',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DriverHomeBody(
            phoneDisplay: widget.phoneDisplay,
            refreshTick: _refreshTick,
            onOpenDetail: (o, currentLocation) async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => DriverOrderDetailPage(
                    order: o,
                    initialDriverLocation: currentLocation,
                  ),
                ),
              );
              if (changed == true) _bumpRefresh();
            },
          ),
          DriverOrdersArchiveBody(refreshTick: _refreshTick),
          DriverWalletBody(refreshTick: _refreshTick),
          DriverProfileBody(
            phoneDisplay: widget.phoneDisplay,
            userId: widget.userId,
            onLogout: _logout,
            onSwitchToCustomer: _switchToCustomer,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Bosh sahifa',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: 'Buyurtmalar',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Hamyon',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Home ───────────────────────────────

class DriverHomeBody extends StatefulWidget {
  const DriverHomeBody({
    required this.phoneDisplay,
    required this.refreshTick,
    required this.onOpenDetail,
  });

  final String phoneDisplay;
  final int refreshTick;
  final void Function(DriverOrder order, LatLng? currentLocation) onOpenDetail;

  @override
  State<DriverHomeBody> createState() => DriverHomeBodyState();
}

class DriverHomeBodyState extends State<DriverHomeBody> {
  bool _online = false;
  bool _busy = false;
  String? _error;
  DriverOrder? _current;
  List<DriverOrder> _active = [];

  /// Foydalanuvchi map picker orqali tanlagan joylashuv.
  LatLng? _pickedLocation;
  String? _pickedAddress;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void didUpdateWidget(covariant DriverHomeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadCurrent();
    }
  }

  Future<void> _loadCurrent() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cur = await DriverApi.instance.currentOrder();
      if (!mounted) return;
      setState(() {
        _current = cur;
        _busy = false;
      });
      // Agar joriy order yo'q bo'lsa va online bo'lsa, active feed yuklaymiz
      if (cur == null && _online) {
        _loadActive();
      } else if (cur == null) {
        setState(() => _active = []);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // currentOrder yo'q bo'lsa server 404 yoki conflict qaytaradi — bu xato emas
        _current = null;
      });
    }
  }

  Future<void> _toggleOnline() async {
    if (_online) {
      // Oflayn — backend'da cargo preferences ham tozalanadi
      try {
        await DriverApi.instance.clearCargoPreferences();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _online = false;
        _active = [];
        _busy = false;
      });
      return;
    }

    // Onlayn bo'lish — avval yuk turlarini so'raymiz (multi-select modal)
    final selected = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CargoTypesPickerSheet(),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await DriverApi.instance.setCargoPreferences(selected);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.firstFieldMessage;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Tarmoq xatosi: $e';
      });
      return;
    }
    if (!mounted) return;
    // Avtomat GPS bilan joylashuv aniqlash
    await _sendCurrentGpsLocation(asOnline: true);
  }

  /// GPS orqali joriy joylashuv olib backend'ga yuboradi. Permission yo'q yoki xizmat
  /// o'chirilgan bo'lsa foydalanuvchiga ko'rsatamiz.
  Future<void> _sendCurrentGpsLocation({required bool asOnline}) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Permission tekshiruvi
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Joylashuv ruxsati berilmadi.';
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Joylashuv doimiy rad etilgan. Sozlamalardan ruxsat bering.';
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Qurilmada joylashuv xizmati o\'chirilgan. Yoqing va qayta urining.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);

      await DriverApi.instance.saveLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      // Reverse-geocode (jimgina, xato bo'lsa koordinata ko'rsatamiz)
      final address = await _reverseGeocode(latLng);

      if (!mounted) return;
      setState(() {
        _pickedLocation = latLng;
        _pickedAddress = address ?? '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        _online = true;
        _busy = false;
      });

      if (asOnline) {
        await _loadActive();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joylashuv yangilandi.')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'GPS xatosi: $e';
      });
    }
  }

  Future<String?> _reverseGeocode(LatLng p) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${p.latitude}&lon=${p.longitude}&format=json&accept-language=uz,ru,en',
      );
      final res = await http.get(url, headers: const {'User-Agent': 'ALIX-Logistics/1.0'}).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return (body['display_name'] as String?);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadActive() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final list = await DriverApi.instance.activeOrders();
      if (!mounted) return;
      setState(() {
        _active = list;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Tarmoq xatosi: $e';
      });
    }
  }

  String _statusLabel(int? s) => statusLabelDriver(s);

  String _formatDistance(double? meters, String? km) {
    if (meters != null) {
      if (meters >= 1000) {
        return '${(meters / 1000).toStringAsFixed(1)} km';
      }
      return '${meters.round()} m';
    }
    if (km != null) return '$km km';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCurrent();
        if (_online && _current == null) await _loadActive();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (_current != null) ...[
            Text('Joriy buyurtma', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              color: cs.primaryContainer,
              child: InkWell(
                onTap: () => widget.onOpenDetail(_current!, _pickedLocation),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _current!.orderNumber ?? 'Buyurtma #${_current!.id}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Holat: ${_statusLabel(_current!.status)}',
                          style: TextStyle(color: cs.onPrimaryContainer)),
                      Text('Jami: ${_formatMoney(_current!.totalPrice)} ${_current!.currency ?? 'UZS'}',
                          style: TextStyle(color: cs.onPrimaryContainer)),
                      if (_current!.pickupAddress != null)
                        Text('A: ${_current!.pickupAddress}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: cs.onPrimaryContainer)),
                      if (_current!.deliveryAddress != null)
                        Text('B: ${_current!.deliveryAddress}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: cs.onPrimaryContainer)),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.chevron_right_rounded, color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            color: _online ? cs.tertiaryContainer : cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _online ? Icons.online_prediction_rounded : Icons.signal_wifi_off_rounded,
                        color: _online ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _online ? 'Onlayn' : 'Oflayn',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _online ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _online
                                  ? '5 km radiusdagi buyurtmalar ko‘rinadi.'
                                  : 'Onlayn bo‘lish uchun GPS joylashuvingiz avtomat olinadi.',
                              style: TextStyle(
                                color: _online ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _online,
                        onChanged: _busy ? null : (_) => _toggleOnline(),
                      ),
                    ],
                  ),
                  if (_online && _pickedAddress != null) ...[
                    const Divider(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 18, color: cs.onTertiaryContainer),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _pickedAddress!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onTertiaryContainer,
                              height: 1.35,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                            _busy ? null : () => _sendCurrentGpsLocation(asOnline: false),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Joylashuvni yangilash'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          if (_error != null)
            Card(
              color: cs.errorContainer,
              child: ListTile(
                leading: Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                title: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                trailing: FilledButton.tonal(
                  onPressed: _online ? _loadActive : _loadCurrent,
                  child: const Text('Qayta'),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_current == null) ...[
            Text('Yangi buyurtmalar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _online
                  ? '5 km radiusdagi, mashina sig‘imingizga mos.'
                  : 'Buyurtmalarni ko‘rish uchun onlayn bo‘ling.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (_online && _active.isEmpty && !_busy)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inbox_outlined),
                  title: const Text('Hozircha buyurtma yo‘q'),
                  subtitle: const Text('Pastga torting yoki keyinroq qaytib keling.'),
                ),
              )
            else
              ..._active.map((o) => Card(
                    child: ListTile(
                      title: Text(o.orderNumber ?? 'Buyurtma #${o.id}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Masofa: ${_formatDistance(o.distanceM, o.distanceKm)}'),
                          if (o.pickupAddress != null)
                            Text('A: ${o.pickupAddress}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (o.deliveryAddress != null)
                            Text('B: ${o.deliveryAddress}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${_formatMoney(o.totalPrice)} ${o.currency ?? 'UZS'} · ${o.cargoWeightKg ?? '—'} kg'),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      isThreeLine: true,
                      onTap: () => widget.onOpenDetail(o, _pickedLocation),
                    ),
                  )),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Archive ───────────────────────────────

class DriverOrdersArchiveBody extends StatefulWidget {
  const DriverOrdersArchiveBody({required this.refreshTick});

  final int refreshTick;

  @override
  State<DriverOrdersArchiveBody> createState() => DriverOrdersArchiveBodyState();
}

class DriverOrdersArchiveBodyState extends State<DriverOrdersArchiveBody> {
  List<DriverOrder> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DriverOrdersArchiveBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await DriverApi.instance.archiveOrders();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Tarmoq xatosi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _list.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          TextButton(onPressed: _load, child: const Text('Qayta urinish')),
        ],
      );
    }
    if (_list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          children: const [
            Icon(Icons.inventory_2_outlined, size: 56),
            SizedBox(height: 12),
            Text('Arxiv bo‘sh', textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          return _DriverOrderCard(
            order: _list[i],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DriverOrderDetailPage(order: _list[i]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DriverOrderCard extends StatelessWidget {
  const _DriverOrderCard({required this.order, required this.onTap});

  final DriverOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = order.status;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber ?? 'Buyurtma #${order.id}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MiniStatusChip(status: s),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatMoney(order.totalPrice)} ${order.currency ?? 'UZS'}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
              ),
              const SizedBox(height: 12),

              // A → B
              _AbRow(
                isStart: true,
                label: 'A',
                address: order.pickupAddress ?? '—',
              ),
              const SizedBox(height: 6),
              _AbRow(
                isStart: false,
                label: 'B',
                address: order.deliveryAddress ?? '—',
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: 10),

              // Boshlanish va tugash vaqtlari + chevron
              Row(
                children: [
                  Expanded(
                    child: _TimeRangeRow(
                      start: order.acceptedAt ?? order.createdAt,
                      end: _orderEndIso(order),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _orderEndIso(DriverOrder o) {
    return o.completedAt ?? o.cancelledAt ?? o.deliveredAt;
  }
}

class _TimeRangeRow extends StatelessWidget {
  const _TimeRangeRow({required this.start, required this.end});

  final String? start;
  final String? end;

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    final local = dt.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${p2(local.day)}.${p2(local.month)} ${p2(local.hour)}:${p2(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.flag_circle_outlined, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          _fmt(start),
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Icon(Icons.arrow_forward_rounded, size: 12, color: cs.outlineVariant),
        const SizedBox(width: 6),
        Icon(Icons.check_circle_outline_rounded, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          _fmt(end),
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _AbRow extends StatelessWidget {
  const _AbRow({
    required this.isStart,
    required this.label,
    required this.address,
  });

  final bool isStart;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isStart ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({required this.status});

  final int? status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    switch (status) {
      case 2:
        bg = const Color(0xFFFBBF24);
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
        bg = const Color(0xFF10B981);
        fg = Colors.white;
        break;
      case 11:
      case 12:
        bg = const Color(0xFFEF4444);
        fg = Colors.white;
        break;
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        statusLabelDriver(status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

// ─────────────────────────────── Wallet ───────────────────────────────

class DriverWalletBody extends StatefulWidget {
  const DriverWalletBody({required this.refreshTick});

  final int refreshTick;

  @override
  State<DriverWalletBody> createState() => DriverWalletBodyState();
}

class DriverWalletBodyState extends State<DriverWalletBody> {
  DriverWalletSnapshot? _w;
  List<DriverWalletTx> _tx = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DriverWalletBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final w = await DriverApi.instance.wallet();
      final t = await DriverApi.instance.walletTransactions();
      if (!mounted) return;
      setState(() {
        _w = w;
        _tx = t;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Tarmoq xatosi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              color: cs.errorContainer,
              child: ListTile(
                leading: Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                title: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                trailing: FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
              ),
            ),
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daromad balansi',
                      style: theme.textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatMoney(_w?.balance)} ${_w?.currency ?? 'UZS'}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yechib olish funksiyasi keyingi versiyada.')),
              );
            },
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pul yechib olish (kartaga)'),
          ),
          const SizedBox(height: 20),
          Text('Tranzaksiyalar', style: theme.textTheme.titleSmall),
          if (_tx.isEmpty)
            const Card(child: ListTile(title: Text('Hozircha yozuvlar yo‘q')))
          else
            ..._tx.map((e) => Card(
                  child: ListTile(
                    title: Text(e.title ?? '—'),
                    subtitle: Text(e.createdAt ?? ''),
                    trailing: Text(_formatMoney(e.amount)),
                  ),
                )),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Profile ───────────────────────────────

class DriverProfileBody extends StatelessWidget {
  const DriverProfileBody({
    required this.phoneDisplay,
    required this.userId,
    required this.onLogout,
    required this.onSwitchToCustomer,
  });

  final String phoneDisplay;
  final int userId;
  final VoidCallback onLogout;
  final VoidCallback onSwitchToCustomer;

  String get _initial {
    final d = phoneDisplay.replaceAll(RegExp(r'\D'), '');
    if (d.length >= 2) return d.substring(d.length - 2);
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: cs.primaryContainer,
              child: Text(
                _initial,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Haydovchi',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(phoneDisplay,
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  Text('ID: $userId',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        DriverRoleSegmented(
          current: 'driver',
          onSelect: (role) {
            if (role == 'customer') onSwitchToCustomer();
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              AnimatedBuilder(
                animation: ThemeController.instance,
                builder: (_, __) {
                  final isDark = ThemeController.instance.mode == ThemeMode.dark;
                  return SwitchListTile(
                    secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                    title: const Text('Tungi rejim'),
                    subtitle: Text(isDark ? 'Yoqilgan' : 'O‘chirilgan'),
                    value: isDark,
                    onChanged: (v) => ThemeController.instance.setMode(
                      v ? ThemeMode.dark : ThemeMode.light,
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.security_rounded),
                title: Text('Xavfsizlik'),
                subtitle: Text('Tokenlar qurilmada saqlanadi.'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('Yordam'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ALIX Logistics — haydovchi.')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Chiqish'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.error,
            side: BorderSide(color: cs.error.withValues(alpha: 0.6)),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── helpers ───────────────────────────────

String statusLabelDriver(int? s) {
  switch (s) {
    case 1:
      return 'Yangi';
    case 2:
      return 'Faol';
    case 3:
      return 'Qabul qilingan';
    case 4:
      return 'Pickup’ga keldi';
    case 5:
      return 'Yuklanmoqda';
    case 6:
      return 'Yo‘lda';
    case 7:
      return 'Delivery’ga keldi';
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

/// Yuk turi multi-select bottom sheet — driver onlayn bo'lganda chiqadi.
class _CargoTypesPickerSheet extends StatefulWidget {
  const _CargoTypesPickerSheet();

  @override
  State<_CargoTypesPickerSheet> createState() => _CargoTypesPickerSheetState();
}

class _CargoTypesPickerSheetState extends State<_CargoTypesPickerSheet> {
  List<CargoType> _items = [];
  final Set<int> _selected = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await const CargoTypesApi().list();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Row(
              children: [
                Icon(Icons.local_shipping_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Qaysi yuk turlarini olasiz?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bir nechtasini tanlash mumkin. Faqat tanlangan turlardagi buyurtmalar ko‘rinadi.',
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final c = _items[i];
                  final isSelected = _selected.contains(c.id);
                  return Material(
                    color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(c.id);
                        } else {
                          _selected.remove(c.id);
                        }
                      }),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: c.description != null
                          ? Text(c.description!,
                              maxLines: 2, overflow: TextOverflow.ellipsis)
                          : Text('${c.pricePerKm ?? '—'} so‘m/km'),
                      controlAffinity: ListTileControlAffinity.trailing,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, <int>[]),
                    child: const Text('Bekor qilish'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected.toList()),
                    child: Text('Tanlash (${_selected.length})'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Customer / Haydovchi rejim toggle (driver shell uchun).
class DriverRoleSegmented extends StatelessWidget {
  const DriverRoleSegmented({
    super.key,
    required this.current,
    required this.onSelect,
  });

  /// 'customer' yoki 'driver'
  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejim', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _RoleSeg(
                      label: 'Customer',
                      icon: Icons.person_outline_rounded,
                      selected: current == 'customer',
                      onTap: () => onSelect('customer'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _RoleSeg(
                      label: 'Haydovchi',
                      icon: Icons.local_shipping_outlined,
                      selected: current == 'driver',
                      onTap: () => onSelect('driver'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSeg extends StatelessWidget {
  const _RoleSeg({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
