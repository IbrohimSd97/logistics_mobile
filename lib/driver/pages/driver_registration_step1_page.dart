import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/widgets/gradient_button.dart';
import '../driver_api.dart';
import 'driver_registration_step2_page.dart';

class DriverRegistrationStep1Page extends StatefulWidget {
  const DriverRegistrationStep1Page({
    super.key,
    required this.phoneDisplay,
    this.prefillLastName,
    this.prefillFirstName,
    this.prefillMiddleName,
    this.prefillBirthDate,
  });

  final String phoneDisplay;
  final String? prefillLastName;
  final String? prefillFirstName;
  final String? prefillMiddleName;
  final String? prefillBirthDate;

  @override
  State<DriverRegistrationStep1Page> createState() => _DriverRegistrationStep1PageState();
}

class _DriverRegistrationStep1PageState extends State<DriverRegistrationStep1Page> {
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

  @override
  void initState() {
    super.initState();
    if ((widget.prefillLastName ?? '').isNotEmpty) {
      _last.text = widget.prefillLastName!;
      _prefilled = true;
    }
    if ((widget.prefillFirstName ?? '').isNotEmpty) {
      _first.text = widget.prefillFirstName!;
      _prefilled = true;
    }
    if ((widget.prefillMiddleName ?? '').isNotEmpty) {
      _middle.text = widget.prefillMiddleName!;
      _prefilled = true;
    }
    if ((widget.prefillBirthDate ?? '').isNotEmpty) {
      try {
        final parts = widget.prefillBirthDate!.split('-');
        if (parts.length >= 3) {
          _birthDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          _prefilled = true;
        }
      } catch (_) {}
    }
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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Tug‘ilgan sana',
    );
    if (!mounted || picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _pickLicIssued() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licIssuedDate ?? DateTime(now.year - 3, 1, 1),
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Guvohnoma berilgan sana',
    );
    if (!mounted || picked == null) return;
    setState(() => _licIssuedDate = picked);
  }

  Future<XFile?> _pickImage({required bool selfie}) async {
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
    return _picker.pickImage(
      source: src,
      imageQuality: 82,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_birthDate == null) {
      _toast('Tug‘ilgan sanani tanlang.');
      return;
    }
    if (_licIssuedDate == null) {
      _toast('Guvohnoma berilgan sanani tanlang.');
      return;
    }
    if (_front == null || _back == null || _selfie == null) {
      _toast('3 ta rasmni yuklang.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final r = await DriverApi.instance.registrationStep1(
        lastName: _last.text.trim(),
        firstName: _first.text.trim(),
        middleName: _middle.text.trim(),
        birthDate: _fmtDate(_birthDate!),
        nationalId: _pinfl.text.trim(),
        carLicenseSeries: _licSeries.text.trim(),
        carLicenseNumber: _licNumber.text.trim(),
        carLicenseIssuedDate: _fmtDate(_licIssuedDate!),
        carLicenseFront: _front!,
        carLicenseBack: _back!,
        carLicenseSelfie: _selfie!,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      final sessionId = r.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        _toast('Server session_id qaytarmadi.');
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DriverRegistrationStep2Page(
            phoneDisplay: widget.phoneDisplay,
            sessionId: sessionId,
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

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1 — Shaxsiy ma‘lumotlar'),
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
                            'Customer ma‘lumotlaringizdan ba‘zi maydonlar avtomat to‘ldirildi. Tekshirib chiqib, kerak bo‘lsa o‘zgartiring.',
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
                'Telefon: ${widget.phoneDisplay}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _last,
                decoration: const InputDecoration(labelText: 'Familiya *'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Familiya kerak' : null,
              ),
              TextFormField(
                controller: _first,
                decoration: const InputDecoration(labelText: 'Ism *'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Ism kerak' : null,
              ),
              TextFormField(
                controller: _middle,
                decoration: const InputDecoration(labelText: 'Otasining ismi *'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Otasining ismi kerak' : null,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tug‘ilgan sana *',
                    suffixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(_birthDate == null ? 'Tanlanmagan' : _fmtDate(_birthDate!)),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pinfl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(14),
                ],
                decoration: const InputDecoration(
                  labelText: 'PINFL (14 raqam) *',
                  hintText: '00000000000000',
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.length != 14) return '14 raqam kerak';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Haydovchilik guvohnomasi',
                  style: Theme.of(context).textTheme.titleSmall),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _licSeries,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(10)],
                      decoration: const InputDecoration(labelText: 'Seriya *', hintText: 'AB'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Seriya kerak' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _licNumber,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(20),
                      ],
                      decoration: const InputDecoration(labelText: 'Raqam *', hintText: '0000000'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Raqam kerak' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickLicIssued,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Guvohnoma berilgan sana *',
                    suffixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(_licIssuedDate == null ? 'Tanlanmagan' : _fmtDate(_licIssuedDate!)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Rasmlar',
                  style: Theme.of(context).textTheme.titleSmall),
              _imgRow('Guvohnoma — old tomon *', _front, () async {
                final f = await _pickImage(selfie: false);
                if (f != null) setState(() => _front = f);
              }),
              _imgRow('Guvohnoma — orqa tomon *', _back, () async {
                final f = await _pickImage(selfie: false);
                if (f != null) setState(() => _back = f);
              }),
              _imgRow('Guvohnoma bilan selfi *', _selfie, () async {
                final f = await _pickImage(selfie: true);
                if (f != null) setState(() => _selfie = f);
              }),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Keyingi: Mashina ma‘lumotlari',
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
      trailing: IconButton(
        icon: const Icon(Icons.photo_camera_outlined),
        onPressed: onPick,
      ),
    );
  }
}
