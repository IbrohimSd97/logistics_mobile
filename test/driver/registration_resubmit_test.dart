import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mening_ilovam/driver/driver_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rad etilgandan keyin qayta yuborish: o'zgarmagan rasm multipart'ga
/// qo'shilmaydi (server mavjud faylni saqlab qoladi), yangisi esa qo'shiladi.
void main() {
  late List<String> sentFiles;
  late Map<String, String> sentFields;

  setUp(() {
    SharedPreferences.setMockInitialValues({'alix_customer_temp_registration_token': 'tmp-token'});
    sentFiles = [];
    sentFields = {};
  });

  Future<http.Response> handler(http.ByteStream bodyStream) async {
    // Fayl baytlari UTF-8 emas — latin1 bilan o'qiymiz (sarlavhalar ASCII).
    final body = latin1.decode(await bodyStream.toBytes());
    sentFiles = RegExp(r'name="([a-z_]+)"; filename=').allMatches(body).map((m) => m.group(1)!).toList();
    for (final m in RegExp(r'name="([a-z_]+)"\r\n\r\n([^\r]*)').allMatches(body)) {
      sentFields[m.group(1)!] = m.group(2)!;
    }
    return http.Response(
      jsonEncode({'success': true, 'data': {'session_id': 's-1', 'next_step': 2}}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<T> withClient<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => MockClient.streaming((_, bodyStream) async {
            final res = await handler(bodyStream);
            return http.StreamedResponse(Stream.value(res.bodyBytes), res.statusCode,
                headers: res.headers);
          }));

  XFile tmpImage(String name) {
    final f = File('${Directory.systemTemp.createTempSync('reg_').path}/$name')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    return XFile(f.path);
  }

  test('step1: only newly picked images are sent', () async {
    await withClient(() => DriverApi.instance.registrationStep1(
          lastName: 'Karimov',
          firstName: 'Aziz',
          middleName: 'A',
          birthDate: '1990-01-01',
          nationalId: '12345678901234',
          carLicenseSeries: 'AF',
          carLicenseNumber: '1234567',
          carLicenseIssuedDate: '2015-01-01',
          carLicenseSelfie: tmpImage('selfie.jpg'),
        ));

    expect(sentFiles, ['car_license_selfie_img']);
    expect(sentFields['last_name'], 'Karimov');
  });

  test('step2: unchanged vehicle photos are omitted', () async {
    await withClient(() => DriverApi.instance.registrationStep2(
          sessionId: 's-1',
          tariffId: 1,
          vehicleName: 'Isuzu',
          plateNumber: '01A123BC',
          capacityKg: '5000',
          regCertSeries: 'AAF',
          regCertNumber: '123',
          hasTrailer: false,
          projectOffertaAccepted: true,
          vehicleSide: tmpImage('side.jpg'),
        ));

    expect(sentFiles, ['vehicle_side_img']);
  });
}
