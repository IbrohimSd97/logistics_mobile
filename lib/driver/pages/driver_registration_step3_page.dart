import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/auth_api.dart';
import '../../core/config/app_links.dart';
import '../../core/i18n/i18n.dart';
import '../../core/session/session_store.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/offerta_link.dart';
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

class _DriverRegistrationStep3PageState extends State<DriverRegistrationStep3Page>
    with I18nObserverMixin<DriverRegistrationStep3Page> {
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
        _avtoparksError = I18n.t('driver.reg.network_error_label', {'msg': '$e'});
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
            title: Text(I18n.t('driver.reg.camera')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(I18n.t('driver.reg.gallery')),
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
    _toast(I18n.t('driver.reg.pdf_not_supported_yet'));
    return _pickImage();
  }

  Future<void> _submit() async {
    if (_ownership == 2 && _ownershipFile == null) {
      _toast(I18n.t('driver.reg.upload_ownership_doc'));
      return;
    }
    if ((_legalType == 1 || _legalType == 2) && _legalPdf == null) {
      _toast(I18n.t('driver.reg.upload_legal_pdf'));
      return;
    }
    if (_avtopark == null) {
      _toast(I18n.t('driver.reg.select_avtopark'));
      return;
    }
    if (!_companyOfferta) {
      _toast(I18n.t('driver.reg.accept_avtopark_offerta'));
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
        _toast(I18n.t('driver.reg.server_no_token'));
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
      _toast(I18n.t('driver.reg.network_error_label', {'msg': '$e'}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('driver.reg.step3_appbar')),
        actions: [
          IconButton(
            tooltip: I18n.t('common.refresh'),
            icon: _loadingAvtoparks
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: (_submitting || _loadingAvtoparks) ? null : _loadAvtoparks,
          ),
        ],
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
            Text(I18n.t('driver.reg.ownership_title'),
                style: Theme.of(context).textTheme.titleSmall),
            RadioListTile<int>(
              value: 1,
              groupValue: _ownership,
              title: Text(I18n.t('driver.reg.ownership_own')),
              subtitle: Text(I18n.t('driver.reg.ownership_own_subtitle')),
              onChanged: (v) => setState(() => _ownership = v ?? 1),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<int>(
              value: 2,
              groupValue: _ownership,
              title: Text(I18n.t('driver.reg.ownership_other')),
              subtitle: Text(I18n.t('driver.reg.ownership_other_subtitle')),
              onChanged: (v) => setState(() => _ownership = v ?? 1),
              contentPadding: EdgeInsets.zero,
            ),
            if (_ownership == 2)
              _fileRow(I18n.t('driver.reg.ownership_doc'), _ownershipFile, () async {
                final f = await _pickImage();
                if (f != null) setState(() => _ownershipFile = f);
              }),
            const Divider(height: 32),
            Text(I18n.t('driver.reg.legal_title'),
                style: Theme.of(context).textTheme.titleSmall),
            RadioListTile<int>(
              value: 1,
              groupValue: _legalType,
              title: Text(I18n.t('driver.reg.legal_yatt')),
              subtitle: Text(I18n.t('driver.reg.legal_yatt_subtitle')),
              onChanged: (v) => setState(() => _legalType = v ?? 3),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<int>(
              value: 2,
              groupValue: _legalType,
              title: Text(I18n.t('driver.reg.legal_self_employed')),
              subtitle: Text(I18n.t('driver.reg.legal_self_employed_subtitle')),
              onChanged: (v) => setState(() => _legalType = v ?? 3),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<int>(
              value: 3,
              groupValue: _legalType,
              title: Text(I18n.t('driver.reg.legal_individual')),
              subtitle: Text(I18n.t('driver.reg.legal_individual_subtitle')),
              onChanged: (v) => setState(() => _legalType = v ?? 3),
              contentPadding: EdgeInsets.zero,
            ),
            if (_legalType == 1 || _legalType == 2)
              _fileRow(I18n.t('driver.reg.legal_pdf'), _legalPdf, () async {
                final f = await _pickPdfPlaceholder();
                if (f != null) setState(() => _legalPdf = f);
              }),
            const Divider(height: 32),
            Text(I18n.t('driver.reg.avtopark_title'),
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
                  trailing: FilledButton.tonal(onPressed: _loadAvtoparks, child: Text(I18n.t('common.retry_short'))),
                ),
              )
            else
              DropdownMenu<AvtoparkItem?>(
                initialSelection: _avtopark,
                expandedInsets: EdgeInsets.zero,
                label: Text(I18n.t('driver.reg.avtopark_label')),
                // Avtopark tanlash MAJBURIY — "avtoparksiz" varianti olib tashlandi.
                dropdownMenuEntries: [
                  ..._avtoparks.map(
                    (a) => DropdownMenuEntry<AvtoparkItem?>(value: a, label: a.name),
                  ),
                ],
                onSelected: (v) => setState(() => _avtopark = v),
              ),
            if (_avtopark != null) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _companyOfferta,
                onChanged: (v) => setState(() => _companyOfferta = v ?? false),
                contentPadding: EdgeInsets.zero,
                title: OffertaCheckboxTitle(
                  text: I18n.t('driver.reg.avtopark_offerta'),
                  url: AppLinks.avtoparkOffertaUrl,
                ),
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: I18n.t('driver.reg.finish_short'),
              icon: Icons.check_rounded,
              loading: _submitting,
              // Offerta tasdiqlanmaguncha tugma o'chiq (barcha joyda bir xil xulq).
              onPressed: (_submitting || _avtopark == null || !_companyOfferta)
                  ? null
                  : _submit,
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
      subtitle: Text(f?.name ?? I18n.t('driver.reg.not_picked'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(icon: const Icon(Icons.upload_file_rounded), onPressed: onPick),
    );
  }
}
