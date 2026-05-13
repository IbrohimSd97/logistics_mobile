import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/auth_api.dart';
import '../../core/api/http_response_codec.dart';
import '../../core/config/api_config.dart';
import '../../core/session/session_store.dart';
import '../../core/widgets/gradient_button.dart';

/// `POST /api/customer/registration/physical` (multipart, **temp** token).
class CustomerPhysicalRegistrationPage extends StatefulWidget {
  const CustomerPhysicalRegistrationPage({
    super.key,
    required this.phoneDisplay,
  });

  final String phoneDisplay;

  @override
  State<CustomerPhysicalRegistrationPage> createState() => _CustomerPhysicalRegistrationPageState();
}

class _CustomerPhysicalRegistrationPageState extends State<CustomerPhysicalRegistrationPage> {
  late final TextEditingController _phoneCtrl;
  final _last = TextEditingController();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  DateTime? _birthDate;
  int _docType = 1;
  bool _offerta = false;
  bool _loading = false;

  XFile? _front;
  XFile? _back;
  XFile? _selfie;

  final _picker = ImagePicker();

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.phoneDisplay);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _last.dispose();
    _first.dispose();
    _middle.dispose();
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
      helpText: 'Tug‘ilgan sana',
    );
    if (!mounted || picked == null) return;
    setState(() => _birthDate = picked);
  }

  MediaType _guessMediaType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.heic')) return MediaType('image', 'heic');
    if (lower.endsWith('.heif')) return MediaType('image', 'heif');
    return MediaType('image', 'jpeg');
  }

  Future<http.MultipartFile> _part(String field, XFile f) async {
    final mt = _guessMediaType(f.name);
    if (kIsWeb) {
      final bytes = await f.readAsBytes();
      return http.MultipartFile.fromBytes(field, bytes, filename: f.name, contentType: mt);
    }
    final length = await File(f.path).length();
    return http.MultipartFile(
      field,
      File(f.path).openRead(),
      length,
      filename: f.name,
      contentType: mt,
    );
  }

  Future<void> _submit() async {
    if (!_offerta) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offertani qabul qiling.')),
      );
      return;
    }
    if (_last.text.trim().isEmpty ||
        _first.text.trim().isEmpty ||
        _middle.text.trim().isEmpty ||
        _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcha maydonlarni to‘ldiring.')),
      );
      return;
    }
    if (_front == null || _back == null || _selfie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('3 ta rasmni yuklang.')),
      );
      return;
    }

    final temp = await SessionStore().getTempRegistrationToken();
    if (!mounted) return;
    if (temp == null || temp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temp token yo‘q. Qayta kiring (OTP).')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/customer/registration/physical');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $temp'
        ..fields['last_name'] = _last.text.trim()
        ..fields['first_name'] = _first.text.trim()
        ..fields['middle_name'] = _middle.text.trim()
        ..fields['birth_date'] = _fmtDate(_birthDate!)
        ..fields['phone_number'] = _phoneCtrl.text.replaceAll(RegExp(r'\s'), '')
        ..fields['id_document_type'] = '$_docType'
        ..fields['offerta_accepted'] = '1';

      req.files.add(await _part('id_doc_front_img', _front!));
      req.files.add(await _part('id_doc_back_img', _back!));
      req.files.add(await _part('id_doc_selfie_img', _selfie!));

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      final map = decodeJsonEnvelopeOrThrow(res);

      final newTemp = map['temp_token'] as String? ??
          (map['data'] is Map ? (map['data'] as Map)['temp_token']?.toString() : null);

      if (newTemp == null || newTemp.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Ariza yuborildi, lekin server sessiya tokenini qaytarmadi. Iltimos, qayta kiring.',
          )),
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
          SnackBar(content: Text('Sessiya ochilmadi: ${e.firstFieldMessage}. Qayta urinib ko‘ring.')),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarmoq xatosi: $e')),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ro‘yxatdan o‘tish muvaffaqiyatli.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.firstFieldMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
    }
  }

  Future<XFile?> _pickFromSheet({required bool preferCamera}) async {
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
      preferredCameraDevice: preferCamera ? CameraDevice.front : CameraDevice.rear,
    );
  }

  Future<void> _pickFront() async {
    final f = await _pickFromSheet(preferCamera: false);
    if (!mounted || f == null) return;
    setState(() => _front = f);
  }

  Future<void> _pickBack() async {
    final f = await _pickFromSheet(preferCamera: false);
    if (!mounted || f == null) return;
    setState(() => _back = f);
  }

  Future<void> _pickSelfie() async {
    final f = await _pickFromSheet(preferCamera: true);
    if (!mounted || f == null) return;
    setState(() => _selfie = f);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jismoniy ro‘yxatdan o‘tish')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Passport yoki haydovchilik guvohnomasi va offerta talab qilinadi.', style: TextStyle(height: 1.35)),
            const SizedBox(height: 16),
            TextField(controller: _last, decoration: const InputDecoration(labelText: 'Familiya *')),
            TextField(controller: _first, decoration: const InputDecoration(labelText: 'Ism *')),
            TextField(controller: _middle, decoration: const InputDecoration(labelText: 'Otasining ismi *')),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickBirthDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tug‘ilgan sana *',
                  suffixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(_birthDate == null ? 'Tanlanmagan' : _fmtDate(_birthDate!)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
            const SizedBox(height: 8),
            DropdownMenu<int>(
              initialSelection: _docType,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Hujjat turi *'),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 1, label: 'Passport'),
                DropdownMenuEntry(value: 2, label: 'Haydovchilik guvohnomasi'),
              ],
              onSelected: (v) => setState(() => _docType = v ?? 1),
            ),
            const SizedBox(height: 12),
            _imgRow('Old tomon', _front, _pickFront),
            _imgRow('Orqa tomon', _back, _pickBack),
            _imgRow('Selfi', _selfie, _pickSelfie),
            CheckboxListTile(
              value: _offerta,
              onChanged: (v) => setState(() => _offerta = v ?? false),
              title: const Text('Offertani o‘qidim va qabul qilaman *'),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Yuborish',
              icon: Icons.send_rounded,
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgRow(String label, XFile? file, VoidCallback onPick) {
    Widget thumb;
    if (file == null) {
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
        child: Image.network(file.path, width: 56, height: 56, fit: BoxFit.cover),
      );
    } else {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(file.path), width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    return ListTile(
      leading: thumb,
      title: Text(label),
      subtitle: Text(file?.name ?? 'Tanlanmagan'),
      trailing: IconButton(icon: const Icon(Icons.photo_camera_outlined), onPressed: onPick),
    );
  }
}
