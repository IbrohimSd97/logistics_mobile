import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/auth_api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/session/session_store.dart';
import '../../screens/login_screen.dart';
import '../driver_api.dart';
import '../driver_models.dart';
import 'driver_registration_step1_page.dart';

class DriverRejectedPage extends StatefulWidget {
  const DriverRejectedPage({
    super.key,
    required this.phoneDisplay,
    required this.userId,
    required this.status,
  });

  final String phoneDisplay;
  final int userId;
  final DriverRegistrationStatus status;

  @override
  State<DriverRejectedPage> createState() => _DriverRejectedPageState();
}

class _DriverRejectedPageState extends State<DriverRejectedPage>
    with I18nObserverMixin<DriverRejectedPage> {
  DriverRegistrationRejects? _rejects;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await DriverApi.instance.registrationRejects();
      if (!mounted) return;
      setState(() {
        _rejects = r;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = I18n.t('driver.network_error_label', {'msg': '$e'});
      });
    }
  }

  Future<void> _logoutAndRetry() async {
    await SessionStore().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// Xatolarni tuzatish — LOGOUT SHART EMAS. Joriy refresh sessiyadan yangi
  /// temp_token olib, to'g'ridan-to'g'ri registratsiya qadamlarini (Step 1→3)
  /// ochamiz. Backend qadamlarni upsert qiladi (yangi driver yaratmaydi),
  /// yakunda status yana `pending` bo'lib DriverPendingPage'ga o'tadi.
  Future<void> _startFix() async {
    setState(() => _busy = true);
    final refresh = await SessionStore().getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      // Refresh yo'q — eski yo'l (logout → login → OTP).
      await _logoutAndRetry();
      return;
    }
    try {
      final temp = await const AuthApi().issueTempTokenFromRefresh(refresh);
      await SessionStore().saveTempRegistrationToken(temp);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('driver.network_error_label', {'msg': '$e'}))),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DriverRegistrationStep1Page(phoneDisplay: widget.phoneDisplay),
      ),
    );
  }

  Widget _stepCard(int stepNo, String title, List<dynamic>? errors, ColorScheme cs) {
    if (errors == null || errors.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
          title: Text(I18n.t('driver.rejected.step_prefix', {'n': stepNo, 'title': title})),
          subtitle: Text(I18n.t('driver.rejected.step_no_error')),
        ),
      );
    }
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  I18n.t('driver.rejected.step_prefix', {'n': stepNo, 'title': title}),
                  style: TextStyle(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...errors.map((e) {
              final map = e is Map ? e : const <dynamic, dynamic>{};
              final field = map['field']?.toString() ?? '';
              final reasonText = map['reason_text']?.toString();
              final reasonCode = map['reason_code']?.toString();
              // Asosiy: admin yozgan aniq izoh (reason_text). Bo'sh bo'lsa —
              // reason_code'ni o'qiladigan ko'rinishga o'giramiz.
              final reason = (reasonText != null && reasonText.trim().isNotEmpty)
                  ? reasonText.trim()
                  : _reasonLabel(reasonCode);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${_fieldLabel(field)}: $reason',
                  style: TextStyle(color: cs.onErrorContainer, height: 1.35),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _humanize(String key) =>
      key.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m[0]!.toUpperCase());

  /// Backend maydon nomini (masalan `car_license_selfie_img`) o'qiladigan
  /// nomga o'giradi. Noma'lum maydon — umumiy humanize.
  static const Map<String, String> _fieldLabels = {
    'last_name': 'Familiya',
    'first_name': 'Ism',
    'middle_name': 'Otasining ismi',
    'birth_date': 'Tug‘ilgan sana',
    'national_id': 'JSHSHIR (INN)',
    'car_license_series': 'Guvohnoma seriyasi',
    'car_license_number': 'Guvohnoma raqami',
    'car_license_issued_date': 'Guvohnoma berilgan sana',
    'car_license_front_img': 'Guvohnoma — old tomon',
    'car_license_back_img': 'Guvohnoma — orqa tomon',
    'car_license_selfie_img': 'Guvohnoma bilan selfi',
    'vehicle_name': 'Avtomobil nomi',
    'plate_number': 'Davlat raqami',
    'reg_certificate_series': 'Texpasport seriyasi',
    'reg_certificate_number': 'Texpasport raqami',
    'reg_certificate_issued_date': 'Texpasport sanasi',
    'reg_certificate_front_img': 'Texpasport — old',
    'reg_certificate_back_img': 'Texpasport — orqa',
    'vehicle_front_img': 'Avtomobil — old',
    'vehicle_side_img': 'Avtomobil — yon',
    'vehicle_back_img': 'Avtomobil — orqa',
    'ownership_contract_img': 'Mulkchilik hujjati',
    'legal_certificate_img': 'Yuridik hujjat',
  };

  String _fieldLabel(String field) => _fieldLabels[field] ?? _humanize(field);

  /// reason_code'ni (masalan `blurry_image`) o'qiladigan sababga o'giradi.
  static const Map<String, String> _reasonLabels = {
    'blurry_image': 'Rasm noaniq',
    'wrong_document': 'Noto‘g‘ri hujjat',
    'unreadable': 'O‘qib bo‘lmaydi',
    'mismatch': 'Ma’lumotlar mos kelmaydi',
    'expired': 'Muddati o‘tgan',
    'invalid': 'Noto‘g‘ri',
    'missing': 'Yetishmaydi',
    'other': 'Boshqa sabab',
  };

  String _reasonLabel(String? code) {
    if (code == null || code.trim().isEmpty) return I18n.t('driver.rejected.reason_generic');
    return _reasonLabels[code] ?? _humanize(code);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('driver.rejected.title')),
        actions: [
          IconButton(
            tooltip: I18n.t('driver.pending.refresh_tooltip'),
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.report_gmailerrorred_rounded, color: cs.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            I18n.t('driver.rejected.body_heading'),
                            style: TextStyle(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            I18n.t('driver.rejected.fix_body'),
                            style: TextStyle(color: cs.onErrorContainer, height: 1.35),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            I18n.t('driver.rejected.rejected_count', {'count': widget.status.rejectCount}),
                            style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Card(
                color: cs.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                  title: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                  trailing: FilledButton.tonal(onPressed: _load, child: Text(I18n.t('driver.retry_btn_short'))),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_rejects != null) ...[
              if ((_rejects!.comment ?? '').isNotEmpty) ...[
                Card(
                  color: cs.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(I18n.t('driver.rejected.admin_comment'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onTertiaryContainer,
                            )),
                        const SizedBox(height: 6),
                        Text(
                          _rejects!.comment!,
                          style: TextStyle(color: cs.onTertiaryContainer, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _stepCard(1, I18n.t('driver.rejected.step1_title'), _rejects!.step1Errors, cs),
              _stepCard(2, I18n.t('driver.rejected.step2_title'), _rejects!.step2Errors, cs),
              _stepCard(3, I18n.t('driver.rejected.step3_title'), _rejects!.step3Errors, cs),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _startFix,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.build_rounded),
              label: Text(I18n.t('driver.rejected.fix_btn')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              I18n.t('driver.rejected.fix_hint'),
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.35, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
