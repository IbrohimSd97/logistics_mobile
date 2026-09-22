import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_ilovam/core/i18n/i18n.dart';
import 'package:mening_ilovam/driver/pages/driver_registration_step3_page.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Guvohnoma yuklash FAQAT PDF tanlashi kerak.
///
/// Backend `legal_certificate_pdf` maydonida `mimes:pdf` talab qiladi, ya'ni
/// kameradan olingan rasm 422 bilan qaytadi. Shuning uchun bu maydonda
/// kamera/galereya tanlovi umuman chiqmasligi shart.
void main() {
  late _FakeFilePicker picker;

  setUp(() {
    picker = _FakeFilePicker();
    FilePickerPlatform.instance = picker;
  });

  Future<void> openStep3(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DriverRegistrationStep3Page(
        sessionId: 'test-session',
        phoneDisplay: '+998 90 000 00 00',
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('guvohnoma tugmasi kamera tanlovini ochmaydi', (tester) async {
    await openStep3(tester);

    await tester.tap(find.text(I18n.t('driver.reg.legal_pdf')));
    await tester.pump(const Duration(milliseconds: 300));

    // Rasm tanlash varag'i (kamera / galereya) chiqmasligi kerak.
    expect(find.text(I18n.t('driver.reg.camera')), findsNothing);
    expect(find.text(I18n.t('driver.reg.gallery')), findsNothing);
  });

  testWidgets('faqat pdf kengaytmasi so\'raladi', (tester) async {
    await openStep3(tester);

    await tester.tap(find.text(I18n.t('driver.reg.legal_pdf')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(picker.calls, hasLength(1));
    expect(picker.calls.single.type, FileType.custom);
    expect(picker.calls.single.allowedExtensions, ['pdf']);
  });

  testWidgets('pdf bo\'lmagan fayl rad etiladi', (tester) async {
    // Fayl menejeri filtrni e'tiborsiz qoldirgan holat.
    picker.result = _FakePlatformFile('skan.jpg', 1024);
    await openStep3(tester);

    await tester.tap(find.text(I18n.t('driver.reg.legal_pdf')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(I18n.t('driver.reg.pdf_only')), findsOneWidget);
  });

  testWidgets('10 MB dan katta fayl rad etiladi', (tester) async {
    picker.result = _FakePlatformFile('guvohnoma.pdf', 11 * 1024 * 1024);
    await openStep3(tester);

    await tester.tap(find.text(I18n.t('driver.reg.legal_pdf')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(I18n.t('driver.reg.file_too_large')), findsOneWidget);
  });
}

class _PickCall {
  const _PickCall(this.type, this.allowedExtensions);

  final FileType type;
  final List<String>? allowedExtensions;
}

class _FakeFilePicker extends FilePickerPlatform with MockPlatformInterfaceMixin {
  final List<_PickCall> calls = [];

  /// Foydalanuvchi tanlagan fayl; `null` — bekor qilingan.
  PlatformFile? result;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls.add(_PickCall(type, allowedExtensions));
    return result;
  }
}

final class _FakePlatformFile extends PlatformFile {
  _FakePlatformFile(this.name, this._size);

  @override
  final String name;

  final int _size;

  @override
  Uri get uri => Uri.file('/tmp/$name');

  @override
  XFile get xFile => XFile('/tmp/$name', name: name);

  @override
  int? lengthSync() => _size;

  @override
  Future<int?> length() async => _size;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}
