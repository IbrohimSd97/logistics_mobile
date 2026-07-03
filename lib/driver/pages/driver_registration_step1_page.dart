import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/config/api_config.dart';
import '../../core/i18n/i18n.dart';
import '../../core/widgets/gradient_button.dart';
import '../driver_api.dart';
import '../driver_models.dart';
import 'driver_registration_step2_page.dart';

class DriverRegistrationStep1Page extends StatefulWidget {
  const DriverRegistrationStep1Page({
    super.key,
    required this.phoneDisplay,
    this.prefillLastName,
    this.prefillFirstName,
    this.prefillMiddleName,
    this.prefillBirthDate,
    this.rejects,
    this.data,
  });

  final String phoneDisplay;
  final String? prefillLastName;
  final String? prefillFirstName;
  final String? prefillMiddleName;
  final String? prefillBirthDate;
  final DriverRegistrationRejects? rejects;

  /// Xatolarni tuzatish oqimida oldin yuborilgan qiymatlar (prefill).
  final DriverRegistrationData? data;

  @override
  State<DriverRegistrationStep1Page> createState() => _DriverRegistrationStep1PageState();
}

class _DriverRegistrationStep1PageState extends State<DriverRegistrationStep1Page>
    with I18nObserverMixin<DriverRegistrationStep1Page> {
  final _formKey = GlobalKey<FormState>();
  final _last = TextEditingController();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _pinfl = TextEditingController();
  final _licSeries = TextEditingController();
  final _licNumber = TextEditingController();

  DateTime? _birthDate;
  DateTime? _licIssuedDate;
  bool _prefilled = false;

  // Server'da mavjud rasmlar (prefill). Foydalanuvchi qayta tanlamasa, submit
  // paytida shu URL'dan yuklab qayta yuboriladi.
  String? _frontUrl;
  String? _backUrl;
  String? _selfieUrl;

  @override
  void initState() {
    super.initState();
    // Prefill: avval data (server) qiymatlari, keyin eski prefill* paramlar.
    final d = widget.data?.step1;
    if (d != null) {
      _setText(_last, widget.data!.s1('last_name'));
      _setText(_first, widget.data!.s1('first_name'));
      _setText(_middle, widget.data!.s1('middle_name'));
      _setText(_pinfl, widget.data!.s1('national_id'));
      _setText(_licSeries, widget.data!.s1('car_license_series'));
      _setText(_licNumber, widget.data!.s1('car_license_number'));
      _birthDate = _parseDate(widget.data!.s1('birth_date')) ?? _birthDate;
      _licIssuedDate =
          _parseDate(widget.data!.s1('car_license_issued_date')) ?? _licIssuedDate;
      _frontUrl = widget.data!.s1('car_license_front_img_url');
      _backUrl = widget.data!.s1('car_license_back_img_url');
      _selfieUrl = widget.data!.s1('car_license_selfie_img_url');
      if (_last.text.isNotEmpty || _birthDate != null) _prefilled = true;
    }
    if (_last.text.isEmpty && (widget.prefillLastName ?? '').isNotEmpty) {
      _last.text = widget.prefillLastName!;
      _prefilled = true;
    }
    if (_first.text.isEmpty && (widget.prefillFirstName ?? '').isNotEmpty) {
      _first.text = widget.prefillFirstName!;
      _prefilled = true;
    }
    if (_middle.text.isEmpty && (widget.prefillMiddleName ?? '').isNotEmpty) {
      _middle.text = widget.prefillMiddleName!;
      _prefilled = true;
    }
    if (_birthDate == null && (widget.prefillBirthDate ?? '').isNotEmpty) {
      _birthDate = _parseDate(widget.prefillBirthDate);
      if (_birthDate != null) _prefilled = true;
    }
  }

  static void _setText(TextEditingController c, String? v) {
    if (v != null && v.isNotEmpty) c.text = v;
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final parts = s.split('T').first.split('-');
      if (parts.length >= 3) {
        return DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (_) {}
    return null;
  }

  XFile? _front;
  XFile? _back;
  XFile? _selfie;
  final _picker = ImagePicker();
  bool _submitting = false;

  @override
  void dispose() {
    _last.dispose();
    _first.dispose();
    _middle.dispose();
    _pinfl.dispose();
    _licSeries.dispose();
    _licNumber.dispose();
    super.dispose();
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirth() async {
    // Sana tanlashdan oldin klaviaturani yopamiz — aks holda oldingi input
    // (otasining ismi) fokusda qolib, klaviatura ochilib turadi.
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: I18n.t('driver.reg.tugilgan'),
    );
    if (!mounted || picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _pickLicIssued() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licIssuedDate ?? DateTime(now.year - 3, 1, 1),
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: I18n.t('driver.reg.helper_license_issued'),
    );
    if (!mounted || picked == null) return;
    setState(() => _licIssuedDate = picked);
  }

  Future<XFile?> _pickImage({required bool selfie}) async {
    if (kIsWeb) {
      return _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    }
    // Selfi (guvohnoma bilan) — galereya tanlash mumkin emas, to'g'ridan old
    // kamera ochiladi.
    if (selfie) {
      return _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        preferredCameraDevice: CameraDevice.front,
      );
    }
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(I18n.t('driver.reg.camera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(I18n.t('driver.reg.gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return null;
    return _picker.pickImage(
      source: src,
      imageQuality: 82,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
    );
  }

  /// Yangi tanlangan rasm bo'lsa — o'sha; aks holda mavjud URL'dan yuklab oladi.
  Future<XFile?> _resolveImage(XFile? picked, String? url) async {
    if (picked != null) return picked;
    if (url != null && url.isNotEmpty) {
      return DriverApi.instance.downloadToTempFile(url);
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_birthDate == null) {
      _toast(I18n.t('driver.reg.birth_required_msg'));
      return;
    }
    if (_licIssuedDate == null) {
      _toast(I18n.t('driver.reg.license_issued_required_msg'));
      return;
    }
    // Har bir rasm: yangi tanlangan bo'lsa — o'sha; aks holda mavjud URL bo'lsa
    // qabul qilinadi (submit paytida yuklab olinadi). Ikkalasi ham yo'q bo'lsa —
    // xatolik.
    if ((_front == null && (_frontUrl ?? '').isEmpty) ||
        (_back == null && (_backUrl ?? '').isEmpty) ||
        (_selfie == null && (_selfieUrl ?? '').isEmpty)) {
      _toast(I18n.t('driver.reg.upload_3_msg'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final front = await _resolveImage(_front, _frontUrl);
      final back = await _resolveImage(_back, _backUrl);
      final selfie = await _resolveImage(_selfie, _selfieUrl);
      if (front == null || back == null || selfie == null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        _toast(I18n.t('driver.reg.upload_3_msg'));
        return;
      }
      final r = await DriverApi.instance.registrationStep1(
        lastName: _last.text.trim(),
        firstName: _first.text.trim(),
        middleName: _middle.text.trim(),
        birthDate: _fmtDate(_birthDate!),
        nationalId: _pinfl.text.trim(),
        carLicenseSeries: _licSeries.text.trim(),
        carLicenseNumber: _licNumber.text.trim(),
        carLicenseIssuedDate: _fmtDate(_licIssuedDate!),
        carLicenseFront: front,
        carLicenseBack: back,
        carLicenseSelfie: selfie,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      final sessionId = r.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        _toast(I18n.t('driver.reg.no_session_id'));
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DriverRegistrationStep2Page(
            phoneDisplay: widget.phoneDisplay,
            sessionId: sessionId,
            rejects: widget.rejects,
            data: widget.data,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(e.firstFieldMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(I18n.t('driver.reg.network_error_label', {'msg': '$e'}));
    }
  }

  String? _fieldError(String field) {
    final errs = widget.rejects?.step1Errors;
    if (errs == null) return null;
    for (final e in errs) {
      if (e is Map && e['field'] == field) {
        final rt = e['reason_text']?.toString();
        if (rt != null && rt.trim().isNotEmpty) return rt.trim();
        return e['reason_code']?.toString();
      }
    }
    return null;
  }

  Widget _errorNote(String field) {
    final r = _fieldError(field);
    if (r == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 6, bottom: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded, size: 15, color: Colors.red),
        const SizedBox(width: 4),
        Expanded(child: Text('Admin: $r', style: const TextStyle(color: Colors.red, fontSize: 12, height: 1.3))),
      ]),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('driver.reg.step1_appbar')),
        actions: [
          IconButton(
            tooltip: I18n.t('common.refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _submitting
                ? null
                : () {
                    _last.clear();
                    _first.clear();
                    _middle.clear();
                    _pinfl.clear();
                    _licSeries.clear();
                    _licNumber.clear();
                    setState(() {
                      _birthDate = null;
                      _licIssuedDate = null;
                      _front = null;
                      _back = null;
                      _selfie = null;
                    });
                  },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: LinearProgressIndicator(value: 1 / 3),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_prefilled)
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            I18n.t('driver.reg.prefill_hint'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_prefilled) const SizedBox(height: 12),
              Text(
                I18n.t('driver.reg.phone_label', {'phone': widget.phoneDisplay}),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _last,
                decoration: InputDecoration(labelText: I18n.t('driver.reg.field_last_required')),
                validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.field_required_last') : null,
              ),
              _errorNote('last_name'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _first,
                decoration: InputDecoration(labelText: I18n.t('driver.reg.field_first_required')),
                validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.field_required_first') : null,
              ),
              _errorNote('first_name'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _middle,
                // Otasining ismi — majburiy emas.
                decoration: InputDecoration(labelText: I18n.t('driver.reg.field_middle')),
              ),
              _errorNote('middle_name'),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickBirth,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: I18n.t('driver.reg.field_birth_required'),
                    suffixIcon: const Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(_birthDate == null ? I18n.t('driver.reg.not_picked') : _fmtDate(_birthDate!)),
                ),
              ),
              _errorNote('birth_date'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pinfl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(14),
                ],
                decoration: InputDecoration(
                  labelText: I18n.t('driver.reg.pinfl_required'),
                  hintText: '00000000000000',
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.length != 14) return I18n.t('driver.reg.pinfl_14_digits');
                  return null;
                },
              ),
              _errorNote('national_id'),
              const SizedBox(height: 16),
              Text(I18n.t('driver.reg.driver_license_section'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _licSeries,
                      textCapitalization: TextCapitalization.characters,
                      // Guvohnoma seriyasi — faqat harf, ko'pi bilan 2 ta.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: InputDecoration(labelText: I18n.t('driver.reg.series_required'), hintText: I18n.t('driver.reg.series_hint')),
                      validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.series_required_msg') : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _licNumber,
                      keyboardType: TextInputType.number,
                      // Guvohnoma raqami — faqat raqam, ko'pi bilan 7 ta.
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(7),
                      ],
                      decoration: InputDecoration(labelText: I18n.t('driver.reg.number_required'), hintText: I18n.t('driver.reg.number_hint')),
                      validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.number_required_msg') : null,
                    ),
                  ),
                ],
              ),
              _errorNote('car_license_series'),
              _errorNote('car_license_number'),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickLicIssued,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: I18n.t('driver.reg.license_issued_required'),
                    suffixIcon: const Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(_licIssuedDate == null ? I18n.t('driver.reg.not_picked') : _fmtDate(_licIssuedDate!)),
                ),
              ),
              _errorNote('car_license_issued_date'),
              const SizedBox(height: 16),
              Text(I18n.t('driver.reg.images_section'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _imgRow(I18n.t('driver.reg.img_license_front'), _front, _frontUrl,
                  () async {
                final f = await _pickImage(selfie: false);
                if (f != null) setState(() => _front = f);
              }),
              _errorNote('car_license_front_img'),
              _imgRow(I18n.t('driver.reg.img_license_back'), _back, _backUrl,
                  () async {
                final f = await _pickImage(selfie: false);
                if (f != null) setState(() => _back = f);
              }),
              _errorNote('car_license_back_img'),
              _imgRow(I18n.t('driver.reg.img_license_selfie'), _selfie, _selfieUrl,
                  () async {
                final f = await _pickImage(selfie: true);
                if (f != null) setState(() => _selfie = f);
              }),
              _errorNote('car_license_selfie_img'),
              const SizedBox(height: 24),
              GradientButton(
                label: I18n.t('driver.reg.next_vehicle_btn'),
                icon: Icons.arrow_forward_rounded,
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgRow(String label, XFile? f, String? existingUrl, VoidCallback onPick) {
    Widget thumb;
    final hasExisting = f == null && (existingUrl ?? '').isNotEmpty;
    if (f == null && !hasExisting) {
      thumb = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_outlined),
      );
    } else if (hasExisting) {
      // Server'dagi mavjud rasm (prefill).
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _fullUrl(existingUrl!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 56,
            height: 56,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    } else if (kIsWeb) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(f!.path, width: 56, height: 56, fit: BoxFit.cover),
      );
    } else {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(f!.path), width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    final subtitle = f?.name ??
        (hasExisting
            ? I18n.t('driver.reg.existing_image')
            : I18n.t('driver.reg.not_picked'));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: thumb,
      title: Text(label),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.photo_camera_outlined),
        onPressed: onPick,
      ),
    );
  }

  static String _fullUrl(String urlOrPath) =>
      urlOrPath.startsWith('http') ? urlOrPath : '${ApiConfig.baseUrl}$urlOrPath';
}
