import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
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
  });

  final String phoneDisplay;
  final String sessionId;

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
  DriverTariffItem? _tariff;
  List<DriverTariffItem> _tariffs = [];
  bool _loadingTariffs = true;
  String? _tariffsError;

  bool _hasTrailer = false;
  bool _offerta = false;

  XFile? _regFront, _regBack, _vFront, _vSide, _vBack, _tFront, _tBack;
  final _picker = ImagePicker();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadTariffs();
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

  Future<void> _loadTariffs() async {
    setState(() {
      _loadingTariffs = true;
      _tariffsError = null;
    });
    try {
      final list = await DriverApi.instance.tariffsList();
      if (!mounted) return;
      setState(() {
        _tariffs = list;
        _loadingTariffs = false;
        _tariff = list.isNotEmpty ? list.first : null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTariffs = false;
        _tariffsError = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTariffs = false;
        _tariffsError = I18n.t('driver.reg.network_error_label', {'msg': '$e'});
      });
    }
  }

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

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_tariff == null) {
      _toast(I18n.t('driver.reg.select_tariff'));
      return;
    }
    if (_regFront == null || _regBack == null || _vFront == null || _vSide == null || _vBack == null) {
      _toast(I18n.t('driver.reg.upload_5_required'));
      return;
    }
    if (_hasTrailer && (_tFront == null || _tBack == null || _trailerPlate.text.trim().isEmpty)) {
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
        tariffId: _tariff!.id,
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
        regCertFront: _regFront!,
        regCertBack: _regBack!,
        vehicleFront: _vFront!,
        vehicleSide: _vSide!,
        vehicleBack: _vBack!,
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
        actions: [
          IconButton(
            tooltip: I18n.t('common.refresh'),
            icon: _loadingTariffs
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            // Tariflar ro'yxatini qaytadan tortib olamiz (tanlangan tarif saqlanadi
            // agar yangi ro'yxatda ham mavjud bo'lsa). Form maydonlari tegmaydi.
            onPressed: (_submitting || _loadingTariffs) ? null : _loadTariffs,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: LinearProgressIndicator(value: 2 / 3),
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
              if (_loadingTariffs)
                const LinearProgressIndicator()
              else if (_tariffsError != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.error_outline_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    title: Text(_tariffsError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                    trailing: FilledButton.tonal(onPressed: _loadTariffs, child: Text(I18n.t('common.retry_short'))),
                  ),
                )
              else
                DropdownMenu<DriverTariffItem>(
                  initialSelection: _tariff,
                  expandedInsets: EdgeInsets.zero,
                  label: Text(I18n.t('driver.reg.tariff_required')),
                  dropdownMenuEntries: _tariffs
                      .map((t) => DropdownMenuEntry(value: t, label: t.name))
                      .toList(),
                  onSelected: (v) => setState(() => _tariff = v),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleName,
                decoration: InputDecoration(labelText: I18n.t('driver.reg.vehicle_name_required'), hintText: I18n.t('driver.reg.vehicle_name_hint')),
                validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.field_required_short') : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                // Davlat raqami maskasi: 01 A 123 BC (2 raqam · 1 harf · 3 raqam · 2 harf).
                inputFormatters: [_UzPlateFormatter()],
                decoration: InputDecoration(labelText: I18n.t('driver.reg.plate_required'), hintText: I18n.t('driver.reg.plate_hint')),
                validator: (v) => (v ?? '').trim().isEmpty ? I18n.t('driver.reg.field_required_short') : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _color,
                decoration: InputDecoration(labelText: I18n.t('driver.reg.color_label')),
              ),
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
              const SizedBox(height: 16),
              Text(I18n.t('driver.reg.techpassport_section'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
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
                _imgRow(I18n.t('driver.reg.img_trailer_front'), _tFront, () async {
                  final f = await _pick();
                  if (f != null) setState(() => _tFront = f);
                }),
                _imgRow(I18n.t('driver.reg.img_trailer_back'), _tBack, () async {
                  final f = await _pick();
                  if (f != null) setState(() => _tBack = f);
                }),
              ],
              const SizedBox(height: 16),
              Text(I18n.t('driver.reg.images_section'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 14),
              _imgRow(I18n.t('driver.reg.img_techpass_front'), _regFront, () async {
                final f = await _pick();
                if (f != null) setState(() => _regFront = f);
              }),
              _imgRow(I18n.t('driver.reg.img_techpass_back'), _regBack, () async {
                final f = await _pick();
                if (f != null) setState(() => _regBack = f);
              }),
              _imgRow(I18n.t('driver.reg.img_vehicle_front'), _vFront, () async {
                final f = await _pick();
                if (f != null) setState(() => _vFront = f);
              }),
              _imgRow(I18n.t('driver.reg.img_vehicle_side'), _vSide, () async {
                final f = await _pick();
                if (f != null) setState(() => _vSide = f);
              }),
              _imgRow(I18n.t('driver.reg.img_vehicle_back'), _vBack, () async {
                final f = await _pick();
                if (f != null) setState(() => _vBack = f);
              }),
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

  Widget _imgRow(String label, XFile? f, VoidCallback onPick) {
    Widget thumb;
    if (f == null) {
      thumb = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_outlined),
      );
    } else if (kIsWeb) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(f.path, width: 56, height: 56, fit: BoxFit.cover),
      );
    } else {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(f.path), width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: thumb,
      title: Text(label),
      subtitle: Text(f?.name ?? I18n.t('driver.reg.not_picked'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(icon: const Icon(Icons.photo_camera_outlined), onPressed: onPick),
    );
  }
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