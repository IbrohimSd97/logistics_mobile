import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../api/http_response_codec.dart';
import '../api/request_headers.dart';
import '../brand/alix_components.dart';
import '../config/api_config.dart';
import '../i18n/i18n.dart';
import '../session/session_store.dart';
import '../theme/app_palette.dart';

/// Soliq bazasidagi (Didox) shaxs — `POST /api/registration/pinfl-lookup` javobi.
class PinflPerson {
  const PinflPerson({
    required this.lastName,
    required this.firstName,
    required this.middleName,
    required this.fullName,
    this.birthDate,
  });

  final String lastName;
  final String firstName;
  final String middleName;
  final String fullName;

  /// YYYY-MM-DD (PINFL'dan). Ba'zan bo'lmasligi mumkin.
  final String? birthDate;

  static PinflPerson? fromMap(Object? raw) {
    if (raw is! Map) return null;
    String s(String k) => (raw[k] ?? '').toString();
    final bd = s('birth_date');
    return PinflPerson(
      lastName: s('last_name'),
      firstName: s('first_name'),
      middleName: s('middle_name'),
      fullName: s('full_name'),
      birthDate: bd.isEmpty ? null : bd,
    );
  }
}

enum PinflLookupStatus {
  /// PINFL hali tekshirilmagan.
  idle,
  loading,

  /// Didox topdi — foydalanuvchi tasdiqlashi kerak.
  found,

  /// Foydalanuvchi "Ha, bu men" dedi: F.I.Sh./sana serverda Didox'dan olinadi.
  confirmed,

  /// Didox topmadi yoki ishlamayapti — F.I.Sh./sana qo'lda kiritiladi.
  manual,
}

/// Ro'yxatdan o'tish formasidagi PINFL holati (mijoz va haydovchi uchun umumiy).
///
/// Forma `confirmed` bo'lsa F.I.Sh./sana maydonlarini yashiradi va so'rovga
/// `didox_confirmed=1` qo'shadi; `manual` bo'lsa eski maydonlarni ko'rsatadi.
class PinflLookupController extends ChangeNotifier {
  PinflLookupController({String? initialPinfl}) : pinfl = TextEditingController(text: initialPinfl ?? '') {
    pinfl.addListener(_onTextChanged);
  }

  final TextEditingController pinfl;
  PinflLookupStatus status = PinflLookupStatus.idle;
  PinflPerson? person;
  String? message;
  String _checked = '';

  bool get confirmed => status == PinflLookupStatus.confirmed;
  bool get manual => status == PinflLookupStatus.manual;
  String get value => pinfl.text.trim();
  bool get isValid => RegExp(r'^\d{14}$').hasMatch(value);

  void _onTextChanged() {
    // Tekshirilgan raqam o'zgartirilsa — natija endi unga tegishli emas.
    if (value != _checked && status != PinflLookupStatus.idle && status != PinflLookupStatus.loading) {
      _set(PinflLookupStatus.idle);
    }
    if (isValid && value != _checked && status == PinflLookupStatus.idle) {
      lookup();
    }
  }

  Future<void> lookup() async {
    if (!isValid || status == PinflLookupStatus.loading) return;
    final pinflValue = value;
    _checked = pinflValue;
    _set(PinflLookupStatus.loading);
    try {
      final token = await SessionStore().getTempRegistrationToken();
      if (token == null || token.isEmpty) throw StateError('no temp token');
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/registration/pinfl-lookup'),
            headers: jsonAuthHeaders(token),
            body: jsonEncode({'pinfl': pinflValue}),
          )
          .timeout(const Duration(seconds: 20));
      final data = decodeJsonEnvelopeOrThrow(res)['data'];
      if (value != pinflValue) return; // foydalanuvchi bu orada raqamni o'zgartirdi
      final found = data is Map && data['status'] == 'found' ? PinflPerson.fromMap(data['person']) : null;
      if (found != null) {
        person = found;
        _set(PinflLookupStatus.found);
      } else {
        final notFound = data is Map && data['status'] == 'not_found';
        _set(PinflLookupStatus.manual,
            msg: I18n.t(notFound ? 'pinfl.not_found' : 'pinfl.unavailable'));
      }
    } catch (_) {
      if (value != pinflValue) return;
      _set(PinflLookupStatus.manual, msg: I18n.t('pinfl.unavailable'));
    }
  }

  void confirm() => _set(PinflLookupStatus.confirmed);

  /// "Yo'q, bu men emas" — raqamni tozalab qayta kiritishga qaytaramiz.
  void reject() {
    _checked = '';
    pinfl.clear();
    _set(PinflLookupStatus.idle);
  }

  void reset() => reject();

  void _set(PinflLookupStatus s, {String? msg}) {
    status = s;
    message = msg;
    if (s == PinflLookupStatus.idle || s == PinflLookupStatus.manual) person = null;
    notifyListeners();
  }

  @override
  void dispose() {
    pinfl.removeListener(_onTextChanged);
    pinfl.dispose();
    super.dispose();
  }
}

/// PINFL maydoni + Didox natijasi (tasdiqlash kartasi / xabar).
class PinflLookupField extends StatelessWidget {
  const PinflLookupField({
    super.key,
    required this.controller,
    required this.label,
    this.errorNote,
  });

  final PinflLookupController controller;
  final String label;

  /// Admin rad etgan bo'lsa izoh (haydovchi formasi).
  final Widget? errorNote;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final locked = c.status == PinflLookupStatus.confirmed || c.status == PinflLookupStatus.found;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: c.pinfl,
              readOnly: locked,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(14),
              ],
              decoration: InputDecoration(
                labelText: label,
                hintText: '00000000000000',
                helperText: c.status == PinflLookupStatus.idle ? I18n.t('pinfl.helper') : null,
                helperMaxLines: 3,
                suffixIcon: switch (c.status) {
                  PinflLookupStatus.loading => const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  PinflLookupStatus.confirmed => const Icon(Icons.verified_rounded, color: AppPalette.success),
                  PinflLookupStatus.manual => IconButton(
                      tooltip: I18n.t('pinfl.retry'),
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: c.isValid ? c.lookup : null,
                    ),
                  _ => null,
                },
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.length != 14) return I18n.t('pinfl.must_be_14');
                return null;
              },
            ),
            ?errorNote,
            if (c.status == PinflLookupStatus.found && c.person != null) ...[
              const SizedBox(height: 12),
              _ConfirmCard(person: c.person!, onYes: c.confirm, onNo: c.reject),
            ],
            if (c.status == PinflLookupStatus.confirmed && c.person != null) ...[
              const SizedBox(height: 12),
              _ConfirmedCard(person: c.person!, onChange: c.reset),
            ],
            if (c.status == PinflLookupStatus.manual && c.message != null) ...[
              const SizedBox(height: 12),
              AlixBanner(message: c.message!, tone: AlixTone.warning),
            ],
          ],
        );
      },
    );
  }
}

class _PersonLines extends StatelessWidget {
  const _PersonLines({required this.person});

  final PinflPerson person;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(person.fullName, style: t.titleMedium),
        if (person.birthDate != null) ...[
          const SizedBox(height: 4),
          Text(I18n.t('pinfl.birth_date', {'date': person.birthDate!}), style: t.bodyMedium),
        ],
      ],
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.person, required this.onYes, required this.onNo});

  final PinflPerson person;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlixCard(
      tone: AlixSurfaceTone.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(I18n.t('pinfl.found_title'), style: t.labelLarge),
          const SizedBox(height: 8),
          _PersonLines(person: person),
          const SizedBox(height: 12),
          Text(I18n.t('pinfl.is_this_you'), style: t.bodyMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onNo, child: Text(I18n.t('pinfl.no'))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(onPressed: onYes, child: Text(I18n.t('pinfl.yes'))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmedCard extends StatelessWidget {
  const _ConfirmedCard({required this.person, required this.onChange});

  final PinflPerson person;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return AlixCard(
      tone: AlixSurfaceTone.cream,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, color: AppPalette.success),
          const SizedBox(width: 12),
          Expanded(child: _PersonLines(person: person)),
          TextButton(onPressed: onChange, child: Text(I18n.t('pinfl.change'))),
        ],
      ),
    );
  }
}
