import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/i18n.dart';
import '../../core/widgets/gradient_button.dart';

class CustomerWalletTopupPage extends StatefulWidget {
  const CustomerWalletTopupPage({super.key});

  @override
  State<CustomerWalletTopupPage> createState() => _CustomerWalletTopupPageState();
}

class _CustomerWalletTopupPageState extends State<CustomerWalletTopupPage>
    with I18nObserverMixin<CustomerWalletTopupPage> {
  final _formKey = GlobalKey<FormState>();
  final _card = TextEditingController();
  final _exp = TextEditingController();
  final _cvc = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _card.dispose();
    _exp.dispose();
    _cvc.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool _luhnOk(String digits) {
    if (digits.length < 13 || digits.length > 19) return false;
    int sum = 0;
    bool alt = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int d = digits.codeUnitAt(i) - 0x30;
      if (d < 0 || d > 9) return false;
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('payment.topup_title')),
        actions: [
          IconButton(
            tooltip: I18n.t('common.refresh'),
            icon: const Icon(Icons.refresh_rounded),
            // Form sahifasi — reload formani tozalaydi.
            onPressed: () {
              _formKey.currentState?.reset();
              _card.clear();
              _exp.clear();
              _cvc.clear();
              _amount.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            I18n.t('payment.topup_intro'),
            style: const TextStyle(height: 1.35),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                TextFormField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: I18n.t('payment.amount_field'),
                    hintText: I18n.t('payment.amount_hint'),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    final n = int.tryParse(s);
                    if (n == null || n < 1000) return I18n.t('payment.amount_min_1000');
                    if (n > 100000000) return I18n.t('payment.amount_too_large');
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _card,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    _CardNumberFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: I18n.t('payment.card_number'),
                    hintText: I18n.t('payment.card_number_hint'),
                  ),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.length != 16) return I18n.t('payment.card_16_digits');
                    if (!_luhnOk(digits)) return I18n.t('payment.card_invalid');
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _exp,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          _ExpiryFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: I18n.t('payment.expiry_field'),
                          hintText: I18n.t('payment.expiry_hint'),
                        ),
                        validator: _validateExpiry,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cvc,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: I18n.t('payment.cvc_field'),
                          hintText: I18n.t('payment.cvc_hint'),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.length < 3 || s.length > 4) return I18n.t('payment.cvc_3_4_digits');
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: I18n.t('payment.continue_btn'),
            icon: Icons.payment_rounded,
            onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(I18n.t('payment.gateway_not_ready'))),
              );
            },
          ),
        ],
      ),
    );
  }

  String? _validateExpiry(String? v) {
    final s = (v ?? '').trim();
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(s);
    if (m == null) return I18n.t('payment.expiry_format');
    final mm = int.parse(m.group(1)!);
    final yy = int.parse(m.group(2)!);
    if (mm < 1 || mm > 12) return I18n.t('payment.expiry_month_range');
    final fullYear = 2000 + yy;
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(fullYear, mm + 1, 0);
    if (lastDayOfMonth.isBefore(DateTime(now.year, now.month, now.day))) {
      return I18n.t('payment.expiry_past');
    }
    if (fullYear > now.year + 20) return I18n.t('payment.expiry_year_invalid');
    return null;
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    String text;
    if (digits.length <= 2) {
      text = digits;
    } else {
      text = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
