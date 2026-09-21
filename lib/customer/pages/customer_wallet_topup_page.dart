import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/gradient_button.dart';
import '../customer_api.dart';
import '../customer_models.dart';
import 'customer_payment_webview_page.dart';

/// Hamyonni karta orqali to'ldirish.
///
/// MUHIM: bu sahifa karta raqami, muddati yoki CVV ni SO'RAMAYDI. Mijoz
/// faqat summani kiritadi, qolgani Kapitalbank to'lov sahifasida bo'ladi
/// (WebView). Shu sababli ilova ham, bizning server ham karta ma'lumotini
/// ko'rmaydi va PCI DSS talabiga tushmaydi.
class CustomerWalletTopupPage extends StatefulWidget {
  const CustomerWalletTopupPage({super.key});

  @override
  State<CustomerWalletTopupPage> createState() => _CustomerWalletTopupPageState();
}

class _CustomerWalletTopupPageState extends State<CustomerWalletTopupPage>
    with I18nObserverMixin<CustomerWalletTopupPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();

  bool _busy = false;
  String? _error;

  List<CardTopUpStatus> _history = const [];
  bool _historyLoading = true;

  /// Tez tanlash uchun tayyor summalar.
  static const _presets = <int>[50000, 100000, 200000, 500000];

  /// Webhook bank sahifasi yopilgandan keyin bir necha soniya kechikishi
  /// mumkin — shuncha marta qayta so'raymiz, keyin "tekshirilmoqda" deymiz.
  static const _statusRetries = 4;
  static const _statusRetryDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() => _historyLoading = true);
    List<CardTopUpStatus> items = const [];
    try {
      items = await CustomerApi.instance.topUpHistory();
    } catch (_) {
      // Tarix ikkinchi darajali — xatoni ko'rsatmaymiz, ro'yxat bo'sh qoladi.
    }
    if (!mounted) return;
    setState(() {
      _history = items;
      _historyLoading = false;
    });
  }

  Future<void> _start() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.parse(_amount.text.trim());

    setState(() {
      _busy = true;
      _error = null;
    });

    CardTopUpSession session;
    try {
      session = await CustomerApi.instance.topUpInit(amount);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = I18n.t('payment.network_error_label').replaceAll('{msg}', '$e');
      });
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerPaymentWebviewPage(
          paymentUrl: session.paymentLink,
          redirectUrl: session.redirectUrl,
        ),
      ),
    );

    // WebView natijasiga ISHONMAYMIZ: haqiqiy holat faqat serverda, chunki
    // pul imzolangan webhook asosida yoziladi. Shuning uchun har holda so'raymiz.
    await _checkResult(session.operationId);
  }

  Future<void> _checkResult(String operationId) async {
    if (!mounted) return;
    setState(() => _busy = true);

    CardTopUpStatus? status;
    for (var attempt = 0; attempt < _statusRetries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_statusRetryDelay);
        if (!mounted) return;
      }

      try {
        status = await CustomerApi.instance.topUpStatus(operationId);
      } catch (_) {
        // Holat aniqlanmadi — keyingi urinishda yana so'raymiz.
        continue;
      }

      // Yakuniy holatlar: ortiq kutishning ma'nosi yo'q.
      if (status.credited || status.isExpired) break;
    }

    if (!mounted) return;
    setState(() => _busy = false);

    unawaited(_loadHistory());

    if (status != null && status.credited) {
      _amount.clear();
      _snack(I18n.t('payment.topup_credited'), success: true);
      // Chaqiruvchi sahifalar natijani o'qimaydi (MaterialPageRoute<void>),
      // shuning uchun qiymatsiz yopamiz.
      Navigator.of(context).pop();
      return;
    }

    if (status != null && status.isExpired) {
      _snack(I18n.t('payment.topup_expired'));
      return;
    }

    // To'langan, lekin hali yozilmagan yoki noma'lum — bank tasdig'i biroz
    // kechikishi normal holat.
    _snack(I18n.t('payment.topup_pending'));
  }

  void _snack(String text, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: success ? Colors.green.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(I18n.t('payment.topup_title'))),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              I18n.t('payment.topup_intro'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: InputDecoration(
                  labelText: I18n.t('payment.amount_field'),
                  hintText: I18n.t('payment.amount_hint'),
                  suffixText: I18n.t('common.uzs'),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  final n = int.tryParse(s);
                  if (n == null || n < 1000) return I18n.t('payment.amount_min_1000');
                  if (n > 100000000) return I18n.t('payment.amount_too_large');
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets
                  .map(
                    (v) => ActionChip(
                      label: Text(_format(v)),
                      onPressed: () {
                        _amount.text = '$v';
                        setState(() {});
                      },
                    ),
                  )
                  .toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AlixBanner(message: _error!, icon: Icons.error_outline_rounded),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: I18n.t('payment.topup_btn'),
              icon: Icons.credit_card_rounded,
              loading: _busy,
              onPressed: _busy ? null : _start,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    I18n.t('payment.topup_secure_note'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            AlixSectionTitle(I18n.t('payment.topup_history_title')),
            if (_historyLoading)
              const LinearProgressIndicator(minHeight: 3)
            else if (_history.isEmpty)
              AlixEmptyState(
                icon: Icons.receipt_long_outlined,
                title: I18n.t('payment.topup_history_empty'),
              )
            else
              ..._history.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TopUpHistoryRow(item: e),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _format(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// To'ldirish tarixining bitta qatori.
///
/// Bank "PAID" desa ham pul hamyonga bir necha soniya keyin yozilishi mumkin
/// — shuning uchun holat va `credited` alohida ko'rsatiladi, foydalanuvchi
/// "to'lovim qayerda?" deb o'ylab qolmaydi.
class _TopUpHistoryRow extends StatelessWidget {
  const _TopUpHistoryRow({required this.item});

  final CardTopUpStatus item;

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${p2(dt.day)}.${p2(dt.month)}.${dt.year} ${p2(dt.hour)}:${p2(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (label, tone) = item.isPaid
        ? (I18n.t('payment.topup_status_paid'), AlixTone.success)
        : item.isExpired
            ? (I18n.t('payment.topup_status_expired'), AlixTone.danger)
            : (I18n.t('payment.topup_status_pending'), AlixTone.warning);

    final meta = [
      if (_formatDate(item.createdAt).isNotEmpty) _formatDate(item.createdAt),
      if ((item.maskedPan ?? '').isNotEmpty) item.maskedPan!,
      // To'landi, lekin hamyonga hali yozilmadi.
      if (item.isPaid && !item.credited) I18n.t('payment.topup_not_credited_yet'),
    ].join(' · ');

    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppPalette.radiusChip),
            ),
            child: const Icon(Icons.credit_card_rounded, size: 18, color: AppPalette.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.amount?.toStringAsFixed(0) ?? '—'} ${item.currency ?? I18n.t('common.uzs')}',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AlixStatusChip(label: label, tone: tone),
        ],
      ),
    );
  }
}
