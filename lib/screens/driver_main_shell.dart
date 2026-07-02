import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/api/api_exception.dart';
import '../core/api/auth_api.dart';
import '../core/api/cargo_types_api.dart';
import '../core/i18n/i18n.dart';
import '../core/i18n/language_picker.dart';
import '../core/i18n/wallet_tx_labels.dart';
import '../core/session/session_store.dart';
import '../core/theme/theme_controller.dart';
import '../customer/customer_api.dart';
import '../customer/pages/customer_physical_registration_page.dart';
import '../driver/driver_api.dart';
import '../driver/driver_models.dart';
import '../driver/pages/driver_failed_page.dart';
import '../driver/pages/driver_order_detail_page.dart';
import '../driver/pages/driver_pending_page.dart';
import '../driver/pages/driver_rejected_page.dart';
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

class _DriverMainShellState extends State<DriverMainShell>
    with I18nObserverMixin<DriverMainShell> {
  int _index = 0;
  // Tab matnlari — joriy I18n locale bo'yicha hisoblanadi (getter).
  List<String> get _titles => [
        I18n.t('shell.tab_home'),
        I18n.t('shell.tab_orders'),
        I18n.t('shell.tab_wallet'),
        I18n.t('shell.tab_profile'),
      ];
  int _refreshTick = 0;

  void _bumpRefresh() {
    if (!mounted) return;
    setState(() => _refreshTick++);
  }

  Future<void> _logout() async {
    // Tasodifiy tap qilinishidan saqlash uchun avval tasdiqlash so'raymiz.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('auth.logout')),
        content: Text(I18n.t('auth.logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(I18n.t('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(I18n.t('auth.logout')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
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
        SnackBar(content: Text(I18n.t('driver.network_error_label', {'msg': '$e'}))),
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
          SnackBar(content: Text(I18n.t('driver.temp_token_label', {'msg': '$e'}))),
        );
        return;
      }
    }
    if (!mounted) return;
    if (temp == null || temp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('driver.session_not_found_short'))),
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
            tooltip: I18n.t('common.refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _bumpRefresh,
          ),
          IconButton(
            tooltip: I18n.t('auth.logout'),
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
            userId: widget.userId,
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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: I18n.t('shell.tab_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping_rounded),
            label: I18n.t('shell.tab_orders'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
            label: I18n.t('shell.tab_wallet'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: I18n.t('shell.tab_profile'),
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
    required this.userId,
    required this.refreshTick,
    required this.onOpenDetail,
  });

  final String phoneDisplay;
  final int userId;
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
  /// Rejali buyurtmalar — kelajakdagi olib ketish vaqti bilan,
  /// radius'siz alohida bo'limda ko'rinadi. Joriy buyurtma bo'lsa ham
  /// ko'rinadi (driver oldinga rejalashtirishi uchun).
  List<DriverOrder> _scheduled = [];

  /// Feed tab indeksi: 0 = Joriy (radius), 1 = Reja.
  int _feedTabIndex = 0;

  /// Foydalanuvchi map picker orqali tanlagan joylashuv.
  LatLng? _pickedLocation;
  String? _pickedAddress;

  /// Onlayn'da bo'lgan davrda har 1 daqiqada GPS olib backend'ga yuboradi.
  /// Bu bilan customer real vaqtda driver harakatini ko'rishi mumkin va
  /// driver_locations jadvalida kuzatuv tarixi to'planadi.
  Timer? _locationPushTimer;
  static const Duration _locationPushInterval = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _loadCurrent();
    // Hot-reload yoki widget qayta yaratilganda agar driver allaqachon
    // onlayn bo'lib qolgan bo'lsa, push timer'ni qayta ishga tushiramiz.
    if (_online) _startLocationPushTimer();
  }

  @override
  void dispose() {
    _locationPushTimer?.cancel();
    super.dispose();
  }

  /// Onlayn bo'lganda chaqiriladi — har 1 daqiqada GPS lokatsiyasini
  /// backend'ga POST qiladi. Avval ishga tushgan timer bo'lsa to'xtatamiz.
  void _startLocationPushTimer() {
    _locationPushTimer?.cancel();
    _locationPushTimer = Timer.periodic(_locationPushInterval, (_) {
      _pushCurrentLocation();
    });
  }

  void _stopLocationPushTimer() {
    _locationPushTimer?.cancel();
    _locationPushTimer = null;
  }

  /// Joriy GPS pozitsiyani olib backend'ga yuboradi (sokin — UI'da xato
  /// chiqarmaydi; tarmoq xatosi log'lanadi va keyingi tick urinib ko'radi).
  Future<void> _pushCurrentLocation() async {
    if (!_online) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) return;
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      await DriverApi.instance.saveLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (_) {
      // Sokin — keyingi tick'da qayta urinamiz.
    }
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
      // Moderatsiya holati — admin haydovchini rad etgan yoki holatini
      // o'zgartirgan bo'lsa (status active=4 EMAS), uni shu yerda tegishli
      // sahifaga (rad etilgan / kutilmoqda / failed) yo'naltiramiz. Aks holda
      // rad etilgan driver asosiy ilovada qolib ketadi.
      try {
        final reg = await DriverApi.instance.registrationStatus();
        if (!mounted) return;
        if (reg.driverId != null && reg.status != DriverRegistrationStatus.statusActive) {
          _redirectByModeration(reg);
          return;
        }
      } catch (_) {
        // Status olib bo'lmasa — mavjud xulqni saqlaymiz (ilovada qoladi).
      }

      final cur = await DriverApi.instance.currentOrder();
      // Backend bilan online holatni sinxronlash: buyurtma yakunlanganda
      // server avtomat went_online_at'ni qayta qo'yadi — mobile UI ham
      // shu holatni ko'rsatishi kerak.
      bool serverOnline = _online;
      try {
        final status = await DriverApi.instance.driverStatus();
        serverOnline = status.isOnline;
      } catch (_) {
        // Status endpointi yaroqsiz bo'lsa lokal holat saqlanadi.
      }

      if (!mounted) return;
      setState(() {
        _current = cur;
        _online = serverOnline;
        _busy = false;
      });

      // Agar driver onlinega qaytarilgan bo'lsa-yu lokatsiya timer'i
      // o'chgan bo'lsa — qayta yoqamiz.
      if (serverOnline && _locationPushTimer == null) {
        _startLocationPushTimer();
      } else if (!serverOnline) {
        _stopLocationPushTimer();
      }

      // Online bo'lsa har doim ikkala feed yuklanadi: radius active va rejali.
      // Joriy buyurtma bo'lsa ham — rejali kelajak buyurtmalari ko'rinishi kerak
      // (driver oldinga rejalashtirishi uchun).
      if (serverOnline) {
        unawaited(_loadActive());
      } else {
        setState(() {
          _active = [];
          _scheduled = [];
        });
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

  /// Moderatsiya holatiga qarab driverni asosiy ilovadan tegishli sahifaga
  /// olib chiqadi (butun stekni almashtiramiz — orqaga qaytib bo'lmaydi).
  void _redirectByModeration(DriverRegistrationStatus reg) {
    _stopLocationPushTimer();
    final Widget target;
    switch (reg.status) {
      case DriverRegistrationStatus.statusRejected: // 2 — xatolarni tuzatish sahifasi
        target = DriverRejectedPage(
          phoneDisplay: widget.phoneDisplay,
          userId: widget.userId,
          status: reg,
        );
        break;
      case DriverRegistrationStatus.statusFailed: // 3 — 3 martadan ortiq rad etilgan
        target = DriverFailedPage(phoneDisplay: widget.phoneDisplay);
        break;
      default:
        target = DriverPendingPage(
          phoneDisplay: widget.phoneDisplay,
          userId: widget.userId,
          initialStatus: reg,
        );
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => target),
      (route) => false,
    );
  }

  Future<void> _toggleOnline() async {
    if (_online) {
      // Oflayn — backend'da cargo preferences ham tozalanadi
      try {
        await DriverApi.instance.clearCargoPreferences();
      } catch (_) {}
      if (!mounted) return;
      _stopLocationPushTimer();
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
      // 409 (active order bor) — foydalanuvchi uchun aniq snackbar
      if (e.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.firstFieldMessage)),
        );
      }
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = I18n.t('driver.network_error_label', {'msg': '$e'});
      });
      return;
    }
    if (!mounted) return;
    // Avtomat GPS bilan joylashuv aniqlash
    await _sendCurrentGpsLocation(asOnline: true);
  }

  /// Onlayn bo'lishni qayta urinish — joylashuv xizmati o'chiq/ruxsat yo'q
  /// bo'lib xato chiqqach, foydalanuvchi uni yoqib qayta bosadi. Yuk turlari
  /// avval tanlangani uchun qaytadan so'ramaymiz — to'g'ridan GPS/online'ni
  /// qayta sinab ko'ramiz.
  Future<void> _retryGoOnline() async {
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
          _error = I18n.t('driver.location_permission_denied');
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = I18n.t('driver.location_permission_denied_forever');
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = I18n.t('driver.location_service_disabled');
        });
        return;
      }

      // GPS fiksatsiyasi timeLimit BILAN — aks holda yuqori-aniqlik fiksatsiyasi
      // (ichkarida/sovuq GPS) cheksiz osilib, online'ga o'tish "o'ylanib" qoladi.
      // Vaqt tugasa oxirgi ma'lum joylashuvni ishlatamiz (bo'lsa).
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = I18n.t('driver.gps_timeout');
          });
          return;
        }
        pos = last;
      }
      final latLng = LatLng(pos.latitude, pos.longitude);

      await DriverApi.instance.saveLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return;
      // Online'ga DARHOL o'tamiz — manzil yorlig'i (reverse-geocode) kritik
      // yo'lda emas: avval koordinata ko'rsatiladi, manzil fonda kelib yangilanadi.
      setState(() {
        _pickedLocation = latLng;
        _pickedAddress = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        _online = true;
        _busy = false;
      });

      // Manzilni fonda aniqlaymiz — tayyor bo'lganda yorliqni yangilaymiz.
      _reverseGeocode(latLng).then((addr) {
        if (addr != null && addr.isNotEmpty && mounted) {
          setState(() => _pickedAddress = addr);
        }
      });

      // Onlayn bo'lgandan keyin har 1 daqiqada GPS lokatsiyasini backend'ga
      // yuborib turamiz — customer realtime tracking uchun.
      _startLocationPushTimer();

      if (asOnline) {
        await _loadActive();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('driver.location_updated'))),
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
        _error = I18n.t('driver.gps_error', {'msg': '$e'});
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
      // Ikkala feed parallel: radius bo'yicha + rejali.
      final results = await Future.wait([
        DriverApi.instance.activeOrders(),
        DriverApi.instance.scheduledOrders(),
      ]);
      if (!mounted) return;
      setState(() {
        _active = results[0];
        _scheduled = results[1];
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
        _error = I18n.t('driver.network_error_label', {'msg': '$e'});
      });
    }
  }

  String _statusLabel(int? s) => statusLabelDriver(s);

  String _formatDistance(double? meters, String? km) {
    if (meters != null) {
      if (meters >= 1000) {
        return '${(meters / 1000).toStringAsFixed(1)} ${I18n.t('common.km')}';
      }
      return '${meters.round()} m';
    }
    if (km != null) return '$km ${I18n.t('common.km')}';
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
            Row(
              children: [
                Icon(Icons.local_shipping_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(I18n.t('driver.current_order'), style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            // Joriy buyurtma — feed kartochkasi bilan bir xil dizayn
            // (sarlavha + status + narx + A→B + masofa + chevron). Driver
            // ko'rinishida `_pickedLocation` GPS asosida A gacha masofani
            // ham ko'rsatadi.
            _DriverFeedOrderCard(
              order: _current!,
              driverLocation: _pickedLocation,
              onTap: () => widget.onOpenDetail(_current!, _pickedLocation),
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
                              _online ? I18n.t('driver.online') : I18n.t('driver.offline'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _online ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _online
                                  ? (_pickedAddress ?? I18n.t('driver.location_pending'))
                                  : I18n.t('driver.online_hint'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                  if (_online) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                            _busy ? null : () => _sendCurrentGpsLocation(asOnline: false),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(I18n.t('driver.refresh_location')),
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
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: cs.onErrorContainer, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                                color: cs.onErrorContainer, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: _online ? _loadActive : _retryGoOnline,
                        child: Text(I18n.t('driver.retry_btn_short')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          // ── Joriy / Reja tabbar ──
          // Ikkala tab har doim ko'rinadi. Joriy — radius bo'yicha yangi
          // buyurtmalar (joriy bandlikda yashiriladi). Reja — rejali
          // buyurtmalar (joriy bilan band bo'lsa ham ko'rinadi).
          if (_online) ...[
            _DriverFeedTabsHeader(
              activeCount: _current == null ? _active.length : 0,
              scheduledCount: _scheduled.length,
              activeIsBusy: _current != null,
              selectedIndex: _feedTabIndex,
              onSelect: (i) => setState(() => _feedTabIndex = i),
            ),
            const SizedBox(height: 12),
            if (_feedTabIndex == 0) ...[
              // Joriy (radius)
              if (_current != null)
                Card(
                  color: cs.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: cs.onTertiaryContainer),
                    title: Text(
                      I18n.t('driver.busy_with_current'),
                      style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      I18n.t('driver.busy_with_current_subtitle'),
                      style: TextStyle(color: cs.onTertiaryContainer),
                    ),
                  ),
                )
              else if (_active.isEmpty && !_busy)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.inbox_outlined),
                    title: Text(I18n.t('driver.no_orders_now')),
                    subtitle: Text(I18n.t('driver.archive_subtitle_empty')),
                  ),
                )
              else
                ..._active.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DriverFeedOrderCard(
                        order: o,
                        driverLocation: _pickedLocation,
                        onTap: () => widget.onOpenDetail(o, _pickedLocation),
                      ),
                    )),
            ] else ...[
              // Reja
              if (_scheduled.isEmpty && !_busy)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_busy_rounded),
                    title: Text(I18n.t('driver.no_scheduled_orders')),
                    subtitle: Text(I18n.t('driver.no_scheduled_orders_subtitle')),
                  ),
                )
              else
                ..._scheduled.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DriverFeedOrderCard(
                        order: o,
                        driverLocation: _pickedLocation,
                        onTap: () => widget.onOpenDetail(o, _pickedLocation),
                      ),
                    )),
            ],
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
        _error = I18n.t('driver.network_error_label', {'msg': '$e'});
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
          TextButton(onPressed: _load, child: Text(I18n.t('common.retry'))),
        ],
      );
    }
    if (_list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56),
            const SizedBox(height: 12),
            Text(I18n.t('driver.archive_empty'), textAlign: TextAlign.center),
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
                      order.orderNumber ?? I18n.t('customer.order_number_fallback', {'id': order.id}),
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
                '${_formatMoney(order.totalPrice)} ${order.currency ?? I18n.t('common.uzs')}',
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
  /// Fleet driver bo'lsa avtopark ma'lumoti — null oddiy independent driver.
  DriverFleetInfo? _fleet;
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
      final results = await Future.wait([
        DriverApi.instance.wallet(),
        DriverApi.instance.walletTransactions(),
        DriverApi.instance.fleetInfo(),
      ]);
      if (!mounted) return;
      setState(() {
        _w = results[0] as DriverWalletSnapshot;
        _tx = results[1] as List<DriverWalletTx>;
        _fleet = results[2] as DriverFleetInfo?;
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
        _error = I18n.t('driver.network_error_label', {'msg': '$e'});
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
                trailing: FilledButton.tonal(onPressed: _load, child: Text(I18n.t('common.retry_short'))),
              ),
            ),
          // Fleet driver — avtopark hamyoni va balans ko'rsatilmaydi.
          // Faqat shaxsiy tushumlar tarixi (pastda) ko'rinadi.
          if (_fleet != null && _fleet!.isFleet) ...[
            // Hech narsa: balans va wallet ham ko'rsatilmaydi.
          ] else
            // Independent driver — shaxsiy hamyon asosiy.
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(I18n.t('driver.fleet_earnings_balance'),
                        style: theme.textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatMoney(_w?.balance)} ${_w?.currency ?? I18n.t('common.uzs')}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // "Pul yechib olish" tugmasi faqat independent driver'ga ko'rinadi.
          // Fleet driverda yechib olish avtopark tomonidan amalga oshiriladi.
          if (!(_fleet?.isFleet ?? false)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(I18n.t('driver.withdraw_not_ready'))),
                );
              },
              icon: const Icon(Icons.payments_outlined),
              label: Text(I18n.t('driver.withdraw_card_btn')),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            (_fleet?.isFleet ?? false) ? I18n.t('driver.income_section') : I18n.t('driver.tx_section'),
            style: theme.textTheme.titleSmall,
          ),
          if ((_fleet?.isFleet ?? false)) ...[
            if (_fleet!.recentMyEarnings.isEmpty)
              Card(child: ListTile(title: Text(I18n.t('driver.fleet_no_earnings'))))
            else
              ..._fleet!.recentMyEarnings.map((e) => Card(
                    child: ListTile(
                      leading: Icon(Icons.local_shipping_outlined, color: cs.primary),
                      title: Text(walletTxLabel(
                        transactionType: e.transactionType,
                        rawDescription: e.title,
                        amount: double.tryParse(e.amount ?? ''),
                      )),
                      subtitle: Text([
                        if (e.orderId != null)
                          I18n.t('wallet.tx.order_ref', {'number': e.orderId}),
                        if ((e.createdAt ?? '').isNotEmpty) e.createdAt!,
                      ].join(' · ')),
                      trailing: Text(
                        '+${_formatMoney(e.amount)}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade700),
                      ),
                    ),
                  )),
          ] else if (_tx.isEmpty)
            Card(child: ListTile(title: Text(I18n.t('driver.no_tx'))))
          else
            ..._tx.map((e) {
              final isNeg = e.amount?.startsWith('-') ?? false;
              return Card(
                child: ListTile(
                  leading: Icon(
                    isNeg
                        ? Icons.arrow_circle_up_outlined
                        : Icons.arrow_circle_down_outlined,
                    color: isNeg ? Colors.redAccent : Colors.green.shade700,
                  ),
                  title: Text(walletTxLabel(
                    transactionType: e.transactionType,
                    rawDescription: e.title,
                    amount: double.tryParse(e.amount ?? ''),
                  )),
                  subtitle: Text([
                    if (e.orderId != null)
                      I18n.t('wallet.tx.order_ref', {'number': e.orderId}),
                    if ((e.createdAt ?? '').isNotEmpty) e.createdAt!,
                  ].join(' · ')),
                  trailing: Text(
                    _formatMoney(e.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isNeg ? Colors.redAccent : Colors.green.shade700,
                    ),
                  ),
                ),
              );
            }),
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
                  Text(I18n.t('driver.role_title'),
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
                    title: Text(I18n.t('settings.dark_mode')),
                    subtitle: Text(
                      isDark
                          ? I18n.t('settings.dark_mode_on')
                          : I18n.t('settings.dark_mode_off'),
                    ),
                    value: isDark,
                    onChanged: (v) => ThemeController.instance.setMode(
                      v ? ThemeMode.dark : ThemeMode.light,
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              const LanguagePickerTile(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.security_rounded),
                title: Text(I18n.t('settings.security')),
                subtitle: Text(I18n.t('settings.security_subtitle')),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: Text(I18n.t('settings.help')),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(I18n.t('driver.help_about_driver'))),
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
          label: Text(I18n.t('auth.logout')),
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
      return I18n.t('order.status.new');
    case 2:
      return I18n.t('order.status.active');
    case 3:
      return I18n.t('order.status.accepted_short');
    case 4:
      return I18n.t('order.status.pickup_arrived_short');
    case 5:
      return I18n.t('order.status.loading_short');
    case 6:
      return I18n.t('order.status.in_transit_short');
    case 7:
      return I18n.t('order.status.delivery_arrived_short');
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

/// "Rejali buyurtma" karta — kelajakdagi olib ketish vaqti va countdown.
/// Driver radius'siz alohida bo'limda ko'radi.
class _ScheduledOrderCard extends StatelessWidget {
  const _ScheduledOrderCard({
    required this.order,
    required this.onTap,
    required this.formatMoney,
  });

  final DriverOrder order;
  final VoidCallback onTap;
  final String Function(String?) formatMoney;

  /// Kun.oy HH:mm — qisqa va o'qish oson, badge'ga sig'adi.
  String _shortDateTime(DateTime dt) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  /// Kelajakdagi vaqtgacha qancha qolganini odamga tushunarli ko'rinishda.
  String _countdown(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return I18n.t('driver.time_passed');
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h >= 24) {
      final d = diff.inDays;
      final hh = diff.inHours.remainder(24);
      return I18n.t('driver.days_hours_left', {'d': d, 'h': hh});
    }
    if (h >= 1) return I18n.t('driver.hours_minutes_left', {'h': h, 'm': m});
    return I18n.t('driver.minutes_left', {'m': diff.inMinutes});
  }

  /// Address matni "lat,lng" formatda bo'lsa (reverse-geocode muvaffaqiyatsiz
  /// bo'lganda fallback), uni "Koordinata: …" deb tepalashtirib chiqaramiz —
  /// haqiqiy manzilday ko'rinmasin.
  String _displayAddress(String raw) {
    final t = raw.trim();
    final looksLikeCoord = RegExp(r'^-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?$').hasMatch(t);
    if (looksLikeCoord) {
      return I18n.t('driver.coords_label', {'value': t});
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    DateTime? scheduled;
    if (order.scheduledPickupAt != null) {
      scheduled = DateTime.tryParse(order.scheduledPickupAt!)?.toLocal();
    }
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber ?? I18n.t('customer.order_number_fallback', {'id': order.id}),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (scheduled != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_rounded, size: 13, color: cs.onPrimaryContainer),
                              const SizedBox(width: 4),
                              Text(
                                _shortDateTime(scheduled),
                                style: TextStyle(
                                  color: cs.onPrimaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _countdown(scheduled),
                            style: TextStyle(
                              color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (order.pickupAddress != null)
                Text('A: ${_displayAddress(order.pickupAddress!)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              if (order.deliveryAddress != null)
                Text('B: ${_displayAddress(order.deliveryAddress!)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                '${formatMoney(order.totalPrice)} ${order.currency ?? I18n.t('common.uzs')} · ${order.cargoWeightKg ?? '—'} ${I18n.t('common.kg')}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                    I18n.t('driver.cargo_picker_title'),
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
                I18n.t('driver.cargo_picker_subtitle'),
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
                          : Text(I18n.t('driver.price_per_km', {'value': c.pricePerKm ?? '—'})),
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
                    child: Text(I18n.t('common.cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected.toList()),
                    child: Text(I18n.t('driver.cargo_select_count', {'count': _selected.length})),
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
            Text(I18n.t('customer.mode_label'), style: Theme.of(context).textTheme.titleSmall),
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
                      label: I18n.t('customer.role_customer_segment'),
                      icon: Icons.person_outline_rounded,
                      selected: current == 'customer',
                      onTap: () => onSelect('customer'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _RoleSeg(
                      label: I18n.t('customer.role_driver_segment'),
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

/// Driver home feed tab boshqaruvi — ikkita pill ("Joriy", "Reja"), har
/// birining yonida count badge. Joriy bandlikda Joriy tabning sonini
/// yashiramiz (chunki radius feed ko'rsatilmaydi).
class _DriverFeedTabsHeader extends StatelessWidget {
  const _DriverFeedTabsHeader({
    required this.activeCount,
    required this.scheduledCount,
    required this.activeIsBusy,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int activeCount;
  final int scheduledCount;
  final bool activeIsBusy;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FeedTabPill(
            label: I18n.t('driver.feed_current'),
            count: activeIsBusy ? null : activeCount,
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FeedTabPill(
            label: I18n.t('driver.feed_plan'),
            count: scheduledCount,
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
        ),
      ],
    );
  }
}

class _FeedTabPill extends StatelessWidget {
  const _FeedTabPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.onPrimary.withValues(alpha: 0.2)
                        : cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? cs.onPrimary : cs.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Driver feed uchun buyurtma karta — customer order list dizayni bilan
/// (sarlavha + status chip, katta narx, A→B manzillar, masofa va vaqt
/// oralig'i). Driver pozitsiyasi berilgan bo'lsa undan A nuqtagacha
/// masofa hisoblanib ko'rsatiladi.
class _DriverFeedOrderCard extends StatelessWidget {
  const _DriverFeedOrderCard({
    required this.order,
    required this.driverLocation,
    required this.onTap,
  });

  final DriverOrder order;
  final LatLng? driverLocation;
  final VoidCallback onTap;

  double? _distanceToPickupMeters() {
    final lat = order.pickupLat;
    final lng = order.pickupLng;
    if (lat == null || lng == null || driverLocation == null) return null;
    return Geolocator.distanceBetween(
      driverLocation!.latitude,
      driverLocation!.longitude,
      lat,
      lng,
    );
  }

  String _formatDistanceShort(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = order.status;
    final distM = _distanceToPickupMeters();

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber ?? I18n.t('customer.order_number_fallback', {'id': order.id}),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (order.scheduledPickupAt != null) ...[
                    const SizedBox(width: 6),
                    _DriverScheduledBadge(scheduledAtIso: order.scheduledPickupAt!),
                  ],
                  const SizedBox(width: 8),
                  _DriverMiniStatusChip(status: s),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatMoney(order.totalPrice)} ${order.currency ?? I18n.t('common.uzs')}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
              ),
              const SizedBox(height: 12),
              _DriverAbRow(isStart: true, label: 'A', address: order.pickupAddress ?? '—'),
              const SizedBox(height: 6),
              _DriverAbRow(isStart: false, label: 'B', address: order.deliveryAddress ?? '—'),
              const SizedBox(height: 12),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.my_location_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    distM != null
                        ? I18n.t('driver.distance_to_a', {'value': _formatDistanceShort(distM)})
                        : I18n.t('driver.distance_to_a_unknown'),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.scale_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${order.cargoWeightKg ?? '—'} ${I18n.t('common.kg')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverAbRow extends StatelessWidget {
  const _DriverAbRow({
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

class _DriverMiniStatusChip extends StatelessWidget {
  const _DriverMiniStatusChip({required this.status});

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
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        break;
      default:
        bg = cs.surfaceContainerHigh;
        fg = cs.onSurface;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabelDriver(status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _DriverScheduledBadge extends StatelessWidget {
  const _DriverScheduledBadge({required this.scheduledAtIso});

  final String scheduledAtIso;

  String _short(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dt = DateTime.tryParse(scheduledAtIso)?.toLocal();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded, size: 12, color: cs.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            dt != null ? _short(dt) : I18n.t('customer.scheduled_badge_short'),
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
