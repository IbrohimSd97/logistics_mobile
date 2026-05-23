import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/i18n/i18n.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/refresh_icon_button.dart';
import '../customer_api.dart';
import '../customer_models.dart';
import 'customer_wallet_topup_page.dart';

/// Walletdan to‘lash yoki kartadan to‘ldirish.
class CustomerPaymentSelectPage extends StatefulWidget {
  const CustomerPaymentSelectPage({super.key, required this.result});

  final CreateOrderResult result;

  @override
  State<CustomerPaymentSelectPage> createState() => _CustomerPaymentSelectPageState();
}

class _CustomerPaymentSelectPageState extends State<CustomerPaymentSelectPage>
    with I18nObserverMixin<CustomerPaymentSelectPage> {
  WalletSnapshot? _wallet;
  bool _loading = true;
  bool _paying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final w = await CustomerApi.instance.wallet();
      if (!mounted) return;
      setState(() {
        _wallet = w;
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
        _error = I18n.t('payment.network_error_label', {'msg': '$e'});
        _loading = false;
      });
    }
  }

  num? _balanceNum() => num.tryParse(_wallet?.balance ?? '');
  num? _totalNum() => num.tryParse(widget.result.totalPrice ?? '');

  bool get _balanceEnough {
    final b = _balanceNum();
    final t = _totalNum();
    if (b == null || t == null) return false;
    return b >= t;
  }

  Future<void> _payFromWallet() async {
    if (!mounted) return;
    setState(() => _paying = true);
    try {
      final r = await CustomerApi.instance.payOrderFromWallet(widget.result.orderId);
      if (!mounted) return;
      setState(() {
        _paying = false;
        _wallet = WalletSnapshot(balance: r.walletBalanceAfter, currency: r.currency);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('payment.success'))),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.firstFieldMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('payment.network_error_label', {'msg': '$e'}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final result = widget.result;
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('payment.title')),
        actions: [
          AppBarRefreshButton(loading: _loading, onPressed: _loading ? null : _loadWallet),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(I18n.t('payment.order_label', {'number': result.orderNumber ?? result.orderId}),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(I18n.t('payment.distance_label', {'value': result.distanceKm ?? '—', 'km': I18n.t('common.km')}),
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    I18n.t('payment.base_price_label', {'amount': _fmt(result.basePrice), 'currency': result.currency ?? I18n.t('common.uzs')}),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    I18n.t('payment.total_label', {'amount': _fmt(result.totalPrice), 'currency': result.currency ?? I18n.t('common.uzs')}),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(I18n.t('payment.balance')),
              subtitle: _loading
                  ? Text(I18n.t('common.loading'))
                  : _error != null
                      ? Text(_error!, style: TextStyle(color: cs.error))
                      : Text('${_fmt(_wallet?.balance)} ${_wallet?.currency ?? I18n.t('common.uzs')}'),
              trailing: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadWallet),
            ),
          ),
          if (!_loading && _error == null && !_balanceEnough)
            Card(
              color: cs.errorContainer,
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
                title: Text(I18n.t('payment.insufficient'),
                    style: TextStyle(color: cs.onErrorContainer)),
                subtitle: Text(
                  (_wallet?.isCorporate ?? false)
                      ? I18n.t('payment.insufficient_corporate')
                      : I18n.t('payment.insufficient_personal'),
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
            ),
          const SizedBox(height: 8),
          GradientButton(
            label: _paying ? I18n.t('payment.paying') : I18n.t('payment.pay_btn'),
            icon: Icons.account_balance_wallet_rounded,
            loading: _paying,
            onPressed: (_loading || _paying || !_balanceEnough) ? null : _payFromWallet,
          ),
          const SizedBox(height: 8),
          // Korporativ xodimda kartadan to'ldirish bo'lmaydi — faqat admin to'ldiradi.
          if (!(_wallet?.isCorporate ?? false))
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const CustomerWalletTopupPage()),
                ).then((_) => _loadWallet());
              },
              icon: const Icon(Icons.add_card_rounded),
              label: Text(I18n.t('payment.topup_card')),
            ),
        ],
      ),
    );
  }
}

String _fmt(String? raw) {
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
