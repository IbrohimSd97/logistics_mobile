import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api/api_exception.dart';
import '../../core/api/auth_api.dart';
import '../../core/api/http_response_codec.dart';
import '../../core/config/api_config.dart';
import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';
import '../../core/registration/pinfl_lookup.dart';
import '../../core/session/session_store.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/offerta_link.dart';

/// `POST /api/customer/registration/physical` (multipart, **temp** token).
///
/// Avval JShShIR (PINFL) kiritiladi: F.I.Sh. va tug'ilgan sana soliq bazasidan
/// (Didox) olinadi va mijoz tasdiqlaydi. Topilmasa — qo'lda kiritadi.
class CustomerPhysicalRegistrationPage extends StatefulWidget {
  const CustomerPhysicalRegistrationPage({
    super.key,
    required this.phoneDisplay,
  });

  final String phoneDisplay;

  @override
  State<CustomerPhysicalRegistrationPage> createState() => _CustomerPhysicalRegistrationPageState();
}

class _CustomerPhysicalRegistrationPageState extends State<CustomerPhysicalRegistrationPage>
    with I18nObserverMixin<CustomerPhysicalRegistrationPage> {
  late final TextEditingController _phoneCtrl;
  final _last = TextEditingController();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _pinfl = PinflLookupController();
  DateTime? _birthDate;
  bool _offerta = false;
  bool _loading = false;

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.phoneDisplay);
    _pinfl.addListener(_onPinflChanged);
  }

  void _onPinflChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _last.dispose();
    _first.dispose();
    _middle.dispose();
    _pinfl.removeListener(_onPinflChanged);
    _pinfl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 14, now.month, now.day),
      helpText: I18n.t('customer.reg.birth_date'),
    );
    if (!mounted || picked == null) return;
    setState(() => _birthDate = picked);
  }



  Future<void> _submit() async {
    if (!_offerta) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('customer.reg.accept_offerta_first'))),
      );
      return;
    }
    if (!_pinfl.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('pinfl.must_be_14'))),
      );
      return;
    }
    if (!_pinfl.confirmed && !_pinfl.manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('pinfl.confirm_first'))),
      );
      return;
    }
    if (_pinfl.manual &&
        (_last.text.trim().isEmpty ||
            _first.text.trim().isEmpty ||
            _middle.text.trim().isEmpty ||
            _birthDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('customer.reg.fill_all_fields'))),
      );
      return;
    }
    final temp = await SessionStore().getTempRegistrationToken();
    if (!mounted) return;
    if (temp == null || temp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('customer.reg.no_temp_token'))),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/customer/registration/physical');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $temp'
        ..fields['pinfl'] = _pinfl.value
        ..fields['phone_number'] = _phoneCtrl.text.replaceAll(RegExp(r'\s'), '')
        ..fields['offerta_accepted'] = '1';

      if (_pinfl.confirmed) {
        // F.I.Sh./sana server tomonda soliq bazasidan olinadi.
        req.fields['didox_confirmed'] = '1';
      } else {
        req.fields
          ..['last_name'] = _last.text.trim()
          ..['first_name'] = _first.text.trim()
          ..['middle_name'] = _middle.text.trim()
          ..['birth_date'] = _fmtDate(_birthDate!);
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      final map = decodeJsonEnvelopeOrThrow(res);

      final newTemp = map['temp_token'] as String? ??
          (map['data'] is Map ? (map['data'] as Map)['temp_token']?.toString() : null);

      if (newTemp == null || newTemp.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('customer.reg.no_session_returned'))),
        );
        return;
      }

      await SessionStore().saveTempRegistrationToken(newTemp);
      try {
        final ex = await const AuthApi().exchangeToken(tempToken: newTemp);
        await SessionStore().saveSession(
          refreshToken: ex.refreshToken,
          userId: ex.userId,
          userType: ex.userType ?? 'customer',
          phoneDisplay: _phoneCtrl.text,
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('customer.reg.session_open_failed', {'msg': e.firstFieldMessage}))),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('customer.reg.network_error_label', {'msg': '$e'}))),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('customer.reg.success_msg'))),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.firstFieldMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('customer.reg.error_label', {'msg': '$e'}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('customer.reg.title')),
        actions: [
          IconButton(
            tooltip: I18n.t('common.refresh'),
            icon: const Icon(Icons.refresh_rounded),
            // Form sahifasi — reload formani tozalaydi (telefon raqamidan boshqa).
            onPressed: () {
              _last.clear();
              _first.clear();
              _middle.clear();
              _pinfl.reset();
              setState(() {
                _birthDate = null;
                _offerta = false;
              });
            },
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              I18n.t('customer.reg.intro'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 22),
            AlixSectionTitle(I18n.t('customer.reg.personal_section')),
            PinflLookupField(controller: _pinfl, label: I18n.t('pinfl.label_required')),
            const SizedBox(height: 14),
            // Soliq bazasi topmasa/ishlamasa — F.I.Sh. va sana qo'lda.
            if (_pinfl.manual) ...[
              TextField(controller: _last, decoration: InputDecoration(labelText: I18n.t('customer.reg.last_name_required'))),
              const SizedBox(height: 14),
              TextField(controller: _first, decoration: InputDecoration(labelText: I18n.t('customer.reg.first_name_required'))),
              const SizedBox(height: 14),
              TextField(controller: _middle, decoration: InputDecoration(labelText: I18n.t('customer.reg.middle_name_required'))),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: I18n.t('customer.reg.birth_date_required'),
                    suffixIcon: const Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(_birthDate == null ? I18n.t('customer.reg.not_picked') : _fmtDate(_birthDate!)),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _phoneCtrl,
              readOnly: true,
              decoration: InputDecoration(labelText: I18n.t('customer.reg.phone_label')),
            ),
            const SizedBox(height: 18),
            CheckboxListTile(
              value: _offerta,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _offerta = v ?? false),
              title: OffertaCheckboxTitle(
                text: I18n.t('customer.reg.offerta_checkbox'),
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: I18n.t('customer.reg.submit_btn'),
              icon: Icons.send_rounded,
              loading: _loading,
              // Offerta tasdiqlanmaguncha tugma o'chiq — barcha formada bir xil.
              onPressed: (_loading || !_offerta) ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

}
