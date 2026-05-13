import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/widgets/gradient_button.dart';
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

class _DriverRegistrationStep2PageState extends State<DriverRegistrationStep2Page> {
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
        _tariffsError = 'Tarmoq xatosi: $e';
      });
    }
  }

  Future<void> _pickIssued() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _regIssuedDate ?? DateTime(now.year - 3, 1, 1),
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Tex. passport berilgan sana',
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
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galereya'),
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
      _toast('Tarif tanlang.');
      return;
    }
    if (_regFront == null || _regBack == null || _vFront == null || _vSide == null || _vBack == null) {
      _toast('5 ta majburiy rasmni yuklang.');
      return;
    }
    if (_hasTrailer && (_tFront == null || _tBack == null || _trailerPlate.text.trim().isEmpty)) {
      _toast('Pritsep ma‘lumotlari to‘liq emas.');
      return;
    }
    if (!_offerta) {
      _toast('Offertani qabul qiling.');
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
      _toast('Tarmoq xatosi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2 — Mashina ma‘lumotlari'),
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
                    trailing: FilledButton.tonal(onPressed: _loadTariffs, child: const Text('Retry')),
                  ),
                )
              else
                DropdownMenu<DriverTariffItem>(
                  initialSelection: _tariff,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('Tarif *'),
                  dropdownMenuEntries: _tariffs
                      .map((t) => DropdownMenuEntry(value: t, label: t.name))
                      .toList(),
                  onSelected: (v) => setState(() => _tariff = v),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleName,
                decoration: const InputDecoration(labelText: 'Mashina rusumi *', hintText: 'Isuzu NQR'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Kerak' : null,
              ),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                decoration: const InputDecoration(labelText: 'Davlat raqami *', hintText: '01A123BC'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Kerak' : null,
              ),
              TextFormField(
                controller: _color,
                decoration: const InputDecoration(labelText: 'Rangi'),
              ),
              TextFormField(
                controller: _capacityKg,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: const InputDecoration(
                  labelText: 'Yuk ko‘tarish sig‘imi (kg) *',
                  hintText: '3000',
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  final n = double.tryParse(s);
                  if (n == null || n <= 0) return 'Musbat son kiriting';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Tex. passport',
                  style: Theme.of(context).textTheme.titleSmall),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _regSeries,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Seriya *', hintText: 'AAA'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Kerak' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _regNumber,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Raqam *', hintText: '0000000'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Kerak' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickIssued,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tex. passport berilgan sana',
                    suffixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(_regIssuedDate == null ? 'Tanlanmagan' : _fmtDate(_regIssuedDate!)),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _hasTrailer,
                onChanged: (v) => setState(() => _hasTrailer = v ?? false),
                title: const Text('Pritsep bor'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasTrailer) ...[
                TextFormField(
                  controller: _trailerPlate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Pritsep davlat raqami *'),
                ),
                _imgRow('Pritsep tex. passport — old *', _tFront, () async {
                  final f = await _pick();
                  if (f != null) setState(() => _tFront = f);
                }),
                _imgRow('Pritsep tex. passport — orqa *', _tBack, () async {
                  final f = await _pick();
                  if (f != null) setState(() => _tBack = f);
                }),
              ],
              const SizedBox(height: 16),
              Text('Rasmlar', style: Theme.of(context).textTheme.titleSmall),
              _imgRow('Tex. passport — old *', _regFront, () async {
                final f = await _pick();
                if (f != null) setState(() => _regFront = f);
              }),
              _imgRow('Tex. passport — orqa *', _regBack, () async {
                final f = await _pick();
                if (f != null) setState(() => _regBack = f);
              }),
              _imgRow('Mashina — old *', _vFront, () async {
                final f = await _pick();
                if (f != null) setState(() => _vFront = f);
              }),
              _imgRow('Mashina — yon *', _vSide, () async {
                final f = await _pick();
                if (f != null) setState(() => _vSide = f);
              }),
              _imgRow('Mashina — orqa *', _vBack, () async {
                final f = await _pick();
                if (f != null) setState(() => _vBack = f);
              }),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _offerta,
                onChanged: (v) => setState(() => _offerta = v ?? false),
                contentPadding: EdgeInsets.zero,
                title: const Text('Loyiha offertasini o‘qidim va qabul qilaman *'),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Keyingi: Egalik va yuridik holat',
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
      subtitle: Text(f?.name ?? 'Tanlanmagan',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(icon: const Icon(Icons.photo_camera_outlined), onPressed: onPick),
    );
  }
}
