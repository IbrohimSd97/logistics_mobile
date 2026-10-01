import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/config/api_config.dart';
import '../../core/brand/alix_components.dart';
import '../../core/camera/camera_capture_page.dart';
import '../../core/theme/app_palette.dart';
import '../../core/i18n/i18n.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/offerta_link.dart';
import '../driver_api.dart';
import '../driver_models.dart';
import 'driver_registration_step3_page.dart';

class DriverRegistrationStep2Page extends StatefulWidget {
  const DriverRegistrationStep2Page({
    super.key,
    required this.phoneDisplay,
    required this.sessionId,
    this.rejects,
    this.data,
  });

  final String phoneDisplay;
  final String sessionId;
  final DriverRegistrationRejects? rejects;

  /// Xatolarni tuzatish oqimida oldin yuborilgan qiymatlar (prefill).
  final DriverRegistrationData? data;

  @override
  State<DriverRegistrationStep2Page> createState() => _DriverRegistrationStep2PageState();
}

class _DriverRegistrationStep2PageState extends State<DriverRegistrationStep2Page>
    with I18nObserverMixin<DriverRegistrationStep2Page> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleName = TextEditingController();
  final _plate = TextEditingController();
  final _color = TextEditingController();
  final _capacityKg = TextEditingController();
  final _regSeries = TextEditingController();
  final _regNumber = TextEditingController();
  final _trailerPlate = TextEditingController();

  DateTime? _regIssuedDate;

  bool _hasTrailer = false;
  bool _offerta = false;

  XFile? _regFront, _regBack, _vFront, _vSide, _vBack, _tFront, _tBack;

  // Server'da mavjud rasmlar (prefill). Foydalanuvchi qayta tanlamasa, rasm
  // yuborilmaydi — server mavjud faylni saqlab qoladi.
  String? _regFrontUrl,
      _regBackUrl,
      _vFrontUrl,
      _vSideUrl,
      _vBackUrl,
      _tFrontUrl,
      _tBackUrl;

  final _picker = ImagePicker();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Prefill: server (data.step2) qiymatlaridan.
    final d = widget.data?.step2;
    if (d != null) {
      _setText(_vehicleName, widget.data!.s2('vehicle_name'));
      _setText(_plate, widget.data!.s2('plate_number'));
      _setText(_color, widget.data!.s2('color'));
      _setText(_capacityKg, widget.data!.s2('capacity_kg'));
      _setText(_regSeries, widget.data!.s2('reg_certificate_series'));
      _setText(_regNumber, widget.data!.s2('reg_certificate_number'));
      _setText(_trailerPlate, widget.data!.s2('trailer_plate_number'));
      _regIssuedDate =
          _parseDate(widget.data!.s2('reg_certificate_issued_date')) ?? _regIssuedDate;
      _hasTrailer = widget.data!.b2('has_trailer');
      _regFrontUrl = widget.data!.s2('reg_certificate_front_img_url');
      _regBackUrl = widget.data!.s2('reg_certificate_back_img_url');
      _vFrontUrl = widget.data!.s2('vehicle_front_img_url');
      _vSideUrl = widget.data!.s2('vehicle_side_img_url');
      _vBackUrl = widget.data!.s2('vehicle_back_img_url');
      _tFrontUrl = widget.data!.s2('trailer_reg_certificate_front_img_url');
      _tBackUrl = widget.data!.s2('trailer_reg_certificate_back_img_url');
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

  @override
  void dispose() {
    _vehicleName.dispose();
    _plate.dispose();
    _color.dispose();
    _capacityKg.dispose();
    _regSeries.dispose();
    _regNumber.dispose();
    _trailerPlate.dispose();
    super.dispose();
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickIssued() async {
    // Sana tanlashdan oldin klaviaturani yopamiz.
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _regIssuedDate ?? DateTime(now.year - 3, 1, 1),
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: I18n.t('driver.reg.helper_techpassport_issued'),
    );
    if (!mounted || picked == null) return;
    setState(() => _regIssuedDate = picked);
  }

  Future<XFile?> _pick() async {
    if (kIsWeb) {
      return _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
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
    return _picker.pickImage(source: src, imageQuality: 82);
  }

  /// Mashina rasmlari — faqat kamera orqali (galereya yo'q), orqa kamera.
  Future<XFile?> _shootVehicle(String hintKey) async {
    if (kIsWeb) return _pick();
    return captureWithCamera(context, lens: CameraLensDirection.back, hint: I18n.t(hintKey));
  }

  /// Admin rad etgan rasm qayta olinishi shart — mavjudi qabul qilinmaydi.
  bool _needsNew(String field, XFile? picked) =>
      picked == null && _fieldError(field) != null;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Har bir majburiy rasm: yangi tanlangan bo'lsa — o'sha yuboriladi; aks
    // holda serverdagi mavjud rasm saqlanib qoladi.
    if ((_regFront == null && (_regFrontUrl ?? '').isEmpty) ||
        (_regBack == null && (_regBackUrl ?? '').isEmpty) ||
        (_vFront == null && (_vFrontUrl ?? '').isEmpty) ||
        (_vSide == null && (_vSideUrl ?? '').isEmpty) ||
        (_vBack == null && (_vBackUrl ?? '').isEmpty)) {
      _toast(I18n.t('driver.reg.upload_5_required'));
      return;
    }
    if (_needsNew('reg_certificate_front_img', _regFront) ||
        _needsNew('reg_certificate_back_img', _regBack) ||
        _needsNew('vehicle_front_img', _vFront) ||
        _needsNew('vehicle_side_img', _vSide) ||
        _needsNew('vehicle_back_img', _vBack) ||
        (_hasTrailer &&
            (_needsNew('trailer_reg_certificate_front_img', _tFront) ||
                _needsNew('trailer_reg_certificate_back_img', _tBack)))) {
      _toast(I18n.t('driver.reg.retake_rejected_msg'));
      return;
    }
    if (_hasTrailer &&
        ((_tFront == null && (_tFrontUrl ?? '').isEmpty) ||
            (_tBack == null && (_tBackUrl ?? '').isEmpty) ||
            _trailerPlate.text.trim().isEmpty)) {
      _toast(I18n.t('driver.reg.trailer_incomplete'));
      return;
    }
    if (!_offerta) {
      _toast(I18n.t('driver.reg.accept_offerta'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final r = await DriverApi.instance.registrationStep2(
        sessionId: widget.sessionId,
        vehicleName: _vehicleName.text.trim(),
        plateNumber: _plate.text.trim(),
        color: _color.text.trim().isEmpty ? null : _color.text.trim(),
        capacityKg: _capacityKg.text.trim(),
        regCertSeries: _regSeries.text.trim(),
        regCertNumber: _regNumber.text.trim(),
        regCertIssuedDate: _regIssuedDate == null ? null : _fmtDate(_regIssuedDate!),
        hasTrailer: _hasTrailer,
        trailerPlateNumber: _hasTrailer ? _trailerPlate.text.trim() : null,
        projectOffertaAccepted: _offerta,
        regCertFront: _regFront,
        regCertBack: _regBack,
        vehicleFront: _vFront,
        vehicleSide: _vSide,
        vehicleBack: _vBack,
        trailerRegFront: _hasTrailer ? _tFront : null,
        trailerRegBack: _hasTrailer ? _tBack : null,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      // step 3 ga o'tamiz; sessionId aynan o'sha
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DriverRegistrationStep3Page(
            phoneDisplay: widget.phoneDisplay,
            sessionId: r.sessionId ?? widget.sessionId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('driver.reg.step2_appbar')),
      ),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              AlixStepHeader(
                step: 2,
                total: 3,
                label: I18n.t('driver.reg.step_of', {'n': 2, 'total': 3}),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _vehicleName,
                decoration: InputDecoration(labelText: I18n.t('driver.reg.vehicle_name_required'), hintText: I18n.t('driver.reg.vehicle_name_hint')),
                validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.field_required_short') : null,
              ),
              _errorNote('vehicle_name'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                // Davlat raqami maskasi: 01 A 123 BC (2 raqam · 1 harf · 3 raqam · 2 harf).
                inputFormatters: [_UzPlateFormatter()],
                decoration: InputDecoration(labelText: I18n.t('driver.reg.plate_required'), hintText: I18n.t('driver.reg.plate_hint')),
                validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.field_required_short') : null,
              ),
              _errorNote('plate_number'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _color,
                decoration: InputDecoration(labelText: I18n.t('driver.reg.color_label')),
              ),
              _errorNote('color'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _capacityKg,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  labelText: I18n.t('driver.reg.capacity_kg_required'),
                  hintText: I18n.t('driver.reg.capacity_hint'),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  final n = double.tryParse(s);
                  if (n == null || n <= 0) return I18n.t('driver.reg.capacity_positive_required');
                  return null;
                },
              ),
              _errorNote('capacity_kg'),
              const SizedBox(height: 16),
              Text(I18n.t('driver.reg.techpassport_section'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _regSeries,
                          textCapitalization: TextCapitalization.characters,
                          // Tex passport seriyasi — faqat harf, ko'pi bilan 3 ta.
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(labelText: I18n.t('driver.reg.series_required'), hintText: I18n.t('driver.reg.techpassport_series_hint')),
                          validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.field_required_short') : null,
                        ),
                        _errorNote('reg_certificate_series'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _regNumber,
                          keyboardType: TextInputType.number,
                          // Tex passport raqami — faqat raqam, ko'pi bilan 7 ta.
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                          ],
                          decoration: InputDecoration(labelText: I18n.t('driver.reg.number_required'), hintText: I18n.t('driver.reg.number_hint')),
                          validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.field_required_short') : null,
                        ),
                        _errorNote('reg_certificate_number'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickIssued,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: I18n.t('driver.reg.techpassport_issued_label'),
                    suffixIcon: const Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(_regIssuedDate == null ? I18n.t('driver.reg.not_picked') : _fmtDate(_regIssuedDate!)),
                ),
              ),
              _errorNote('reg_certificate_issued_date'),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _hasTrailer,
                onChanged: (v) => setState(() => _hasTrailer = v ?? false),
                title: Text(I18n.t('driver.reg.has_trailer')),
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasTrailer) ...[
                TextFormField(
                  controller: _trailerPlate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: I18n.t('driver.reg.trailer_plate_required')),
                ),
                _errorNote('trailer_plate_number'),
                _imgRow(I18n.t('driver.reg.img_trailer_front'), _tFront, _tFrontUrl, field: 'trailer_reg_certificate_front_img', () async {
                  final f = await _pick();
                  if (f != null) setState(() => _tFront = f);
                }),
                _errorNote('trailer_reg_certificate_front_img'),
                _imgRow(I18n.t('driver.reg.img_trailer_back'), _tBack, _tBackUrl, field: 'trailer_reg_certificate_back_img', () async {
                  final f = await _pick();
                  if (f != null) setState(() => _tBack = f);
                }),
                _errorNote('trailer_reg_certificate_back_img'),
              ],
              const SizedBox(height: 16),
              Text(I18n.t('driver.reg.images_section'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 14),
              _imgRow(I18n.t('driver.reg.img_techpass_front'), _regFront, _regFrontUrl, field: 'reg_certificate_front_img', () async {
                final f = await _pick();
                if (f != null) setState(() => _regFront = f);
              }),
              _errorNote('reg_certificate_front_img'),
              _imgRow(I18n.t('driver.reg.img_techpass_back'), _regBack, _regBackUrl, field: 'reg_certificate_back_img', () async {
                final f = await _pick();
                if (f != null) setState(() => _regBack = f);
              }),
              _errorNote('reg_certificate_back_img'),
              _imgRow(I18n.t('driver.reg.img_vehicle_front'), _vFront, _vFrontUrl, field: 'vehicle_front_img', () async {
                final f = await _shootVehicle('camera.hint_vehicle_front');
                if (f != null) setState(() => _vFront = f);
              }),
              _errorNote('vehicle_front_img'),
              _imgRow(I18n.t('driver.reg.img_vehicle_side'), _vSide, _vSideUrl, field: 'vehicle_side_img', () async {
                final f = await _shootVehicle('camera.hint_vehicle_side');
                if (f != null) setState(() => _vSide = f);
              }),
              _errorNote('vehicle_side_img'),
              _imgRow(I18n.t('driver.reg.img_vehicle_back'), _vBack, _vBackUrl, field: 'vehicle_back_img', () async {
                final f = await _shootVehicle('camera.hint_vehicle_back');
                if (f != null) setState(() => _vBack = f);
              }),
              _errorNote('vehicle_back_img'),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _offerta,
                onChanged: (v) => setState(() => _offerta = v ?? false),
                contentPadding: EdgeInsets.zero,
                title: OffertaCheckboxTitle(
                  text: I18n.t('driver.reg.project_offerta_text'),
                ),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: I18n.t('driver.reg.next_ownership_btn'),
                icon: Icons.arrow_forward_rounded,
                loading: _submitting,
                onPressed: (_submitting || !_offerta) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _fieldError(String field) {
    final errs = widget.rejects?.step2Errors;
    if (errs == null) return null;
    for (final e in errs) {
      if (e is Map && e['field'] == field) return driverRejectNote(e);
    }
    return null;
  }

  Widget _errorNote(String field) {
    final r = _fieldError(field);
    if (r == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 6, bottom: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded,
            size: 15, color: AppPalette.dangerLight),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            I18n.t('driver.reg.admin_note', {'text': r}),
            style: const TextStyle(
              color: AppPalette.dangerLight,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _imgRow(String label, XFile? f, String? existingUrl, VoidCallback onPick,
      {required String field}) {
    final cs = Theme.of(context).colorScheme;
    final hasExisting = f == null && (existingUrl ?? '').isNotEmpty;
    // Admin rad etgan mavjud rasm "tayyor" (✓) ko'rinmasin — qayta olish kerak.
    final needsRetake = f == null && _fieldError(field) != null;
    const size = 52.0;
    const radius = AppPalette.radiusChip;

    Widget thumb;
    if (f == null && !hasExisting) {
      thumb = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
      );
    } else if (hasExisting) {
      // Server'dagi mavjud rasm (prefill).
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          _fullUrl(existingUrl!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: cs.surface,
            child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
          ),
        ),
      );
    } else if (kIsWeb) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(f!.path, width: size, height: size, fit: BoxFit.cover),
      );
    } else {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(File(f!.path), width: size, height: size, fit: BoxFit.cover),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AlixUploadRow(
        label: label,
        status: f?.name ??
            (needsRetake
                ? I18n.t('driver.reg.needs_retake')
                : hasExisting
                    ? I18n.t('driver.reg.existing_image')
                    : I18n.t('driver.reg.not_picked')),
        filled: f != null || (hasExisting && !needsRetake),
        thumbnail: thumb,
        onPick: onPick,
      ),
    );
  }

  static String _fullUrl(String urlOrPath) =>
      urlOrPath.startsWith('http') ? urlOrPath : '${ApiConfig.baseUrl}$urlOrPath';
}

class _UzPlateFormatter extends TextInputFormatter {
  bool _isDigitPos(int i) => i <= 1 || (i >= 3 && i <= 5);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw =
        newValue.text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    final buf = StringBuffer();
    for (var i = 0; i < raw.length && buf.length < 8; i++) {
      final c = raw[i];
      final isDigit = RegExp('[0-9]').hasMatch(c);
      final pos = buf.length;
      if (_isDigitPos(pos)) {
        if (isDigit) buf.write(c);
      } else {
        if (!isDigit) buf.write(c);
      }
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}