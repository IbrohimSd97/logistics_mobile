import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/brand/alix_components.dart';
import '../core/brand/order_status_tone.dart';
import '../core/brand/alix_logo.dart';
import '../core/theme/app_palette.dart';
import '../core/location/current_location.dart';
import '../core/location/yandex_geocoder.dart';
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
    final ok = await showAlixConfirm(
      context,
      icon: Icons.logout_rounded,
      title: I18n.t('auth.logout'),
      message: I18n.t('auth.logout_confirm'),
      confirmLabel: I18n.t('auth.logout'),
      cancelLabel: I18n.t('common.cancel'),
      danger: true,
    );
    if (!ok || !mounted) return;
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
        // Bosh sahifada brend lockup'i, qolgan tab'larda bo'lim nomi —
        // logotip ilovaning birinchi ekranida darrov ko'zga tashlanadi.
        title: _index == 0
            ? const AlixLogo(height: 22)
            : Text(_titles[_index]),
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

class DriverHomeBodyState extends State<DriverHomeBody>
    with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _loadCurrent();
    // Hot-reload yoki widget qayta yaratilganda agar driver allaqachon
    // onlayn bo'lib qolgan bo'lsa, push timer'ni qayta ishga tushiramiz.
    if (_online) _startLocationPushTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationPushTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Ilova fon'dan qaytdi — eski (bayon qolgan) ma'lumot ko'rsatilmasin:
      // joriy buyurtmani serverdan qayta yuklaymiz. (Uzoq suspend'dan keyin
      // ekranda eski karta qolib ketishi muammosini hal qiladi.)
      _loadCurrent();
      if (_online) {
        _startLocationPushTimer();
        if (_current == null) _loadActive();
      }
    } else if (state == AppLifecycleState.paused) {
      // Fon'da GPS push timer'ni to'xtatamiz — batareya/CPU tejaladi va
      // resume paytida toza qayta ishga tushadi.
      _stopLocationPushTimer();
    }
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

      // Periodik push — oxirgi ma'lum joylashuvni ishlatamiz (ANR-xavfsiz;
      // har tick'da yangi fix so'rab NMEA start/stop churn qilmaymiz).
      final pos = await CurrentLocation.oneShot(timeLimit: const Duration(seconds: 8));
      if (pos == null) return;
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

  Future<String?> _reverseGeocode(LatLng p) => YandexGeocoder.reverse(p);

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

  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadCurrent();
        if (_online && _current == null) await _loadActive();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          // Smena holati — ekrandagi eng muhim element: haydovchi birinchi
          // navbatda "men liniyadamanmi?" degan savolga javob izlaydi.
          // Shuning uchun online holat brendning to'q plastinkasida.
          _ShiftCard(
            online: _online,
            busy: _busy,
            address: _pickedAddress,
            onToggle: _busy ? null : _toggleOnline,
            onRefreshLocation:
                _busy ? null : () => _sendCurrentGpsLocation(asOnline: false),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AlixBanner(
              message: _error!,
              icon: Icons.error_outline_rounded,
              action: TextButton(
                onPressed: _online ? _loadActive : _retryGoOnline,
                child: Text(I18n.t('driver.retry_btn_short')),
              ),
            ),
          ],
          if (_current != null) ...[
            const SizedBox(height: 24),
            AlixSectionTitle(I18n.t('driver.current_order')),
            _DriverFeedOrderCard(
              order: _current!,
              driverLocation: _pickedLocation,
              onTap: () => widget.onOpenDetail(_current!, _pickedLocation),
            ),
          ],
          // ── Joriy / Reja tabbar ──
          // Ikkala tab har doim ko'rinadi. Joriy — radius bo'yicha yangi
          // buyurtmalar (joriy bandlikda yashiriladi). Reja — rejali
          // buyurtmalar (joriy bilan band bo'lsa ham ko'rinadi).
          if (_online) ...[
            const SizedBox(height: 24),
            _DriverFeedTabsHeader(
              activeCount: _current == null ? _active.length : 0,
              scheduledCount: _scheduled.length,
              activeIsBusy: _current != null,
              selectedIndex: _feedTabIndex,
              onSelect: (i) => setState(() => _feedTabIndex = i),
            ),
            const SizedBox(height: 14),
            if (_feedTabIndex == 0) ...[
              // Joriy (radius)
              if (_current != null)
                AlixBanner(
                  message: '${I18n.t('driver.busy_with_current')}\n'
                      '${I18n.t('driver.busy_with_current_subtitle')}',
                  tone: AlixTone.warning,
                  icon: Icons.info_outline_rounded,
                )
              else if (_active.isEmpty && !_busy)
                AlixEmptyState(
                  icon: Icons.inbox_outlined,
                  title: I18n.t('driver.no_orders_now'),
                  message: I18n.t('driver.archive_subtitle_empty'),
                )
              else
                ..._active.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DriverFeedOrderCard(
                        order: o,
                        driverLocation: _pickedLocation,
                        onTap: () => widget.onOpenDetail(o, _pickedLocation),
                      ),
                    )),
            ] else ...[
              // Reja
              if (_scheduled.isEmpty && !_busy)
                AlixEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: I18n.t('driver.no_scheduled_orders'),
                  message: I18n.t('driver.no_scheduled_orders_subtitle'),
                )
              else
                ..._scheduled.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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

/// Smena kartasi: online bo'lsa to'q plastinka va orange indikator,
/// offline bo'lsa jim krem karta. Holat bir qarashda o'qilishi kerak.
class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.online,
    required this.busy,
    required this.address,
    required this.onToggle,
    required this.onRefreshLocation,
  });

  final bool online;
  final bool busy;
  final String? address;
  final VoidCallback? onToggle;
  final VoidCallback? onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onCard = online ? Colors.white : cs.onSurface;
    final onCardMuted =
        online ? Colors.white.withValues(alpha: 0.72) : cs.onSurfaceVariant;

    return AlixCard(
      tone: online ? AlixSurfaceTone.ink : AlixSurfaceTone.cream,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: online ? AppPalette.orange : cs.outlineVariant,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  online ? I18n.t('driver.online') : I18n.t('driver.offline'),
                  style: theme.textTheme.titleLarge?.copyWith(color: onCard),
                ),
              ),
              Switch(
                value: online,
                onChanged: onToggle == null ? null : (_) => onToggle!(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            online
                ? (address ?? I18n.t('driver.location_pending'))
                : I18n.t('driver.online_hint'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: onCardMuted),
          ),
          if (online) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRefreshLocation,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(I18n.t('driver.refresh_location')),
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.orange,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          AlixBanner(
            message: _error!,
            icon: Icons.error_outline_rounded,
            action: TextButton(
              onPressed: _load,
              child: Text(I18n.t('common.retry')),
            ),
          ),
        ],
      );
    }
    if (_list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 96),
          children: [
            AlixEmptyState(
              icon: Icons.inventory_2_outlined,
              title: I18n.t('driver.archive_empty'),
              message: I18n.t('driver.archive_subtitle_empty'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        itemCount: _list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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

  /// Buyurtma qachon yopilgan: yakunlangan, bekor qilingan yoki yetkazilgan.
  String? _orderEndIso(DriverOrder o) =>
      o.completedAt ?? o.cancelledAt ?? o.deliveredAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber ??
                      I18n.t('customer.order_number_fallback', {'id': order.id}),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _MiniStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatMoney(order.totalPrice)} ${order.currency ?? I18n.t('common.uzs')}',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _DriverRoute(
            pickup: order.pickupAddress ?? '—',
            delivery: order.deliveryAddress ?? '—',
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 10),
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
    );
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

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({required this.status});

  final int? status;

  @override
  Widget build(BuildContext context) {
    return AlixStatusChip(
      label: statusLabelDriver(status),
      tone: orderStatusTone(status),
    );
  }
}

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
    final isFleet = _fleet?.isFleet ?? false;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          if (_error != null) ...[
            AlixBanner(
              message: _error!,
              icon: Icons.error_outline_rounded,
              action: TextButton(
                onPressed: _load,
                child: Text(I18n.t('common.retry_short')),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Avtopark haydovchisida shaxsiy balans bo'lmaydi — pul avtoparkka
          // tushadi, shuning uchun unga faqat tushumlar tarixi ko'rsatiladi.
          if (!isFleet) ...[
            _DriverBalanceCard(
              label: I18n.t('driver.fleet_earnings_balance'),
              amount:
                  '${_formatMoney(_w?.balance)} ${_w?.currency ?? I18n.t('common.uzs')}',
            ),
            const SizedBox(height: 14),
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
          const SizedBox(height: 26),
          AlixSectionTitle(
            isFleet ? I18n.t('driver.income_section') : I18n.t('driver.tx_section'),
          ),
          if (isFleet) ...[
            if (_fleet!.recentMyEarnings.isEmpty)
              AlixEmptyState(
                icon: Icons.receipt_long_outlined,
                title: I18n.t('driver.fleet_no_earnings'),
              )
            else
              ..._fleet!.recentMyEarnings.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AlixTxRow(
                    icon: Icons.local_shipping_outlined,
                    title: walletTxLabel(
                      transactionType: e.transactionType,
                      rawDescription: e.title,
                      amount: double.tryParse(e.amount ?? ''),
                    ),
                    meta: _txMeta(e.orderId, e.createdAt),
                    amount: '+${_formatMoney(e.amount)}',
                  ),
                ),
              ),
          ] else if (_tx.isEmpty)
            AlixEmptyState(
              icon: Icons.receipt_long_outlined,
              title: I18n.t('driver.no_tx'),
            )
          else
            ..._tx.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AlixTxRow(
                  title: walletTxLabel(
                    transactionType: e.transactionType,
                    rawDescription: e.title,
                    amount: double.tryParse(e.amount ?? ''),
                  ),
                  meta: _txMeta(e.orderId, e.createdAt),
                  amount: _formatMoney(e.amount),
                  negative: e.amount?.startsWith('-') ?? false,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Qatorning ikkinchi satri: buyurtma raqami va sana (mahalliy vaqtda).
  String _txMeta(int? orderId, String? createdAtIso) {
    final dt = DateTime.tryParse(createdAtIso ?? '')?.toLocal();
    String p2(int v) => v.toString().padLeft(2, '0');
    return [
      if (orderId != null) I18n.t('wallet.tx.order_ref', {'number': orderId}),
      if (dt != null)
        '${p2(dt.day)}.${p2(dt.month)}.${dt.year} ${p2(dt.hour)}:${p2(dt.minute)}',
    ].join(' · ');
  }
}

/// Haydovchi balansi — mijoz hamyonidagi kabi to'q plastinka.
class _DriverBalanceCard extends StatelessWidget {
  const _DriverBalanceCard({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlixCard(
      tone: AlixSurfaceTone.ink,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppPalette.radiusCard),
              ),
              child: Text(
                _initial,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(I18n.t('driver.role_title'), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    phoneDisplay,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text('ID: $userId', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        DriverRoleSegmented(
          current: 'driver',
          onSelect: (role) {
            if (role == 'customer') onSwitchToCustomer();
          },
        ),
        const SizedBox(height: 22),
        AlixSectionTitle(I18n.t('settings.title')),
        AlixCard(
          padding: EdgeInsets.zero,
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
              Divider(height: 1, color: cs.outlineVariant),
              const LanguagePickerTile(),
              Divider(height: 1, color: cs.outlineVariant),
              ListTile(
                leading: const Icon(Icons.security_rounded),
                title: Text(I18n.t('settings.security')),
                subtitle: Text(I18n.t('settings.security_subtitle')),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: Text(I18n.t('settings.help')),
                trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(I18n.t('driver.help_about_driver'))),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: Text(I18n.t('auth.logout')),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.error,
            side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
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
                const Icon(Icons.local_shipping_rounded, color: AppPalette.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    I18n.t('driver.cargo_picker_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                I18n.t('driver.cargo_picker_subtitle'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 14),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AlixBanner(message: _error!, icon: Icons.error_outline_rounded),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = _items[i];
                  final isSelected = _selected.contains(c.id);
                  // Tanlangan qator orange chegara bilan ajraladi — faqat fon
                  // rangi bilan ajratish kam sezilar edi.
                  return Material(
                    color: isSelected
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppPalette.radiusField),
                      side: BorderSide(
                        color: isSelected ? AppPalette.orange : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppPalette.radiusField),
                      ),
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
    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(I18n.t('customer.mode_label'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppPalette.radiusField),
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
        borderRadius: BorderRadius.circular(AppPalette.radiusChip),
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppPalette.radiusChip),
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
                    borderRadius: BorderRadius.circular(AppPalette.radiusChip),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final distM = _distanceToPickupMeters();

    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber ??
                      I18n.t('customer.order_number_fallback', {'id': order.id}),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (order.scheduledPickupAt != null) ...[
                const SizedBox(width: 6),
                _DriverScheduledBadge(scheduledAtIso: order.scheduledPickupAt!),
                const SizedBox(width: 6),
              ],
              _DriverMiniStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatMoney(order.totalPrice)} ${order.currency ?? I18n.t('common.uzs')}',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _DriverRoute(
            pickup: order.pickupAddress ?? '—',
            delivery: order.deliveryAddress ?? '—',
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.my_location_rounded, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                distM != null
                    ? I18n.t('driver.distance_to_a',
                        {'value': _formatDistanceShort(distM)})
                    : I18n.t('driver.distance_to_a_unknown'),
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 14),
              Icon(Icons.scale_rounded, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                '${order.cargoWeightKg ?? '—'} ${I18n.t('common.kg')}',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }
}

/// Yo'nalish bloki — mijoz ro'yxatidagi bilan bir xil til: to'q nuqta
/// olib ketish, orange nuqta yetkazish, orasida bog'lovchi chiziq.
class _DriverRoute extends StatelessWidget {
  const _DriverRoute({required this.pickup, required this.delivery});

  final String pickup;
  final String delivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget dot(Color color) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );

    Widget address(String value) => Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600, height: 1),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            dot(cs.onSurface),
            Container(width: 2, height: 22, color: cs.outlineVariant),
            dot(AppPalette.orange),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              address(pickup),
              const SizedBox(height: 18),
              address(delivery),
            ],
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
    // Rang mijoz ekranlaridagi bilan bitta manbadan olinadi.
    return AlixStatusChip(
      label: statusLabelDriver(status),
      tone: orderStatusTone(status),
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
