import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';
import '../driver_api.dart';
import '../driver_models.dart';

/// "Pul yechib olish": hamyondagi daromadni o'z kompaniyasining (YATT/yuridik
/// shaxs) bank hisob raqamiga yechish. `true` — so'rov yuborildi.
Future<bool> showDriverWithdrawSheet(BuildContext context) async {
  DriverWithdrawInfo info;
  try {
    info = await DriverApi.instance.withdrawInfo();
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.firstFieldMessage)));
    return false;
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('common.network_unreachable'))));
    return false;
  }
  if (!context.mounted) return false;

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _WithdrawSheet(info: info),
  );
  return ok == true;
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.info});

  final DriverWithdrawInfo info;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.info.available.floor().toString());
  bool _sending = false;
  String? _error;

  String _fmt(double v) => v.floor().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');

  Future<void> _send() async {
    final amount = double.tryParse(_amount.text.replaceAll(' ', '')) ?? 0;
    if (amount < widget.info.minAmount || amount > widget.info.available) {
      setState(() => _error = I18n.t('driver.withdraw_amount_range', {
            'min': _fmt(widget.info.minAmount),
            'max': _fmt(widget.info.available),
          }));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final msg = await DriverApi.instance.withdraw(amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isNotEmpty ? msg : I18n.t('driver.withdraw_sent'))),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.firstFieldMessage);
    } catch (_) {
      if (mounted) setState(() => _error = I18n.t('common.network_unreachable'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(I18n.t('driver.withdraw_title'), style: t.titleLarge),
          const SizedBox(height: 14),
          if (!info.canWithdraw) ...[
            AlixBanner(message: info.reason ?? I18n.t('driver.withdraw_not_ready'), tone: AlixTone.warning),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(I18n.t('common.close'))),
          ] else ...[
            AlixCard(
              tone: AlixSurfaceTone.cream,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(I18n.t('driver.withdraw_to'), style: t.labelMedium),
                  const SizedBox(height: 4),
                  Text(info.companyName ?? '', style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text('${info.bankAccount ?? ''} · MFO ${info.bankMfo ?? ''}', style: t.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: I18n.t('driver.withdraw_amount'),
                helperText: I18n.t('driver.withdraw_available', {'sum': _fmt(info.available)}),
                errorText: _error,
                suffixText: I18n.t('common.uzs'),
              ),
            ),
            const SizedBox(height: 8),
            Text(I18n.t('driver.withdraw_note'), style: t.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.account_balance_rounded),
              label: Text(I18n.t('driver.withdraw_submit')),
            ),
          ],
        ],
      ),
    );
  }
}
