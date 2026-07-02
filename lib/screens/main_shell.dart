import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../core/api/auth_api.dart';
import '../core/i18n/i18n.dart';
import '../core/session/session_store.dart';
import '../core/theme/theme_controller.dart';
import '../customer/customer_api.dart';
import '../customer/customer_models.dart';
import '../customer/pages/customer_order_create_page.dart';
import '../customer/pages/customer_order_detail_page.dart';
import '../customer/pages/customer_physical_registration_page.dart';
import '../customer/pages/customer_wallet_topup_page.dart' as wallet_page;
import '../driver/driver_api.dart';
import '../driver/driver_models.dart';
import '../driver/pages/driver_failed_page.dart';
import '../driver/pages/driver_order_detail_page.dart';
import '../driver/pages/driver_pending_page.dart';
import '../driver/pages/driver_registration_step1_page.dart';
import '../driver/pages/driver_rejected_page.dart';
import 'customer_main_shell.dart';
import 'driver_main_shell.dart';
import 'login_screen.dart';

/// Bir foydalanuvchi (bir telefon) ham customer ham driver bo'lishi mumkin.
/// Bottom navigation barcha rejim uchun bir xil — Profile'dagi toggle
/// content'ni almashtiradi (push replacement emas).
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.initialMode,
    required this.phoneDisplay,
    this.userId,
    this.hasRefreshSession = true,
  });

  /// 'customer' yoki 'driver'
  final String initialMode;
  final String phoneDisplay;
  final int? userId;
  final bool hasRefreshSession;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with I18nObserverMixin<MainShell> {
  // Tab matnlari — joriy I18n locale bo'yicha hisoblanadi (getter).
  List<String> get _titles => [
        I18n.t('shell.tab_home'),
        I18n.t('shell.tab_orders'),
        I18n.t('shell.tab_wallet'),
        I18n.t('shell.tab_profile'),
      ];

  late String _mode;
  int _index = 0;
  int _refreshTick = 0;
  bool _hasRefresh = false;
  int? _userId;

  /// Customer Buyurtmalar tab'i ichida tanlanadigan boshlang'ich tab
  /// (0=Joriy, 1=Arxiv). Bosh sahifadagi Joriy/Arxiv ko'rsatkich kartasi
  /// bosilganda yangilanadi va `CustomerOrdersBody` `key` o'zgarishi bilan
  /// re-mount qilinib, boshlang'ich tab'ga o'tadi.
  int _customerOrdersInitialTab = 0;
  int _customerOrdersKey = 0;

  void _openCustomerOrdersTab(int initialTab) {
    setState(() {
      _customerOrdersInitialTab = initialTab;
      _customerOrdersKey++;
      _index = 1;
    });
  }

  final _session = SessionStore();

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _userId = widget.userId;
    _hasRefresh = widget.hasRefreshSession;
    _syncFromStore();
  }

  Future<void> _syncFromStore() async {
    final t = await _session.getRefreshToken();
    final uid = await _session.getUserId();
    if (!mounted) return;
    setState(() {
      _hasRefresh = t != null && t.isNotEmpty;
      _userId = _userId ?? uid;
    });
  }

  void _bumpRefresh() {
    if (!mounted) return;
    setState(() => _refreshTick++);
  }

  void _setMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _index = 0;
      _refreshTick++;
    });
    // Backend'ga ham yozamiz (oxirgi rejim users.role'ga saqlanadi).
    _persistRole(mode);
  }

  Future<void> _persistRole(String role) async {
    try {
      final refresh = await _session.getRefreshToken();
      if (refresh == null || refresh.isEmpty) return;
      await const AuthApi().switchRole(refreshToken: refresh, role: role);
    } catch (_) {
      // Local state allaqachon o'zgargan; serverda muvaffaqiyatsizlikni jimgina o'tkazamiz.
    }
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
    await _session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────── Customer flows ───────────────────────

  Future<void> _openOrderCreate() async {
    if (_hasRefresh) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const CustomerOrderCreatePage()),
      );
      if (!mounted) return;
      await _syncFromStore();
      _bumpRefresh();
      return;
    }
    final temp = await _session.getTempRegistrationToken();
    if (temp != null && temp.isNotEmpty) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(I18n.t('customer.reg.required_title')),
          content: Text(I18n.t('customer.reg.required_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(I18n.t('common.later'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(I18n.t('customer.reg.register_btn'))),
          ],
        ),
      );
      if (go == true && mounted) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => CustomerPhysicalRegistrationPage(phoneDisplay: widget.phoneDisplay),
          ),
        );
        if (ok == true && mounted) {
          await _syncFromStore();
          _bumpRefresh();
        }
      }
      return;
    }
    if (!mounted) return;
    _toast('Sessiya topilmadi. Iltimos, qayta kiring.');
  }

  /// Customer → Haydovchi rejim. Driver record bor bo'lsa status'ga qarab,
  /// yo'q bo'lsa registratsiya. Muvaffaqiyat — _setMode('driver').
  Future<void> _switchToDriverMode() async {
    // 1) Driver record bormi tekshiramiz
    if (_hasRefresh) {
      DriverRegistrationStatus? status;
      try {
        status = await DriverApi.instance.registrationStatus();
      } catch (_) {}
      if (!mounted) return;
      if (status != null && status.driverId != null) {
        switch (status.status) {
          case DriverRegistrationStatus.statusActive: // 4
            _setMode('driver');
            return;
          case DriverRegistrationStatus.statusRejected: // 2 — xatolarni tuzatish sahifasi
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DriverRejectedPage(
                  phoneDisplay: widget.phoneDisplay,
                  userId: _userId ?? 0,
                  status: status!,
                ),
              ),
            );
            return;
          case DriverRegistrationStatus.statusFailed: // 3 — 3 martadan ortiq rad etilgan
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DriverFailedPage(phoneDisplay: widget.phoneDisplay),
              ),
            );
            return;
          case DriverRegistrationStatus.statusPending: // 1
          default:
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DriverPendingPage(
                  phoneDisplay: widget.phoneDisplay,
                  userId: _userId ?? 0,
                  initialStatus: status,
                ),
              ),
            );
            return;
        }
      }
    }

    // 2) Driver record yo'q — registratsiyani boshlash. Temp token kerak.
    String? temp = await _session.getTempRegistrationToken();
    if (!mounted) return;
    if (temp == null || temp.isEmpty) {
      final refresh = await _session.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        _toast('Sessiya topilmadi. Iltimos, qayta kiring.');
        return;
      }
      try {
        temp = await const AuthApi().issueTempTokenFromRefresh(refresh);
        await _session.saveTempRegistrationToken(temp);
      } on ApiException catch (e) {
        _toast('Temp token: ${e.firstFieldMessage}');
        return;
      } catch (e) {
        _toast('Tarmoq xatosi: $e');
        return;
      }
    }
    if (!mounted) return;

    // Customer profilni olib step1 ga prefill
    CustomerProfile? profile;
    if (_hasRefresh) {
      try {
        profile = await CustomerApi.instance.me();
      } catch (_) {}
    }
    if (!mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DriverRegistrationStep1Page(
          phoneDisplay: widget.phoneDisplay,
          prefillLastName: profile?.lastName,
          prefillFirstName: profile?.firstName,
          prefillMiddleName: profile?.middleName,
          prefillBirthDate: profile?.birthDate,
        ),
      ),
    );
    if (!mounted) return;
    await _syncFromStore();
    _bumpRefresh();

    if (ok == true) {
      // Step3 muvaffaqiyatli — endi rol Driver. Mode'ni ham o'zgartiramiz.
      _setMode('driver');
      // Status'ga qarab pending/active/rejected/failed sahifasini ochamiz.
      await _routeAfterDriverRegistration();
    }
  }

  Future<void> _routeAfterDriverRegistration() async {
    DriverRegistrationStatus? status;
    try {
      status = await DriverApi.instance.registrationStatus();
    } catch (_) {}
    if (!mounted) return;
    if (status == null) return;
    Widget? target;
    switch (status.status) {
      case DriverRegistrationStatus.statusActive: // 4 — driver mode shellni o'zi ko'rsatadi
        return;
      case DriverRegistrationStatus.statusRejected: // 2 — xatolarni tuzatish sahifasi
        target = DriverRejectedPage(
          phoneDisplay: widget.phoneDisplay,
          userId: _userId ?? 0,
          status: status,
        );
        break;
      case DriverRegistrationStatus.statusFailed: // 3 — 3 martadan ortiq rad etilgan
        target = DriverFailedPage(phoneDisplay: widget.phoneDisplay);
        break;
      case DriverRegistrationStatus.statusPending: // 1
      default:
        target = DriverPendingPage(
          phoneDisplay: widget.phoneDisplay,
          userId: _userId ?? 0,
          initialStatus: status,
        );
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => target!),
    );
  }

  /// Driver → Customer rejim. Customer record bor bo'lsa setMode, yo'q bo'lsa registratsiya.
  Future<void> _switchToCustomerMode() async {
    // 1) Customer record bormi
    try {
      final profile = await CustomerApi.instance.me();
      if (profile != null && mounted) {
        _setMode('customer');
        return;
      }
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 403) {
        if (!mounted) return;
        _toast(e.firstFieldMessage);
        return;
      }
      // 404/403 → record yo'q. Registratsiya.
    } catch (e) {
      if (!mounted) return;
      _toast('Tarmoq xatosi: $e');
      return;
    }

    // 2) Customer record yo'q — registratsiya. Temp token kerak.
    String? temp = await _session.getTempRegistrationToken();
    if (!mounted) return;
    if (temp == null || temp.isEmpty) {
      final refresh = await _session.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        _toast('Sessiya topilmadi.');
        return;
      }
      try {
        temp = await const AuthApi().issueTempTokenFromRefresh(refresh);
        await _session.saveTempRegistrationToken(temp);
      } catch (e) {
        if (!mounted) return;
        _toast('Temp token: $e');
        return;
      }
    }
    if (!mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CustomerPhysicalRegistrationPage(phoneDisplay: widget.phoneDisplay),
      ),
    );
    if (ok == true && mounted) {
      await _syncFromStore();
      _setMode('customer');
    }
  }

  // ─────────────────────── Build ───────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: _mode == 'customer'
            ? [
                IconButton(
                  tooltip: I18n.t('common.refresh'),
                  onPressed: () {
                    _syncFromStore();
                    _bumpRefresh();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: I18n.t('shell.notifications'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(I18n.t('shell.notifications_soon'))),
                    );
                  },
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                IconButton(
                  tooltip: I18n.t('auth.logout'),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ]
            : [
                IconButton(
                  tooltip: I18n.t('common.refresh'),
                  onPressed: () {
                    _syncFromStore();
                    _bumpRefresh();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: I18n.t('auth.logout'),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
      ),
      // IndexedStack — barcha tab body'lari tirik turadi, faqat ko'rinish o'zgaradi
      // (state — masalan onlayn holati — tab almashganda yo'qolmaydi).
      // Mode'ni o'zgartirilganda butun stack qayta yaratiladi (key orqali).
      body: _mode == 'driver'
          ? IndexedStack(
              key: const ValueKey('driver-stack'),
              index: _index,
              children: _driverChildren(),
            )
          : IndexedStack(
              key: const ValueKey('customer-stack'),
              index: _index,
              children: _customerChildren(),
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

  List<Widget> _customerChildren() {
    return [
      CustomerHomeBody(
        phoneDisplay: widget.phoneDisplay,
        userId: _userId,
        hasRefreshSession: _hasRefresh,
        refreshTick: _refreshTick,
        onRefreshParent: _syncFromStore,
        onCreateOrder: _openOrderCreate,
        onOpenOrders: _openCustomerOrdersTab,
      ),
      CustomerOrdersBody(
        key: ValueKey<int>(_customerOrdersKey),
        initialTab: _customerOrdersInitialTab,
        hasRefreshSession: _hasRefresh,
        refreshTick: _refreshTick,
        onOpenDetail: (o) {
          Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => CustomerOrderDetailPage(order: o),
            ),
          ).then((changed) {
            if (changed == true) {
              _syncFromStore();
              _bumpRefresh();
            }
          });
        },
      ),
      CustomerWalletBody(
        hasRefreshSession: _hasRefresh,
        refreshTick: _refreshTick,
        onTopUp: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const wallet_page.CustomerWalletTopupPage(),
            ),
          ).then((_) {
            _syncFromStore();
            _bumpRefresh();
          });
        },
      ),
      CustomerProfileBody(
        phoneDisplay: widget.phoneDisplay,
        userId: _userId,
        hasRefreshSession: _hasRefresh,
        onLogout: _logout,
        onBecomeDriver: _switchToDriverMode,
        onOpenRegistration: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => CustomerPhysicalRegistrationPage(phoneDisplay: widget.phoneDisplay),
            ),
          );
          if (ok == true && mounted) {
            await _syncFromStore();
            _bumpRefresh();
          }
        },
      ),
    ];
  }

  List<Widget> _driverChildren() {
    return [
      DriverHomeBody(
        phoneDisplay: widget.phoneDisplay,
        userId: widget.userId ?? 0,
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
        userId: _userId ?? 0,
        onLogout: _logout,
        onSwitchToCustomer: _switchToCustomerMode,
      ),
    ];
  }
}

/// Theme toggle widget — profile sahifalari uchun.
Widget themeSwitchTile() {
  return AnimatedBuilder(
    animation: Listenable.merge([ThemeController.instance, I18n.instance]),
    builder: (_, __) {
      final isDark = ThemeController.instance.mode == ThemeMode.dark;
      return SwitchListTile(
        secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
        title: Text(I18n.t('settings.dark_mode')),
        subtitle: Text(isDark ? I18n.t('settings.dark_mode_on') : I18n.t('settings.dark_mode_off')),
        value: isDark,
        onChanged: (v) => ThemeController.instance.setMode(
          v ? ThemeMode.dark : ThemeMode.light,
        ),
      );
    },
  );
}
