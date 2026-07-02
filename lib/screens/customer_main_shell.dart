import 'package:flutter/material.dart';

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
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(I18n.t('auth.registration_required')),
          content: Text(I18n.t('auth.registration_required_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(I18n.t('auth.later'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(I18n.t('auth.register_now'))),
          ],
        ),
      );
      if (go == true && mounted) {
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
        title: Text(_titles[_index]),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefreshParent();
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (_error != null)
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _error!,
                            style: TextStyle(color: cs.onErrorContainer, height: 1.35),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.tonal(
                              onPressed: _load,
                              child: Text(I18n.t('common.retry')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null) const SizedBox(height: 12),
          if (!widget.hasRefreshSession)
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        I18n.t('customer.unverified_warn'),
                        style: TextStyle(color: cs.onErrorContainer, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!widget.hasRefreshSession) const SizedBox(height: 12),
          Text(I18n.t('customer.welcome'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(I18n.t('customer.your_phone', {'phone': widget.phoneDisplay}), style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          if (_loading) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          const SizedBox(height: 16),
          Text(I18n.t('customer.metrics'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: I18n.t('customer.tile_current'),
                  value: '$_currentCount',
                  subtitle: I18n.t('customer.tile_current_subtitle'),
                  cs: cs,
                  onTap: () => widget.onOpenOrders(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  title: I18n.t('customer.tile_archive'),
                  value: '$_archiveCount',
                  subtitle: I18n.t('customer.tile_archive_subtitle'),
                  cs: cs,
                  onTap: () => widget.onOpenOrders(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatCard(
            title: I18n.t('customer.tile_wallet_title'),
            value: _balanceStr != null ? '${_formatNumber(_balanceStr)} ${I18n.t('common.uzs')}' : '—',
            subtitle: I18n.t('customer.tile_wallet_subtitle'),
            cs: cs,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: widget.onCreateOrder,
            icon: const Icon(Icons.add_location_alt_rounded),
            label: Text(I18n.t('customer.new_order_btn')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            I18n.t('customer.new_order_hint'),
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.cs,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
    if (onTap == null) {
      return Card(elevation: 0, color: cs.surfaceContainerHighest, child: inner);
    }
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: inner),
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
          Material(
            color: cs.surfaceContainerHighest,
            child: TabBar(
              onTap: (_) => _load(),
              tabs: [
                Tab(text: I18n.t('customer.tab_current')),
                Tab(text: I18n.t('customer.tab_archive')),
              ],
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
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
        padding: const EdgeInsets.all(24),
        children: [
          Text(err),
          TextButton(onPressed: _load, child: Text(I18n.t('common.retry'))),
        ],
      );
    }
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const Icon(Icons.inventory_2_outlined, size: 56),
          const SizedBox(height: 12),
          Text(I18n.t('customer.empty_list'), textAlign: TextAlign.center),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                  if (order.scheduledPickupAt != null) ...[
                    const SizedBox(width: 6),
                    _ScheduledBadge(scheduledAtIso: order.scheduledPickupAt!),
                  ],
                  const SizedBox(width: 8),
                  _OrderMiniStatusChip(status: s),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatNumber(order.totalPrice)} ${order.currency ?? I18n.t('common.uzs')}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
              ),
              const SizedBox(height: 12),

              // A → B
              _OrderAbRow(
                isStart: true,
                label: 'A',
                address: order.pickupAddress ?? '—',
              ),
              const SizedBox(height: 6),
              _OrderAbRow(
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
        ),
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
            dt != null
                ? I18n.t('customer.scheduled_badge_full', {'value': _short(dt)})
                : I18n.t('customer.scheduled_badge_short'),
            style: TextStyle(
              color: cs.onPrimaryContainer,
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

class _OrderAbRow extends StatelessWidget {
  const _OrderAbRow({
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

class _OrderMiniStatusChip extends StatelessWidget {
  const _OrderMiniStatusChip({required this.status});

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
        _statusLabel(status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!widget.hasRefreshSession) {
      return Center(child: Text(I18n.t('customer.wallet_session_required')));
    }

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
          if (_error != null) const SizedBox(height: 12),
          // Korporativ xodim — kompaniya hamyoni asosiy karta, shaxsiy ostida.
          if (_billing != null && _billing!.isCorporateBilling) ...[
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business_rounded, size: 18, color: cs.onPrimaryContainer),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            I18n.t('customer.wallet.corporate_title'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.onPrimaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            I18n.t('customer.wallet.corporate_badge'),
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _billing!.companyName ?? '—',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_formatNumber(_billing!.companyBalance)} ${_billing!.companyCurrency ?? I18n.t('common.uzs')}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      I18n.t('customer.wallet.corporate_hint'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Korporativ xodimda shaxsiy hamyon ko'rsatilmaydi — xodimda
            // alohida balans bo'lmaydi, buyurtmalar faqat kompaniya hamyonidan.
            Card(
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        I18n.t('customer.wallet.admin_only_hint'),
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            // Oddiy mijoz — shaxsiy hamyon asosiy karta.
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(I18n.t('customer.wallet.balance'), style: theme.textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatNumber(_w?.balance)} ${_w?.currency ?? I18n.t('common.uzs')}',
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
          // Korporativ xodimga top-up tugmasi ko'rsatilmaydi —
          // kompaniya hamyonini faqat administrator to'ldira oladi.
          if (!(_billing?.isCorporateBilling ?? false))
            OutlinedButton.icon(
              onPressed: widget.onTopUp,
              icon: const Icon(Icons.add_card_rounded),
              label: Text(I18n.t('customer.wallet.topup_btn')),
            ),
          const SizedBox(height: 20),
          // Korporativ bo'lsa kompaniya tarixi, aks holda shaxsiy.
          Text(
            (_billing?.isCorporateBilling ?? false)
                ? I18n.t('customer.wallet.company_tx')
                : I18n.t('customer.wallet.tx'),
            style: theme.textTheme.titleSmall,
          ),
          if ((_billing?.isCorporateBilling ?? false) &&
              _billing!.recentCompanyTx.isNotEmpty) ...[
            ..._billing!.recentCompanyTx.map(
              (e) => Card(
                child: ListTile(
                  leading: Icon(Icons.business_center_outlined, color: cs.primary),
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
                    _formatNumber(e.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: (e.amount?.startsWith('-') ?? false)
                          ? Colors.redAccent
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ),
            ),
          ] else if (_tx.isEmpty)
            Card(child: ListTile(title: Text(I18n.t('customer.wallet.no_entries'))))
          else
            ..._tx.map(
              (e) {
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
                      _formatNumber(e.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isNeg ? Colors.redAccent : Colors.green.shade700,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
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
                  Text(I18n.t('customer.role_title'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(phoneDisplay, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  if (userId != null)
                    Text('ID: $userId', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (!hasRefreshSession)
          Card(
            color: cs.secondaryContainer,
            child: ListTile(
              leading: Icon(Icons.app_registration_rounded, color: cs.onSecondaryContainer),
              title: Text(
                I18n.t('customer.physical_register_title'),
                style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                I18n.t('customer.physical_register_subtitle'),
                style: TextStyle(color: cs.onSecondaryContainer.withValues(alpha: 0.9)),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: cs.onSecondaryContainer),
              onTap: () => onOpenRegistration(),
            ),
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(I18n.t('customer.session_active')),
              subtitle: Text(I18n.t('customer.account_verified'), style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ),
        const SizedBox(height: 12),
        _RoleSegmented(
          current: 'customer',
          onSelect: (role) {
            if (role == 'driver') onBecomeDriver();
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
                    SnackBar(content: Text(I18n.t('customer.help_about_customer'))),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
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
