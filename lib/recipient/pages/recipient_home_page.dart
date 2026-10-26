import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_palette.dart';
import '../recipient_api.dart';
import 'recipient_order_page.dart';

/// "Menga kelayotgan yuklar".
///
/// Ikki holatda ochiladi:
///   • ro'yxatdan o'tmagan qabul qiluvchi (faqat SMS kod bilan kirgan) —
///     ilovaning asosiy ekrani: chiqish va "Ro'yxatdan o'tish" tugmasi bilan;
///   • ro'yxatdan o'tgan mijoz — bosh sahifadagi "Sizga yuk kelyapti" kartasidan.
class RecipientHomePage extends StatefulWidget {
  const RecipientHomePage({super.key, this.onLogout, this.onRegister});

  /// Faqat qabul qiluvchi rejimida (asosiy ekran) beriladi.
  final VoidCallback? onLogout;
  final VoidCallback? onRegister;

  @override
  State<RecipientHomePage> createState() => _RecipientHomePageState();
}

class _RecipientHomePageState extends State<RecipientHomePage> {
  List<RecipientOrder>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await RecipientApi.instance.orders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.firstFieldMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _open(RecipientOrder o) async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => RecipientOrderPage(order: o)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('recipient.title')),
        actions: [
          if (widget.onLogout != null)
            IconButton(icon: const Icon(Icons.logout_rounded), tooltip: I18n.t('auth.logout'), onPressed: widget.onLogout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_error != null) AlixBanner(message: _error!, tone: AlixTone.danger),
            if (orders == null && _error == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            if (orders != null && orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text(I18n.t('recipient.empty'))),
              ),
            for (final o in orders ?? const <RecipientOrder>[]) ...[
              _OrderTile(order: o, onTap: () => _open(o)),
              const SizedBox(height: 10),
            ],
            if (widget.onRegister != null) ...[
              const SizedBox(height: 12),
              AlixCard(
                tone: AlixSurfaceTone.cream,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(I18n.t('recipient.register_title'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(I18n.t('recipient.register_sub')),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: widget.onRegister, child: Text(I18n.t('recipient.register_btn'))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});

  final RecipientOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final highlight = order.canFinish;
    return Material(
      color: highlight ? AppPalette.orange.withValues(alpha: 0.10) : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                order.isActive ? Icons.local_shipping_rounded : Icons.inventory_2_outlined,
                color: order.isActive ? AppPalette.orange : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(I18n.t('recipient.order_title', {'number': order.orderNumber}), style: t.titleSmall),
                    const SizedBox(height: 2),
                    Text(I18n.t('recipient.status.${order.status}'), style: t.bodyMedium),
                    const SizedBox(height: 2),
                    Text(order.deliveryAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mijoz bosh sahifasidagi karta: shu raqamga faol yuk yuborilgan bo'lsa ko'rinadi.
class IncomingCargoBanner extends StatefulWidget {
  const IncomingCargoBanner({super.key, required this.refreshTick});

  /// Ota sahifa yangilanganda qayta so'rash uchun.
  final int refreshTick;

  @override
  State<IncomingCargoBanner> createState() => _IncomingCargoBannerState();
}

class _IncomingCargoBannerState extends State<IncomingCargoBanner> {
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant IncomingCargoBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  Future<void> _load() async {
    try {
      final orders = await RecipientApi.instance.orders();
      if (!mounted) return;
      setState(() => _active = orders.where((o) => o.isActive).length);
    } catch (_) {
      // Ixtiyoriy karta — xato bo'lsa shunchaki ko'rsatilmaydi.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_active == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppPalette.orange,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const RecipientHomePage()));
            if (mounted) await _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(I18n.t('recipient.banner_title'),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white)),
                      Text(I18n.t('recipient.banner_sub', {'n': '$_active'}),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
