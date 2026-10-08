import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_palette.dart';
import '../customer_api.dart';
import '../customer_models.dart';

/// Mijozga ko'rsatiladigan chek — faqat Sotuv cheki (qaytarish emas).
///
/// Buyurtma yakunlanganda backend uchta chek chiqaradi (Avans → Sotuv →
/// Kredit), lekin Avans va Kredit buxgalteriya uchun. Backend ham faqat
/// Sotuvni qaytaradi; bu filtr eski backend bilan ham to'g'ri ishlashi uchun.
bool _isCustomerReceipt(OrderFiscalReceipt r) => r.receiptType == 0 && !r.isRefund;

/// Yakunlangan buyurtmaning sotuv cheki (OFD). Chek bosilganda QR kod
/// ochiladi — mijoz uni soliq ilovasi bilan skanerlashi yoki soliq saytida
/// ko'rishi mumkin.
///
/// Cheklar backendda buyurtma yakunlangach navbat orqali yuboriladi, shuning
/// uchun ro'yxat bo'sh yoki `pending` bo'lsa bir necha marta qayta so'raladi.
class OrderFiscalReceiptsSection extends StatefulWidget {
  const OrderFiscalReceiptsSection({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderFiscalReceiptsSection> createState() => _OrderFiscalReceiptsSectionState();
}

class _OrderFiscalReceiptsSectionState extends State<OrderFiscalReceiptsSection>
    with I18nObserverMixin<OrderFiscalReceiptsSection> {
  static const _pollInterval = Duration(seconds: 5);
  static const _maxPolls = 24; // ~2 daqiqa

  List<OrderFiscalReceipt>? _items;
  String? _error;
  bool _loading = false;
  int _polls = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _waiting {
    final items = _items;
    if (items == null) return false;
    return items.isEmpty || items.any((r) => r.isPending);
  }

  Future<void> _load({bool resetPolls = false}) async {
    _timer?.cancel();
    if (resetPolls) _polls = 0;
    setState(() => _loading = true);
    try {
      final items = await CustomerApi.instance.orderFiscalReceipts(widget.orderId);
      if (!mounted) return;
      setState(() {
        _items = items.where(_isCustomerReceipt).toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.firstFieldMessage : '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    if (_error == null && _waiting && _polls < _maxPolls) {
      _polls++;
      _timer = Timer(_pollInterval, _load);
    }
  }

  String _typeLabel(OrderFiscalReceipt r) {
    final base = switch (r.receiptType) {
      1 => I18n.t('fiscal.type.advance'),
      2 => I18n.t('fiscal.type.credit'),
      _ => I18n.t('fiscal.type.sale'),
    };
    return r.isRefund ? '$base · ${I18n.t('fiscal.refund')}' : base;
  }

  (String, AlixTone) _statusChip(OrderFiscalReceipt r) {
    if (r.isAccepted) return (I18n.t('fiscal.status.accepted'), AlixTone.success);
    if (r.isPending) return (I18n.t('fiscal.status.pending'), AlixTone.progress);
    return (I18n.t('fiscal.status.error'), AlixTone.danger);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _items;

    Widget body;
    if (items == null && _error == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    } else if (_error != null && (items == null || items.isEmpty)) {
      body = _hint(context, _error!, isError: true);
    } else if (items!.isEmpty) {
      body = _hint(
        context,
        _waiting && _polls < _maxPolls ? I18n.t('fiscal.preparing') : I18n.t('fiscal.not_ready'),
      );
    } else {
      body = Column(
        children: [
          for (final r in items) ...[
            _ReceiptRow(
              title: _typeLabel(r),
              subtitle: [
                if (r.amount != null) '${_formatMoney(r.amount!)} ${I18n.t('common.uzs')}',
                if (r.receiptSeq != null) '№ ${r.receiptSeq}',
              ].join(' · '),
              chip: _statusChip(r),
              onTap: r.hasQr ? () => _showQr(context, r) : null,
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlixSectionTitle(
          I18n.t('fiscal.section_title'),
          trailing: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  tooltip: I18n.t('common.retry'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
                  onPressed: () => _load(resetPolls: true),
                ),
        ),
        body,
      ],
    );
  }

  Widget _hint(BuildContext context, String text, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
            color: isError ? cs.error : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: isError ? cs.error : cs.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQr(BuildContext context, OrderFiscalReceipt r) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _FiscalQrSheet(receipt: r, title: _typeLabel(r)),
    );
  }
}

/// Buyurtma yakunlangach sotuv chekini ekranga chiqaradi.
///
/// Chek OFD'ga navbat orqali yuboriladi, shuning uchun oyna chek tayyor
/// bo'lguncha kutadi va keyin QR kodni ko'rsatadi. Chek vaqtida chiqmasa,
/// mijozga buyurtma sahifasida ko'rinishini aytamiz — oynani yopsa bo'ladi.
Future<void> showOrderSaleReceiptSheet(BuildContext context, int orderId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SaleReceiptSheet(orderId: orderId),
  );
}

class _SaleReceiptSheet extends StatefulWidget {
  const _SaleReceiptSheet({required this.orderId});

  final int orderId;

  @override
  State<_SaleReceiptSheet> createState() => _SaleReceiptSheetState();
}

class _SaleReceiptSheetState extends State<_SaleReceiptSheet> {
  static const _pollInterval = Duration(seconds: 3);
  static const _maxPolls = 20; // ~1 daqiqa

  OrderFiscalReceipt? _receipt;
  bool _gaveUp = false;
  int _polls = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    OrderFiscalReceipt? sale;
    try {
      final items = await CustomerApi.instance.orderFiscalReceipts(widget.orderId);
      for (final r in items) {
        if (_isCustomerReceipt(r)) sale = r;
      }
    } catch (_) {
      // Tarmoq xatosi — keyingi urinishda yana so'raymiz.
    }
    if (!mounted) return;
    final ready = sale != null && sale.hasQr;
    final failed = sale != null && !sale.isPending && !sale.hasQr;
    setState(() {
      _receipt = ready ? sale : null;
      _gaveUp = !ready && (failed || _polls >= _maxPolls);
    });
    if (!ready && !_gaveUp) {
      _polls++;
      _timer = Timer(_pollInterval, _load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _receipt;
    if (r != null) {
      return _FiscalQrSheet(receipt: r, title: I18n.t('fiscal.type.sale'));
    }

    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 56, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              I18n.t('order.detail.order_finished_msg'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            if (_gaveUp)
              Text(
                I18n.t('fiscal.sale_later'),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
              )
            else ...[
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6)),
              const SizedBox(height: 14),
              Text(
                I18n.t('fiscal.sale_preparing'),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(I18n.t('common.close')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.title,
    required this.subtitle,
    required this.chip,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final (String, AlixTone) chip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlixCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            onTap != null ? Icons.qr_code_2_rounded : Icons.receipt_long_rounded,
            color: onTap != null ? cs.onSurface : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          AlixStatusChip(label: chip.$1, tone: chip.$2),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ],
      ),
    );
  }
}

class _FiscalQrSheet extends StatelessWidget {
  const _FiscalQrSheet({required this.receipt, required this.title});

  final OrderFiscalReceipt receipt;
  final String title;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(Uri.parse(receipt.qrCodeUrl!), mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text(I18n.t('fiscal.open_failed'))));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(I18n.t('fiscal.open_failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = receipt;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              I18n.t('fiscal.scan_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            // QR har doim oq fonda — tungi rejimda ham skanerlanishi uchun.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppPalette.radiusField),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: QrImageView(
                data: r.qrCodeUrl!,
                size: 220,
                backgroundColor: Colors.white,
                semanticsLabel: I18n.t('fiscal.qr_semantics'),
              ),
            ),
            const SizedBox(height: 16),
            _kv(context, I18n.t('fiscal.amount'),
                r.amount != null ? '${_formatMoney(r.amount!)} ${I18n.t('common.uzs')}' : null),
            _kv(context, I18n.t('fiscal.receipt_seq'), r.receiptSeq?.toString()),
            _kv(context, I18n.t('fiscal.terminal_id'), r.terminalId),
            _kv(context, I18n.t('fiscal.fiscal_sign'), r.fiscalSign),
            _kv(context, I18n.t('fiscal.issued_at'), r.issuedAt != null ? _fmtDate(r.issuedAt!) : null),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _open(context),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(I18n.t('fiscal.open_in_browser')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String? v) {
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(k, style: TextStyle(color: cs.onSurfaceVariant))),
          const SizedBox(width: 12),
          Flexible(
            child: SelectableText(v, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

String _formatMoney(num n) {
  final s = n.round().abs().toString();
  final buf = StringBuffer();
  for (int k = 0; k < s.length; k++) {
    if (k > 0 && (s.length - k) % 3 == 0) buf.write(' ');
    buf.write(s[k]);
  }
  return n < 0 ? '-$buf' : buf.toString();
}
