import 'package:flutter/material.dart';

import '../core/brand/alix_components.dart';
import '../core/brand/order_status_tone.dart';
import '../core/brand/alix_logo.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/gradient_button.dart';
import '../core/api/api_exception.dart';
import '../core/api/auth_api.dart';
import '../core/i18n/i18n.dart';
import '../core/i18n/language_picker.dart';
import '../core/i18n/wallet_tx_labels.dart';
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
import '../driver/pages/driver_pending_page.dart';
import '../driver/pages/driver_registration_step1_page.dart';
import '../driver/pages/driver_rejected_page.dart';
import 'driver_main_shell.dart';
import 'login_screen.dart';

/// ISO sanani mahalliy vaqtda "DD.MM.YYYY HH:mm" ko'rinishida beradi.
/// Backend UTC yuboradi, foydalanuvchi esa o'z vaqtini kutadi.
String _formatDateTime(String? iso) {
  final dt = DateTime.tryParse(iso ?? '');
  if (dt == null) return '';
  final local = dt.toLocal();
  String p2(int v) => v.toString().padLeft(2, '0');
  return '${p2(local.day)}.${p2(local.month)}.${local.year} '
      '${p2(local.hour)}:${p2(local.minute)}';
}

String _formatNumber(String? raw) {
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

/// Order status kodlari `OrderStatusCode` (1..12) bilan mos — driver listidagidek.
String _statusLabel(int? s) {
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

/// Buyurtmachi mobil asosiy oqim.
class CustomerMainShell extends StatefulWidget {
  const CustomerMainShell({
    super.key,
    required this.phoneDisplay,
    this.userId,
    this.hasRefreshSession = false,
  });

  final String phoneDisplay;
  final int? userId;
  final bool hasRefreshSession;

  @override
  State<CustomerMainShell> createState() => _CustomerMainShellState();
}

class _CustomerMainShellState extends State<CustomerMainShell>
    with I18nObserverMixin<CustomerMainShell> {
  int _index = 0;
  // Tab matnlari — joriy I18n locale bo'yicha hisoblanadi (getter).
  List<String> get _titles => [
        I18n.t('shell.tab_home'),
        I18n.t('shell.tab_orders'),
        I18n.t('shell.tab_wallet'),
        I18n.t('shell.tab_profile'),
      ];

  bool _hasRefresh = false;
  int? _userId;
  int _refreshTick = 0;

  /// Bosh sahifadagi Joriy/Arxiv kartalardan kelgan boshlang'ich tab.
  /// Buyurtmalar tab'i ko'rsatilganda `_CustomerOrdersBody`'ga `key` bilan
  /// uzatiladi → tab re-mount bo'lib `initialTab`'ga o'tadi.
  int _ordersInitialTab = 0;
  int _ordersKey = 0;

  void _openOrdersTab(int initialTab) {
    setState(() {
      _ordersInitialTab = initialTab;
      _ordersKey++;
      _index = 1;
    });
  }

  final _session = SessionStore();

  void _bumpRefresh() {
    if (!mounted) return;
    setState(() => _refreshTick++);
  }

  @override
  void initState() {
    super.initState();
    _hasRefresh = widget.hasRefreshSession;
    _userId = widget.userId;
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

  /// TZ: `exchange-token` «Please complete registration first» bo‘lsa refresh yo‘q, lekin asosiy sahifa ochiq.
  /// Buyurtma faqat to‘liq sessiya (verifikatsiya + exchange) dan keyin.
  Future<void> _openOrderCreate() async {
    if (_hasRefresh) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const CustomerOrderCreatePage()),
      );
      await _syncFromStore();
      return;
    }

    final temp = await _session.getTempRegistrationToken();
    if (temp != null && temp.isNotEmpty) {
      if (!mounted) return;
      final go = await showAlixConfirm(
        context,
        icon: Icons.app_registration_rounded,
        title: I18n.t('auth.registration_required'),
        message: I18n.t('auth.registration_required_body'),
        confirmLabel: I18n.t('auth.register_now'),
        cancelLabel: I18n.t('auth.later'),
      );
      if (go && mounted) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => CustomerPhysicalRegistrationPage(phoneDisplay: widget.phoneDisplay),
          ),
        );
        if (ok == true) await _syncFromStore();
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.t('auth.session_not_found'))),
    );
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
    await _session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// "Haydovchi bo'lish" / "Haydovchi rejimi" tugmasi handler.
  /// - Driver record bor: status'ga qarab pending/main/rejected/failed sahifaga
  /// - Driver record yo'q: step1 ga (kerak bo'lsa issue-temp-token chaqiradi)
  Future<void> _openDriverRegistration() async {
    final hasRefresh = await _session.getRefreshToken();
    if (!mounted) return;

    // Refresh bor → driver status'ni tekshiramiz
    if (hasRefresh != null && hasRefresh.isNotEmpty) {
      DriverRegistrationStatus? status;
      try {
        status = await DriverApi.instance.registrationStatus();
      } catch (_) {
        // Status olib bo'lmadi — registratsiya boshlangan deb hisoblaymiz
      }
      if (!mounted) return;
      if (status != null && status.driverId != null) {
        // Driver record mavjud — status'ga qarab yo'naltiramiz
        Widget target;
        switch (status.status) {
          case DriverRegistrationStatus.statusActive: // 4 = active
            target = DriverMainShell(
              phoneDisplay: widget.phoneDisplay,
              userId: _userId ?? 0,
              userType: 'driver',
            );
            break;
          case DriverRegistrationStatus.statusRejected: // 2 = rejected — xatolarni tuzatish
            target = DriverRejectedPage(
              phoneDisplay: widget.phoneDisplay,
              userId: _userId ?? 0,
              status: status,
            );
            break;
          case DriverRegistrationStatus.statusFailed: // 3 = failed
            target = DriverFailedPage(phoneDisplay: widget.phoneDisplay);
            break;
          case DriverRegistrationStatus.statusPending: // 1 = pending
          default:
            target = DriverPendingPage(
              phoneDisplay: widget.phoneDisplay,
              userId: _userId ?? 0,
              initialStatus: status,
            );
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => target),
        );
        return;
      }
    }

    // Driver record yo'q — registratsiyani boshlash uchun temp_token kerak
    String? temp = await _session.getTempRegistrationToken();
    if (!mounted) return;

    if (temp == null || temp.isEmpty) {
      if (hasRefresh == null || hasRefresh.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('auth.session_not_found'))),
        );
        return;
      }
      try {
        temp = await const AuthApi().issueTempTokenFromRefresh(hasRefresh);
        await _session.saveTempRegistrationToken(temp);
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('customer.temp_token_label', {'msg': e.firstFieldMessage}))),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('customer.network_error_label', {'msg': '$e'}))),
        );
        return;
      }
    }

    if (!mounted) return;

    // Customer profilni olib step1 ga prefill qilamiz (overlap maydonlar: ism/familiya/sana).
    CustomerProfile? profile;
    if (hasRefresh != null && hasRefresh.isNotEmpty) {
      try {
        profile = await CustomerApi.instance.me();
      } catch (_) {
        // Profil yo'q yoki olib bo'lmadi — prefillsiz davom etamiz.
      }
    }
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DriverRegistrationStep1Page(
          phoneDisplay: widget.phoneDisplay,
          prefillLastName: profile?.lastName,
          prefillFirstName: profile?.firstName,
          prefillMiddleName: profile?.middleName,
          prefillBirthDate: profile?.birthDate,
        ),
      ),
    );
    if (mounted) {
      await _syncFromStore();
      _bumpRefresh();
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
            // Tab'larni bumpRefresh orqali to'liq qayta yuklash.
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
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          CustomerHomeBody(
            phoneDisplay: widget.phoneDisplay,
            userId: _userId,
            hasRefreshSession: _hasRefresh,
            refreshTick: _refreshTick,
            onRefreshParent: _syncFromStore,
            onCreateOrder: () {
              _openOrderCreate();
            },
            onOpenOrders: _openOrdersTab,
          ),
          CustomerOrdersBody(
            key: ValueKey<int>(_ordersKey),
            initialTab: _ordersInitialTab,
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
                MaterialPageRoute<void>(builder: (_) => const wallet_page.CustomerWalletTopupPage()),
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
            onBecomeDriver: _openDriverRegistration,
            onOpenRegistration: () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => CustomerPhysicalRegistrationPage(phoneDisplay: widget.phoneDisplay),
                ),
              );
              if (ok == true) {
                await _syncFromStore();
                _bumpRefresh();
              }
            },
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

class CustomerHomeBody extends StatefulWidget {
  const CustomerHomeBody({
    required this.phoneDisplay,
    required this.userId,
    required this.hasRefreshSession,
    required this.refreshTick,
    required this.onRefreshParent,
    required this.onCreateOrder,
    required this.onOpenOrders,
  });

  final String phoneDisplay;
  final int? userId;
  final bool hasRefreshSession;
  final int refreshTick;
  final Future<void> Function() onRefreshParent;
  final VoidCallback onCreateOrder;

  /// Joriy/Arxiv ko'rsatkich kartasini bosganda chaqiriladi.
  /// `initialTab`: 0=Joriy, 1=Arxiv.
  final void Function(int initialTab) onOpenOrders;

  @override
  State<CustomerHomeBody> createState() => CustomerHomeBodyState();
}

class CustomerHomeBodyState extends State<CustomerHomeBody> {
  int _currentCount = 0;
  int _archiveCount = 0;
  String? _balanceStr;

  /// Bosh sahifadagi to'q kartada ko'rsatiladigan buyurtma: yo'ldagisi
  /// birinchi o'rinda, bo'lmasa ro'yxatdagi eng birinchisi.
  CustomerOrder? _activeOrder;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.hasRefreshSession) _load();
  }

  @override
  void didUpdateWidget(covariant CustomerHomeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged = oldWidget.hasRefreshSession != widget.hasRefreshSession;
    final tickChanged = oldWidget.refreshTick != widget.refreshTick;
    if (widget.hasRefreshSession && (sessionChanged || tickChanged)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.hasRefreshSession) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cur = await CustomerApi.instance.currentOrders();
      final arch = await CustomerApi.instance.archiveOrders();
      final w = await CustomerApi.instance.wallet();
      if (!mounted) return;
      setState(() {
        _currentCount = cur.length;
        _archiveCount = arch.length;
        _balanceStr = w.balance;
        _activeOrder = _pickActive(cur);
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
        _error = '$e';
      });
    }
  }

  /// Statusdan taxminiy progress. Buyurtma bosqichlari 1..10 bo'ylab oshadi,
  /// shuning uchun foydalanuvchi yukning qay darajada yetganini ko'radi.
  static double _progressFor(int? status) {
    switch (status) {
      case 1:
        return 0.05;
      case 2:
        return 0.12;
      case 3:
        return 0.22;
      case 4:
        return 0.35;
      case 5:
        return 0.48;
      case 6:
        return 0.62;
      case 7:
        return 0.80;
      case 8:
        return 0.90;
      case 9:
        return 0.97;
      case 10:
        return 1.0;
      default:
        return 0.0;
    }
  }

  /// Manzilning birinchi bo'lagi — to'q kartada butun manzil sig'maydi.
  static String _shortAddress(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '—';
    final head = raw.split(',').first.trim();
    return head.isEmpty ? raw : head;
  }

  /// Yo'lda ketayotgan buyurtma (status 3..8) ustuvor — foydalanuvchi uchun
  /// eng muhim ma'lumot o'sha.
  static CustomerOrder? _pickActive(List<CustomerOrder> orders) {
    if (orders.isEmpty) return null;
    for (final o in orders) {
      final s = o.status ?? 0;
      if (s >= 3 && s <= 8) return o;
    }
    return orders.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final active = _activeOrder;

    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefreshParent();
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          if (_error != null) ...[
            AlixBanner(
              message: _error!,
              icon: Icons.error_outline_rounded,
              action: TextButton(
                onPressed: _load,
                child: Text(I18n.t('common.retry')),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (!widget.hasRefreshSession) ...[
            AlixBanner(
              message: I18n.t('customer.unverified_warn'),
              tone: AlixTone.warning,
            ),
            const SizedBox(height: 14),
          ],
          Text(
            I18n.t('customer.welcome'),
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(I18n.t('customer.home_title'), style: theme.textTheme.headlineMedium),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          const SizedBox(height: 22),
          AlixSectionTitle(I18n.t('customer.active_order')),
          if (active != null)
            AlixTrackingCard(
              trackingLabel:
                  '${I18n.t('order.tracking')} · ${active.orderNumber ?? '#${active.id}'}',
              route:
                  '${_shortAddress(active.pickupAddress)} → ${_shortAddress(active.deliveryAddress)}',
              statusLabel: _statusLabel(active.status),
              progress: _progressFor(active.status),
              onTap: () => widget.onOpenOrders(0),
            )
          else
            AlixEmptyState(
              icon: Icons.local_shipping_outlined,
              title: I18n.t('customer.no_active_order'),
              message: I18n.t('customer.no_active_order_hint'),
            ),
          const SizedBox(height: 24),
          AlixSectionTitle(I18n.t('customer.metrics')),
          Row(
            children: [
              Expanded(
                child: AlixStatTile(
                  label: I18n.t('customer.tile_current'),
                  value: '$_currentCount',
                  caption: I18n.t('customer.tile_current_subtitle'),
                  icon: Icons.inventory_2_outlined,
                  onTap: () => widget.onOpenOrders(0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AlixStatTile(
                  label: I18n.t('customer.tile_archive'),
                  value: '$_archiveCount',
                  caption: I18n.t('customer.tile_archive_subtitle'),
                  icon: Icons.history_rounded,
                  onTap: () => widget.onOpenOrders(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AlixStatTile(
            label: I18n.t('customer.tile_wallet_title'),
            value: _balanceStr != null
                ? '${_formatNumber(_balanceStr)} ${I18n.t('common.uzs')}'
                : '—',
            caption: I18n.t('customer.tile_wallet_subtitle'),
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 28),
          GradientButton(
            label: I18n.t('customer.new_order_btn'),
            icon: Icons.add_rounded,
            onPressed: widget.onCreateOrder,
            height: 56,
            borderRadius: 28,
          ),
          const SizedBox(height: 10),
          Text(
            I18n.t('customer.new_order_hint'),
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class CustomerOrdersBody extends StatefulWidget {
  const CustomerOrdersBody({
    super.key,
    required this.hasRefreshSession,
    required this.refreshTick,
    required this.onOpenDetail,
    this.initialTab = 0,
  });

  final bool hasRefreshSession;
  final int refreshTick;
  final void Function(CustomerOrder order) onOpenDetail;

  /// 0=Joriy, 1=Arxiv. Customer Home «Joriy/Arxiv» kartalaridan kelganda ishlatiladi.
  final int initialTab;

  @override
  State<CustomerOrdersBody> createState() => CustomerOrdersBodyState();
}

class CustomerOrdersBodyState extends State<CustomerOrdersBody> {
  List<CustomerOrder> _current = [];
  List<CustomerOrder> _archive = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerOrdersBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasRefreshSession != widget.hasRefreshSession ||
        oldWidget.refreshTick != widget.refreshTick) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.hasRefreshSession) {
      setState(() {
        _current = [];
        _archive = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await CustomerApi.instance.currentOrders();
      final a = await CustomerApi.instance.archiveOrders();
      if (!mounted) return;
      setState(() {
        _current = c;
        _archive = a;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.firstFieldMessage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!widget.hasRefreshSession) {
      return Center(child: Text(I18n.t('customer.orders_session_required')));
    }

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Column(
        children: [
          // Tab'lar sahifa fonida turadi — brendda ular alohida "panel" emas,
          // matn + orange indikator.
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: TabBar(
              onTap: (_) => _load(),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              tabs: [
                Tab(text: I18n.t('customer.tab_current')),
                Tab(text: I18n.t('customer.tab_archive')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const AlixListSkeleton()
                : TabBarView(
                    children: [
                      _orderList(_current, widget.onOpenDetail, _error),
                      _orderList(_archive, widget.onOpenDetail, _error),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _orderList(List<CustomerOrder> list, void Function(CustomerOrder) onTap, String? err) {
    if (err != null && list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          AlixBanner(
            message: err,
            icon: Icons.error_outline_rounded,
            action: TextButton(
              onPressed: _load,
              child: Text(I18n.t('common.retry')),
            ),
          ),
        ],
      );
    }
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 96),
        children: [
          AlixEmptyState(
            icon: Icons.inventory_2_outlined,
            title: I18n.t('customer.empty_list'),
            message: I18n.t('customer.no_active_order_hint'),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final o = list[i];
          return _CustomerOrderCard(order: o, onTap: () => onTap(o));
        },
      ),
    );
  }
}

// ─────────────────────── Buyurtma kartochkasi (driver listidagidek) ───────────────────────

/// Customer buyurtma kartochkasi — `driver_main_shell.dart` dagi `_DriverOrderCard`
/// bilan bir xil dizayn: sarlavha + status chip, katta narx, A→B manzillar,
/// vaqt oralig'i va chevron.
class _CustomerOrderCard extends StatelessWidget {
  const _CustomerOrderCard({required this.order, required this.onTap});

  final CustomerOrder order;
  final VoidCallback onTap;

  String? _orderEndIso(CustomerOrder o) {
    return o.completedAt ?? o.cancelledAt ?? o.deliveredAt;
  }

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
              if (order.scheduledPickupAt != null) ...[
                const SizedBox(width: 6),
                _ScheduledBadge(scheduledAtIso: order.scheduledPickupAt!),
                const SizedBox(width: 6),
              ],
              _OrderMiniStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatNumber(order.totalPrice)} ${order.currency ?? I18n.t('common.uzs')}',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _OrderRoute(
            pickup: order.pickupAddress ?? '—',
            delivery: order.deliveryAddress ?? '—',
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OrderTimeRangeRow(
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

/// "Rejali" yorlig'i — buyurtma `scheduled_pickup_at` bilan yaratilgan bo'lsa
/// orderlar ro'yxatida darrov ajralib turishi uchun. Sana qisqa formatda
/// ("DD.MM HH:mm") badge ichida ko'rinadi.
class _ScheduledBadge extends StatelessWidget {
  const _ScheduledBadge({required this.scheduledAtIso});

  final String scheduledAtIso;

  String _short(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dt = DateTime.tryParse(scheduledAtIso)?.toLocal();
    // Yonida status chipi turadi, shuning uchun bu yorliq neytral: ikkita
    // rangli chip yonma-yon bo'lsa, ko'z qaysi biri muhimligini ajratolmaydi.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppPalette.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            dt != null
                ? I18n.t('customer.scheduled_badge_full', {'value': _short(dt)})
                : I18n.t('customer.scheduled_badge_short'),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTimeRangeRow extends StatelessWidget {
  const _OrderTimeRangeRow({required this.start, required this.end});

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

/// Yo'nalish bloki: A va B nuqtalari va ular orasidagi bog'lovchi chiziq.
/// Chiziq yukning bir nuqtadan ikkinchisiga borishini ko'rsatadi — alohida
/// ikkita qatordan ko'ra tezroq o'qiladi.
class _OrderRoute extends StatelessWidget {
  const _OrderRoute({required this.pickup, required this.delivery});

  final String pickup;
  final String delivery;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _dot(color: cs.onSurface),
            Container(width: 2, height: 22, color: cs.outlineVariant),
            _dot(color: AppPalette.orange),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _address(context, pickup),
              const SizedBox(height: 18),
              _address(context, delivery),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot({required Color color}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _address(BuildContext context, String value) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1,
          ),
    );
  }
}

class _OrderMiniStatusChip extends StatelessWidget {
  const _OrderMiniStatusChip({required this.status});

  final int? status;

  @override
  Widget build(BuildContext context) {
    return AlixStatusChip(
      label: _statusLabel(status),
      tone: orderStatusTone(status),
    );
  }
}

class CustomerWalletBody extends StatefulWidget {
  const CustomerWalletBody({
    required this.hasRefreshSession,
    required this.refreshTick,
    required this.onTopUp,
  });

  final bool hasRefreshSession;
  final int refreshTick;
  final VoidCallback onTopUp;

  @override
  State<CustomerWalletBody> createState() => CustomerWalletBodyState();
}

class CustomerWalletBodyState extends State<CustomerWalletBody> {
  WalletSnapshot? _w;
  List<WalletTransaction> _tx = [];
  /// Korporativ xodim bo'lsa kompaniya hamyoni ma'lumoti shu yerda saqlanadi.
  /// Aks holda null.
  CustomerBillingInfo? _billing;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerWalletBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasRefreshSession != widget.hasRefreshSession ||
        oldWidget.refreshTick != widget.refreshTick) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.hasRefreshSession) {
      setState(() {
        _w = null;
        _tx = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 3 ta API parallel — billing-info ham (xodim bo'lsa kompaniya hamyoni).
      final results = await Future.wait([
        CustomerApi.instance.wallet(),
        CustomerApi.instance.walletTransactions(),
        CustomerApi.instance.billingInfo(),
      ]);
      if (!mounted) return;
      setState(() {
        _w = results[0] as WalletSnapshot;
        _tx = results[1] as List<WalletTransaction>;
        _billing = results[2] as CustomerBillingInfo?;
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
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final corporate = _billing?.isCorporateBilling ?? false;

    if (!widget.hasRefreshSession) {
      return Center(child: Text(I18n.t('customer.wallet_session_required')));
    }

    // Korporativ xodimda shaxsiy balans bo'lmaydi — buyurtmalar kompaniya
    // hamyonidan to'lanadi, shuning uchun tarix ham kompaniyaniki.
    final transactions = corporate ? _billing!.recentCompanyTx : _tx;

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
          _WalletBalanceCard(
            label: corporate
                ? I18n.t('customer.wallet.corporate_title')
                : I18n.t('customer.wallet.balance'),
            amount: corporate
                ? '${_formatNumber(_billing!.companyBalance)} ${_billing!.companyCurrency ?? I18n.t('common.uzs')}'
                : '${_formatNumber(_w?.balance)} ${_w?.currency ?? I18n.t('common.uzs')}',
            subtitle: corporate ? _billing!.companyName : null,
            badge: corporate ? I18n.t('customer.wallet.corporate_badge') : null,
            hint: corporate ? I18n.t('customer.wallet.corporate_hint') : null,
          ),
          const SizedBox(height: 14),
          if (corporate)
            AlixBanner(
              message: I18n.t('customer.wallet.admin_only_hint'),
              tone: AlixTone.neutral,
            )
          else
            GradientButton(
              label: I18n.t('customer.wallet.topup_btn'),
              icon: Icons.add_card_rounded,
              onPressed: widget.onTopUp,
            ),
          const SizedBox(height: 26),
          AlixSectionTitle(
            corporate
                ? I18n.t('customer.wallet.company_tx')
                : I18n.t('customer.wallet.tx'),
          ),
          if (transactions.isEmpty)
            AlixEmptyState(
              icon: Icons.receipt_long_outlined,
              title: I18n.t('customer.wallet.no_entries'),
            )
          else
            ...transactions.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WalletTxRow(tx: e),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hamyon balansi — brendning to'q plastinkasi. Ekrandagi eng muhim raqam
/// shu yerda, shuning uchun u boshqa hech narsa bilan raqobatlashmaydi.
class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({
    required this.label,
    required this.amount,
    this.subtitle,
    this.badge,
    this.hint,
  });

  final String label;
  final String amount;

  /// Korporativ hamyonda — kompaniya nomi.
  final String? subtitle;

  /// O'ng yuqoridagi kichik yorliq ("Korporativ").
  final String? badge;

  /// Kartaning pastidagi tushuntirish.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faded = Colors.white.withValues(alpha: 0.72);

    return AlixCard(
      tone: AlixSurfaceTone.ink,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(color: faded),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.orange,
                    borderRadius: BorderRadius.circular(AppPalette.radiusChip),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(color: faded),
            ),
          ],
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(color: faded),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tranzaksiya qatori — ko'rinish umumiy komponentda (`AlixTxRow`), bu
/// yerda faqat modeldan matn yasaladi.
class _WalletTxRow extends StatelessWidget {
  const _WalletTxRow({required this.tx});

  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (tx.orderId != null) I18n.t('wallet.tx.order_ref', {'number': tx.orderId}),
      if (_formatDateTime(tx.createdAt).isNotEmpty) _formatDateTime(tx.createdAt),
    ].join(' · ');

    return AlixTxRow(
      title: walletTxLabel(
        transactionType: tx.transactionType,
        rawDescription: tx.title,
        amount: double.tryParse(tx.amount ?? ''),
      ),
      meta: meta,
      amount: _formatNumber(tx.amount),
      negative: tx.amount?.startsWith('-') ?? false,
    );
  }
}

class CustomerProfileBody extends StatelessWidget {
  const CustomerProfileBody({
    required this.phoneDisplay,
    required this.userId,
    required this.hasRefreshSession,
    required this.onLogout,
    required this.onBecomeDriver,
    required this.onOpenRegistration,
  });

  final String phoneDisplay;
  final int? userId;
  final bool hasRefreshSession;
  final VoidCallback onLogout;
  final VoidCallback onBecomeDriver;
  final Future<void> Function() onOpenRegistration;

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
                  Text(I18n.t('customer.role_title'), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    phoneDisplay,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (userId != null)
                    Text('ID: $userId', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (!hasRefreshSession)
          AlixCard(
            tone: AlixSurfaceTone.cream,
            onTap: () => onOpenRegistration(),
            child: Row(
              children: [
                const Icon(Icons.app_registration_rounded, color: AppPalette.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        I18n.t('customer.physical_register_title'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        I18n.t('customer.physical_register_subtitle'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          )
        else
          AlixCard(
            tone: AlixSurfaceTone.cream,
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppPalette.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        I18n.t('customer.session_active'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        I18n.t('customer.account_verified'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        _RoleSegmented(
          current: 'customer',
          onSelect: (role) {
            if (role == 'driver') onBecomeDriver();
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
                    SnackBar(content: Text(I18n.t('customer.help_about_customer'))),
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

/// Customer / Haydovchi rejim toggle. Pill shaklidagi 2-segment switch.
class _RoleSegmented extends StatelessWidget {
  const _RoleSegmented({
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
            Text(
              I18n.t('customer.mode_label'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
                    child: _RoleSegment(
                      label: I18n.t('customer.role_customer_segment'),
                      icon: Icons.person_outline_rounded,
                      selected: current == 'customer',
                      onTap: () => onSelect('customer'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _RoleSegment(
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

class _RoleSegment extends StatelessWidget {
  const _RoleSegment({
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
