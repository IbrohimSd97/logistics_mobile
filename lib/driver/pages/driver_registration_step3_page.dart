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
import 'driver_pending_page.dart';

class DriverRegistrationStep3Page extends StatefulWidget {
  const DriverRegistrationStep3Page({
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
  State<DriverRegistrationStep3Page> createState() => _DriverRegistrationStep3PageState();
}

class _DriverRegistrationStep3PageState extends State<DriverRegistrationStep3Page>
    with I18nObserverMixin<DriverRegistrationStep3Page> {
  /// 1=O'zimniki, 2=Boshqa hujjat asosida
  int _ownership = 1;
  XFile? _ownershipFile;
  String? _ownershipUrl; // server'dagi mavjud hujjat (prefill)

  /// 1=YATT, 2=O'z-o'zini band qilish, 3=Jismoniy shaxs
  int _legalType = 3;
  XFile? _legalPdf;
  String? _legalUrl; // server'dagi mavjud hujjat (prefill)

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
    // Prefill: oldin yuborilgan tanlovlar va mavjud hujjatlar.
    if (widget.data?.step3 != null) {
      final own = widget.data!.i3('vehicle_ownership');
      if (own == 1 || own == 2) _ownership = own!;
      final lt = widget.data!.i3('legal_entity_type');
      if (lt == 1 || lt == 2 || lt == 3) _legalType = lt!;
      _ownershipUrl = widget.data!.s3('ownership_contract_img_url');
      _legalUrl = widget.data!.s3('legal_certificate_img_url');
    }
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
        // Prefill: oldin tanlangan avtoparkni id bo'yicha tiklaymiz.
        final cid = widget.data?.i3('company_id');
        if (_avtopark == null && cid != null) {
          for (final a in list) {
            if (a.id == cid) {
              _avtopark = a;
              break;
            }
          }
        }
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

  String? _fieldError(String field) {
    final errs = widget.rejects?.step3Errors;
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
    // Hujjat majburiy: yangi tanlangan yoki server'da mavjud (URL) bo'lsa yetarli.
    if (_ownership == 2 &&
        _ownershipFile == null &&
        (_ownershipUrl ?? '').isEmpty) {
      _toast(I18n.t('driver.reg.upload_ownership_doc'));
      return;
    }
    if ((_legalType == 1 || _legalType == 2) &&
        _legalPdf == null &&
        (_legalUrl ?? '').isEmpty) {
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
      // Foydalanuvchi qayta tanlamagan hujjatlarni mavjud URL'dan yuklab olamiz.
      XFile? ownershipFile = _ownershipFile;
      if (_ownership == 2 &&
          ownershipFile == null &&
          (_ownershipUrl ?? '').isNotEmpty) {
        ownershipFile =
            await DriverApi.instance.downloadToTempFile(_ownershipUrl!);
      }
      XFile? legalPdf = _legalPdf;
      if ((_legalType == 1 || _legalType == 2) &&
          legalPdf == null &&
          (_legalUrl ?? '').isNotEmpty) {
        legalPdf = await DriverApi.instance.downloadToTempFile(_legalUrl!);
      }
      final r = await DriverApi.instance.registrationStep3(
        sessionId: widget.sessionId,
        vehicleOwnership: _ownership,
        ownershipFile: ownershipFile,
        legalEntityType: _legalType,
        legalCertificatePdf: legalPdf,
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

      // Registratsiya yakunlandi — driver endi PENDING (moderatsiya kutilmoqda).
      // To'g'ridan-to'g'ri driver kutish sahifasiga o'tamiz va butun stack'ni
      // tozalaymiz — shunda customer sahifaga qaytib ketmaydi. Keyinchalik
      // logout/qayta kirishda ham login routing shu holatga qarab yo'naltiradi.
      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => DriverPendingPage(
            phoneDisplay: widget.phoneDisplay,
            userId: ex.userId,
          ),
        ),
        (_) => false,
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
              _fileRow(I18n.t('driver.reg.ownership_doc'), _ownershipFile,
                  _ownershipUrl, () async {
                final f = await _pickImage();
                if (f != null) setState(() => _ownershipFile = f);
              }),
            _errorNote('ownership_contract_img'),
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
              _fileRow(I18n.t('driver.reg.legal_pdf'), _legalPdf, _legalUrl,
                  () async {
                final f = await _pickPdfPlaceholder();
                if (f != null) setState(() => _legalPdf = f);
              }),
            _errorNote('legal_certificate_img'),
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

  Widget _fileRow(String label, XFile? f, String? existingUrl, VoidCallback onPick) {
    Widget thumb;
    final hasExisting = f == null && (existingUrl ?? '').isNotEmpty;
    if (hasExisting) {
      // Mavjud hujjat (PDF bo'lishi mumkin) — rasm sifatida ko'rsatmaymiz,
      // "biriktirilgan hujjat" belgisi.
      thumb = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.description_rounded,
            color: Theme.of(context).colorScheme.onPrimaryContainer),
      );
    } else if (f == null) {
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
    final subtitle = f?.name ??
        (hasExisting
            ? I18n.t('driver.reg.existing_image')
            : I18n.t('driver.reg.not_picked'));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: thumb,
      title: Text(label),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(icon: const Icon(Icons.upload_file_rounded), onPressed: onPick),
    );
  }
}
