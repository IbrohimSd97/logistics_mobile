import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/gradient_button.dart';

class CustomerWalletTopupPage extends StatefulWidget {
  const CustomerWalletTopupPage({super.key});

  @override
  State<CustomerWalletTopupPage> createState() => _CustomerWalletTopupPageState();
}

class _CustomerWalletTopupPageState extends State<CustomerWalletTopupPage> {
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
      appBar: AppBar(title: const Text('Hamyonni to‘ldirish')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'VISA / MasterCard ma’lumotlarini kiriting. To‘lov xizmati keyingi versiyada ulanadi.',
            style: TextStyle(height: 1.35),
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
                  decoration: const InputDecoration(
                    labelText: 'Summa (so‘m) *',
                    hintText: '50000',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    final n = int.tryParse(s);
                    if (n == null || n < 1000) return 'Kamida 1 000 so‘m';
                    if (n > 100000000) return 'Juda katta summa';
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
                  decoration: const InputDecoration(
                    labelText: 'Karta raqami *',
                    hintText: '0000 0000 0000 0000',
                  ),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.length != 16) return '16 xonali karta raqami kiriting';
                    if (!_luhnOk(digits)) return 'Karta raqami noto‘g‘ri';
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
                        decoration: const InputDecoration(
                          labelText: 'Amal qilish (MM/YY) *',
                          hintText: '12/28',
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
                        decoration: const InputDecoration(
                          labelText: 'CVC *',
                          hintText: '123',
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.length < 3 || s.length > 4) return '3-4 raqam';
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
            label: 'Davom etish',
            icon: Icons.payment_rounded,
            onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('To‘lov xizmati hali ulangan emas.')),
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
    if (m == null) return 'MM/YY formatida kiriting';
    final mm = int.parse(m.group(1)!);
    final yy = int.parse(m.group(2)!);
    if (mm < 1 || mm > 12) return 'Oy 01..12 bo‘lsin';
    final fullYear = 2000 + yy;
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(fullYear, mm + 1, 0);
    if (lastDayOfMonth.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'Karta muddati o‘tgan';
    }
    if (fullYear > now.year + 20) return 'Yil noto‘g‘ri';
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
