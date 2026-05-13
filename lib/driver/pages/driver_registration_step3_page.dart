import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/auth_api.dart';
import '../../core/session/session_store.dart';
import '../../core/widgets/gradient_button.dart';
import '../driver_api.dart';
import '../driver_models.dart';

class DriverRegistrationStep3Page extends StatefulWidget {
  const DriverRegistrationStep3Page({
    super.key,
    required this.phoneDisplay,
    required this.sessionId,
  });

  final String phoneDisplay;
  final String sessionId;

  @override
  State<DriverRegistrationStep3Page> createState() => _DriverRegistrationStep3PageState();
}

class _DriverRegistrationStep3PageState extends State<DriverRegistrationStep3Page> {
  /// 1=O'zimniki, 2=Boshqa hujjat asosida
  int _ownership = 1;
  XFile? _ownershipFile;

  /// 1=YATT, 2=O'z-o'zini band qilish, 3=Jismoniy shaxs
  int _legalType = 3;
  XFile? _legalPdf;

  AvtoparkItem? _avtopark;
  List<AvtoparkItem> _avtoparks = [];
  bool _loadingAvtoparks = true;
  String? _avtoparksError;

  bool _companyOfferta = false;
  bool _submitting = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAvtoparks();
  }

  Future<void> _loadAvtoparks() async {
    setState(() {
      _loadingAvtoparks = true;
      _avtoparksError = null;
    });
    try {
      final list = await DriverApi.instance.avtoparksList();
      if (!mounted) return;
      setState(() {
        _avtoparks = list;
        _loadingAvtoparks = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAvtoparks = false;
        _avtoparksError = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAvtoparks = false;
        _avtoparksError = 'Tarmoq xatosi: $e';
      });
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<XFile?> _pickImage() async {
    if (kIsWeb) return _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
    if (src == null) return null;
    return _picker.pickImage(source: src, imageQuality: 82);
  }

  /// Note: image_picker hozircha PDF tanlashga ruxsat bermaydi (faqat rasmlar).
  /// Step3 backend `mimes:pdf` kutadi. Hozirgi UX: foydalanuvchiga "PDF rasm sifatida yuklash"ni so'raymiz —
  /// haqiqiy PDF picker keyingi versiyada (file_picker package).
  Future<XFile?> _pickPdfPlaceholder() async {
    _toast('PDF tanlash hozircha qo‘llab-quvvatlanmaydi. Galereyadan rasm tanlang yoki bu maydonni keyin yangilang.');
    return _pickImage();
  }

  Future<void> _submit() async {
    if (_ownership == 2 && _ownershipFile == null) {
      _toast('Egalik hujjatini yuklang.');
      return;
    }
    if ((_legalType == 1 || _legalType == 2) && _legalPdf == null) {
      _toast('Yuridik hujjat (PDF) ni yuklang.');
      return;
    }
    if (_avtopark != null && !_companyOfferta) {
      _toast('Avtopark offertasini qabul qiling.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final r = await DriverApi.instance.registrationStep3(
        sessionId: widget.sessionId,
        vehicleOwnership: _ownership,
        ownershipFile: _ownershipFile,
        legalEntityType: _legalType,
        legalCertificatePdf: _legalPdf,
        companyId: _avtopark?.id,
        companyOffertaAccepted: _companyOfferta,
      );

      // Step3 yangi temp_token qaytaradi → exchange-token → refresh_token → session saqlash
      final newTemp = r.tempToken;
      if (newTemp == null || newTemp.isEmpty) {
        _toast('Server yangi token qaytarmadi.');
        setState(() => _submitting = false);
        return;
      }

      await SessionStore().saveTempRegistrationToken(newTemp);

      final ex = await const AuthApi().exchangeToken(tempToken: newTemp);
      await SessionStore().saveSession(
        refreshToken: ex.refreshToken,
        userId: ex.userId,
        userType: ex.userType ?? 'driver',
        phoneDisplay: widget.phoneDisplay,
      );

      // Driver hozir pending status'da bo'ladi — moderatsiya kutiladi.
      // Tugagandan keyin pop(true) qaytaramiz; MainShell qaytishi va pending sahifani
      // ko'rsatishi (yoki active bo'lsa to'g'ridan driver mode'ga o'tishi) o'zi hal qiladi.
      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pop(true);
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
        title: const Text('Step 3 — Egalik va yuridik holat'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: LinearProgressIndicator(value: 3 / 3),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Mashina egaligi *',
                style: Theme.of(context).textTheme.titleSmall),
            RadioListTile<int>(
              value: 1,
              groupValue: _ownership,
              title: const Text('O‘zimniki'),
              subtitle: const Text('Hujjat talab qilinmaydi'),
              onChanged: (v) => setState(() => _ownership = v ?? 1),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<int>(
              value: 2,
              groupValue: _ownership,
              title: const Text('Boshqa hujjat asosida'),
              subtitle: const Text('Dovernost yoki ijara shartnomasi'),
              onChanged: (v) => setState(() => _ownership = v ?? 1),
              contentPadding: EdgeInsets.zero,
            ),
            if (_ownership == 2)
              _fileRow('Egalik hujjati *', _ownershipFile, () async {
                final f = await _pickImage();
                if (f != null) setState(() => _ownershipFile = f);
              }),
            const Divider(height: 32),
            Text('Yuridik holat *',
                style: Theme.of(context).textTheme.titleSmall),
            RadioListTile<int>(
              value: 1,
              groupValue: _legalType,
              title: const Text('YATT'),
              subtitle: const Text('Guvohnoma PDF talab qilinadi'),
              onChanged: (v) => setState(() => _legalType = v ?? 3),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<int>(
              value: 2,
              groupValue: _legalType,
              title: const Text('O‘z-o‘zini band qilish'),
              subtitle: const Text('Guvohnoma PDF talab qilinadi'),
              onChanged: (v) => setState(() => _legalType = v ?? 3),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<int>(
              value: 3,
              groupValue: _legalType,
              title: const Text('Jismoniy shaxs'),
              subtitle: const Text('Hujjat talab qilinmaydi'),
              onChanged: (v) => setState(() => _legalType = v ?? 3),
              contentPadding: EdgeInsets.zero,
            ),
            if (_legalType == 1 || _legalType == 2)
              _fileRow('Guvohnoma (PDF) *', _legalPdf, () async {
                final f = await _pickPdfPlaceholder();
                if (f != null) setState(() => _legalPdf = f);
              }),
            const Divider(height: 32),
            Text('Avtopark tanlash (ixtiyoriy)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_loadingAvtoparks)
              const LinearProgressIndicator()
            else if (_avtoparksError != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.error_outline_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                  title: Text(_avtoparksError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                  trailing: FilledButton.tonal(onPressed: _loadAvtoparks, child: const Text('Retry')),
                ),
              )
            else
              DropdownMenu<AvtoparkItem?>(
                initialSelection: _avtopark,
                expandedInsets: EdgeInsets.zero,
                label: const Text('Avtopark'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry<AvtoparkItem?>(
                    value: null,
                    label: 'Avtoparksiz (custom driver)',
                  ),
                  ..._avtoparks.map(
                    (a) => DropdownMenuEntry<AvtoparkItem?>(value: a, label: a.name),
                  ),
                ],
                onSelected: (v) => setState(() {
                  _avtopark = v;
                  if (v == null) _companyOfferta = false;
                }),
              ),
            if (_avtopark != null) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _companyOfferta,
                onChanged: (v) => setState(() => _companyOfferta = v ?? false),
                contentPadding: EdgeInsets.zero,
                title: const Text('Avtopark offertasini qabul qilaman *'),
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: 'Tugatish',
              icon: Icons.check_rounded,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileRow(String label, XFile? f, VoidCallback onPick) {
    Widget thumb;
    if (f == null) {
      thumb = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.attach_file_rounded),
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
      trailing: IconButton(icon: const Icon(Icons.upload_file_rounded), onPressed: onPick),
    );
  }
}
