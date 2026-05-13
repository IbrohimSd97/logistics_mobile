import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../core/api/auth_api.dart';
import '../core/session/session_store.dart';
import '../core/theme/theme_controller.dart';
import '../customer/customer_api.dart';
import '../customer/customer_models.dart';
import '../customer/pages/customer_order_create_page.dart';
import '../customer/pages/customer_order_detail_page.dart';
import '../customer/pages/customer_physical_registration_page.dart';
import '../customer/pages/customer_tariff_list_page.dart';
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

String _statusLabel(int? s) {
  switch (s) {
    case 1:
      return 'Yangi';
    case 2:
      return 'Qabul qilindi';
    case 3:
      return 'Yo‘lda';
    case 4:
      return 'Yetkazildi';
    case 5:
      return 'Bekor qilingan';
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

class _CustomerMainShellState extends State<CustomerMainShell> {
  int _index = 0;
  static const _titles = ['Bosh sahifa', 'Buyurtmalar', 'Hamyon', 'Profil'];

  bool _hasRefresh = false;
  int? _userId;
  int _refreshTick = 0;

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
          title: const Text('Ro‘yxatdan o‘tish kerak'),
          content: const Text(
            'Yangi buyurtma berish uchun avval jismoniy ro‘yxatdan o‘ting va hisobingiz tasdiqlansin. '
            'OTP orqali kirganingizdan keyin server verifikatsiyasini kuting.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keyinroq')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ro‘yxatdan o‘tish')),
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
      const SnackBar(content: Text('Sessiya topilmadi. Iltimos, qayta kiring.')),
    );
  }

  Future<void> _logout() async {
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
          case 2:
            target = DriverMainShell(
              phoneDisplay: widget.phoneDisplay,
              userId: _userId ?? 0,
              userType: 'driver',
            );
            break;
          case 3:
            target = DriverRejectedPage(
              phoneDisplay: widget.phoneDisplay,
              userId: _userId ?? 0,
              status: status,
            );
            break;
          case 4:
            target = DriverFailedPage(phoneDisplay: widget.phoneDisplay);
            break;
          case 1:
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
          const SnackBar(content: Text('Sessiya topilmadi. Iltimos, qayta kiring.')),
        );
        return;
      }
      try {
        temp = await const AuthApi().issueTempTokenFromRefresh(hasRefresh);
        await _session.saveTempRegistrationToken(temp);
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Temp token: ${e.firstFieldMessage}')),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarmoq xatosi: $e')),
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
            tooltip: 'Bildirishnomalar',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bildirishnomalar tez orada qo‘shiladi.')),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Chiqish',
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
            onTariffs: () {
              if (!_hasRefresh) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tariflar uchun sessiya kerak.')),
                );
                return;
              }
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const CustomerTariffListPage()),
              );
            },
          ),
          CustomerOrdersBody(
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

class CustomerHomeBody extends StatefulWidget {
  const CustomerHomeBody({
    required this.phoneDisplay,
    required this.userId,
    required this.hasRefreshSession,
    required this.refreshTick,
    required this.onRefreshParent,
    required this.onCreateOrder,
    required this.onTariffs,
  });

  final String phoneDisplay;
  final int? userId;
  final bool hasRefreshSession;
  final int refreshTick;
  final Future<void> Function() onRefreshParent;
  final VoidCallback onCreateOrder;
  final VoidCallback onTariffs;

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
                              child: const Text('Qayta urinish'),
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
                        'Hisobingiz tasdiqlanmaguncha «Yangi buyurtma» ochilmaydi. «Yangi buyurtma» yoki «Profil» orqali jismoniy ro‘yxatdan o‘ting.',
                        style: TextStyle(color: cs.onErrorContainer, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!widget.hasRefreshSession) const SizedBox(height: 12),
          Text('Xush kelibsiz', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Telefon: ${widget.phoneDisplay}', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          if (widget.userId != null)
            Text('User ID: ${widget.userId}', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          if (_loading) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          const SizedBox(height: 16),
          Text('Ko‘rsatkichlar', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Joriy',
                  value: '$_currentCount',
                  subtitle: 'Faol buyurtmalar',
                  cs: cs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  title: 'Arxiv',
                  value: '$_archiveCount',
                  subtitle: 'Tugagan / bekor',
                  cs: cs,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatCard(
            title: 'Hamyon',
            value: _balanceStr != null ? '${_formatNumber(_balanceStr)} so‘m' : '—',
            subtitle: 'Joriy balans',
            cs: cs,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: widget.onCreateOrder,
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('Yangi buyurtma'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manzil, tarif, yuk (kg), izoh kiriting.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('Tez kirish', style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.price_change_outlined, color: cs.primary),
                  title: const Text('Tariflar'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onTariffs,
                ),
              ],
            ),
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
  });

  final String title;
  final String value;
  final String subtitle;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
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
      ),
    );
  }
}

class CustomerOrdersBody extends StatefulWidget {
  const CustomerOrdersBody({
    required this.hasRefreshSession,
    required this.refreshTick,
    required this.onOpenDetail,
  });

  final bool hasRefreshSession;
  final int refreshTick;
  final void Function(CustomerOrder order) onOpenDetail;

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
      return const Center(child: Text('Buyurtmalar uchun sessiya kerak.'));
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: cs.surfaceContainerHighest,
            child: TabBar(
              onTap: (_) => _load(),
              tabs: const [Tab(text: 'Joriy'), Tab(text: 'Arxiv')],
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
          TextButton(onPressed: _load, child: const Text('Qayta urinish')),
        ],
      );
    }
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: const [
          Icon(Icons.inventory_2_outlined, size: 56),
          SizedBox(height: 12),
          Text('Ro‘yxat bo‘sh', textAlign: TextAlign.center),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final o = list[i];
          return Card(
            child: ListTile(
              title: Text(o.orderNumber ?? 'Buyurtma #${o.id}'),
              subtitle: Text('${_statusLabel(o.status)} · ${_formatNumber(o.totalPrice)} ${o.currency ?? 'UZS'}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onTap(o),
            ),
          );
        },
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
      final w = await CustomerApi.instance.wallet();
      final t = await CustomerApi.instance.walletTransactions();
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
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!widget.hasRefreshSession) {
      return const Center(child: Text('Hamyon uchun sessiya kerak.'));
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
                trailing: FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
              ),
            ),
          if (_error != null) const SizedBox(height: 12),
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balans', style: theme.textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatNumber(_w?.balance)} ${_w?.currency ?? 'UZS'}',
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
            onPressed: widget.onTopUp,
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Hamyonni to‘ldirish'),
          ),
          const SizedBox(height: 20),
          Text('Tranzaksiyalar', style: theme.textTheme.titleSmall),
          if (_tx.isEmpty)
            const Card(child: ListTile(title: Text('Hozircha yozuvlar yo‘q')))
          else
            ..._tx.map(
              (e) => Card(
                child: ListTile(
                  title: Text(e.title ?? '—'),
                  subtitle: Text(e.createdAt ?? ''),
                  trailing: Text(_formatNumber(e.amount)),
                ),
              ),
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
                  Text('Buyurtmachi', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                'Jismoniy ro‘yxatdan o‘tish',
                style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Shaxsiy ma’lumotlar, hujjat rasmlari, offerta.',
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
              title: const Text('Sessiya faol'),
              subtitle: Text('Hisob tasdiqlangan', style: TextStyle(color: cs.onSurfaceVariant)),
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
                    const SnackBar(content: Text('ALIX Logistics — buyurtmachi.')),
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
              'Rejim',
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
                      label: 'Customer',
                      icon: Icons.person_outline_rounded,
                      selected: current == 'customer',
                      onTap: () => onSelect('customer'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _RoleSegment(
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
