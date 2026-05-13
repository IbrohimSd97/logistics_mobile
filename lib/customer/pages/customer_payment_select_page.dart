import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/widgets/gradient_button.dart';
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

class _CustomerPaymentSelectPageState extends State<CustomerPaymentSelectPage> {
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
        _error = 'Tarmoq xatosi: $e';
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('To‘lovni tasdiqlash'),
        content: Text(
          'Hamyondan ${_fmt(widget.result.totalPrice)} ${widget.result.currency ?? 'UZS'} '
          'yechib olinishini tasdiqlaysizmi?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Yo‘q')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ha, to‘lash')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _paying = true);
    try {
      final r = await CustomerApi.instance.payOrderFromWallet(widget.result.orderId);
      if (!mounted) return;
      setState(() {
        _paying = false;
        _wallet = WalletSnapshot(balance: r.walletBalanceAfter, currency: r.currency);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To‘lov muvaffaqiyatli. Buyurtma faollashtirildi.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.firstFieldMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tarmoq xatosi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final result = widget.result;
    return Scaffold(
      appBar: AppBar(title: const Text('To‘lov')),
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
                  Text('Buyurtma #${result.orderNumber ?? result.orderId}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Masofa: ${result.distanceKm ?? '—'} km',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    'Asosiy narx: ${_fmt(result.basePrice)} ${result.currency ?? 'UZS'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Jami: ${_fmt(result.totalPrice)} ${result.currency ?? 'UZS'}',
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
              title: const Text('Hamyon balansi'),
              subtitle: _loading
                  ? const Text('Yuklanmoqda…')
                  : _error != null
                      ? Text(_error!, style: TextStyle(color: cs.error))
                      : Text('${_fmt(_wallet?.balance)} ${_wallet?.currency ?? 'UZS'}'),
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
                title: Text('Balans yetarli emas',
                    style: TextStyle(color: cs.onErrorContainer)),
                subtitle: Text('Hamyondan to‘lash uchun avval to‘ldiring.',
                    style: TextStyle(color: cs.onErrorContainer)),
              ),
            ),
          const SizedBox(height: 8),
          GradientButton(
            label: _paying ? 'To‘lanmoqda…' : 'Hamyondan to‘lash',
            icon: Icons.account_balance_wallet_rounded,
            loading: _paying,
            onPressed: (_loading || _paying || !_balanceEnough) ? null : _payFromWallet,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const CustomerWalletTopupPage()),
              ).then((_) => _loadWallet());
            },
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Hamyonni to‘ldirish (karta)'),
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
