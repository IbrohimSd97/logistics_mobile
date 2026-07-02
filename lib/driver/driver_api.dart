import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api/api_exception.dart';
import '../core/api/cancel_reasons_api.dart';
import '../core/api/http_response_codec.dart';
import '../core/config/api_config.dart';
import '../core/i18n/i18n.dart';
import '../core/session/session_store.dart';
import 'driver_models.dart';

class DriverApi {
  DriverApi._();
  static final DriverApi instance = DriverApi._();

  final _session = SessionStore();

  Future<String> _requireRefresh() async {
    final t = await _session.getRefreshToken();
    if (t == null || t.isEmpty) {
      throw ApiException('Kirish sessiyasi yo‘q. Qayta kiring.');
    }
    return t;
  }

  Future<String> _requireTemp() async {
    final t = await _session.getTempRegistrationToken();
    if (t == null || t.isEmpty) {
      throw ApiException('Vaqtinchalik token yo‘q. Qayta kiring (OTP).');
    }
    return t;
  }

  Map<String, String> _jsonAuth(String token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Accept-Language': I18n.instance.code,
        'Authorization': 'Bearer $token',
      };

  Map<String, String> _multiAuth(String token) => {
        'Accept': 'application/json',
        'Accept-Language': I18n.instance.code,
        'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _decode(http.Response res) =>
      decodeJsonEnvelopeOrThrow(res);

  // ────────────────────────────── meta ──────────────────────────────

  /// GET /api/driver/registration/status (auth.refresh)
  Future<DriverRegistrationStatus> registrationStatus() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/registration/status');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Javobda data yo‘q');
    }
    return DriverRegistrationStatus.fromMap(data);
  }

  /// GET /api/driver/registration/rejects (auth.refresh)
  Future<DriverRegistrationRejects> registrationRejects() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/registration/rejects');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Javobda data yo‘q');
    }
    return DriverRegistrationRejects.fromMap(data);
  }

  // ────────────────────────────── lookups ──────────────────────────────

  /// GET /api/driver/avtoparks/lists (no auth required by routes)
  Future<List<AvtoparkItem>> avtoparksList() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/avtoparks/lists');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Accept-Language': I18n.instance.code,
    });
    final map = _decode(res);
    final list = mapListFrom(map['data']);
    return list.map(AvtoparkItem.fromMap).whereType<AvtoparkItem>().toList();
  }

  /// GET /api/driver/tariff/lists (no auth required by routes)
  Future<List<DriverTariffItem>> tariffsList() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/tariff/lists');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Accept-Language': I18n.instance.code,
    });
    final map = _decode(res);
    final list = mapListFrom(map['data']);
    return list.map(DriverTariffItem.fromMap).whereType<DriverTariffItem>().toList();
  }

  // ────────────────────────────── registration steps ──────────────────────────────

  /// POST /api/driver/registration/step1 (auth.temp, multipart)
  Future<DriverStepResult> registrationStep1({
    required String lastName,
    required String firstName,
    required String middleName,
    required String birthDate, // YYYY-MM-DD
    required String nationalId, // 14 raqamli PINFL
    required String carLicenseSeries,
    required String carLicenseNumber,
    required String carLicenseIssuedDate, // YYYY-MM-DD
    required XFile carLicenseFront,
    required XFile carLicenseBack,
    required XFile carLicenseSelfie,
  }) async {
    final token = await _requireTemp();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/driver/registration/step1');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_multiAuth(token))
      ..fields['last_name'] = lastName
      ..fields['first_name'] = firstName
      ..fields['middle_name'] = middleName
      ..fields['birth_date'] = birthDate
      ..fields['national_id'] = nationalId
      ..fields['car_license_series'] = carLicenseSeries
      ..fields['car_license_number'] = carLicenseNumber
      ..fields['car_license_issued_date'] = carLicenseIssuedDate;

    req.files.add(await _filePart('car_license_front_img', carLicenseFront));
    req.files.add(await _filePart('car_license_back_img', carLicenseBack));
    req.files.add(await _filePart('car_license_selfie_img', carLicenseSelfie));

    final res = await http.Response.fromStream(await req.send());
    final map = _decode(res);
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Javobda data yo‘q');
    }
    return DriverStepResult.fromMap(data);
  }

  /// POST /api/driver/registration/step2 (auth.temp, multipart)
  Future<DriverStepResult> registrationStep2({
    required String sessionId,
    required int tariffId,
    required String vehicleName,
    required String plateNumber,
    String? color,
    required String capacityKg,
    required String regCertSeries,
    required String regCertNumber,
    String? regCertIssuedDate,
    required bool hasTrailer,
    String? trailerPlateNumber,
    required bool projectOffertaAccepted,
    required XFile regCertFront,
    required XFile regCertBack,
    required XFile vehicleFront,
    required XFile vehicleSide,
    required XFile vehicleBack,
    XFile? trailerRegFront,
    XFile? trailerRegBack,
  }) async {
    final token = await _requireTemp();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/driver/registration/step2');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_multiAuth(token))
      ..fields['session_id'] = sessionId
      ..fields['tariff_id'] = '$tariffId'
      ..fields['vehicle_name'] = vehicleName
      ..fields['plate_number'] = plateNumber
      ..fields['capacity_kg'] = capacityKg
      ..fields['reg_certificate_series'] = regCertSeries
      ..fields['reg_certificate_number'] = regCertNumber
      ..fields['has_trailer'] = hasTrailer ? '1' : '0'
      ..fields['project_offerta_accepted'] = projectOffertaAccepted ? '1' : '0';
    if (color != null && color.isNotEmpty) req.fields['color'] = color;
    if (regCertIssuedDate != null && regCertIssuedDate.isNotEmpty) {
      req.fields['reg_certificate_issued_date'] = regCertIssuedDate;
    }
    if (hasTrailer && trailerPlateNumber != null && trailerPlateNumber.isNotEmpty) {
      req.fields['trailer_plate_number'] = trailerPlateNumber;
    }

    req.files.add(await _filePart('reg_certificate_front_img', regCertFront));
    req.files.add(await _filePart('reg_certificate_back_img', regCertBack));
    req.files.add(await _filePart('vehicle_front_img', vehicleFront));
    req.files.add(await _filePart('vehicle_side_img', vehicleSide));
    req.files.add(await _filePart('vehicle_back_img', vehicleBack));
    if (hasTrailer && trailerRegFront != null) {
      req.files.add(await _filePart('trailer_reg_certificate_front_img', trailerRegFront));
    }
    if (hasTrailer && trailerRegBack != null) {
      req.files.add(await _filePart('trailer_reg_certificate_back_img', trailerRegBack));
    }

    final res = await http.Response.fromStream(await req.send());
    final map = _decode(res);
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Javobda data yo‘q');
    }
    return DriverStepResult.fromMap(data);
  }

  /// POST /api/driver/registration/step3 (auth.temp, multipart)
  /// vehicleOwnership: 1=O'zimniki, 2=Boshqa hujjat asosida (ownershipFile required)
  /// legalEntityType: 1=YATT, 2=O'z-o'zini band, 3=Jismoniy
  Future<DriverStepResult> registrationStep3({
    required String sessionId,
    required int vehicleOwnership,
    XFile? ownershipFile,
    required int legalEntityType,
    XFile? legalCertificatePdf,
    int? companyId,
    bool companyOffertaAccepted = false,
  }) async {
    final token = await _requireTemp();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/driver/registration/step3');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_multiAuth(token))
      ..fields['session_id'] = sessionId
      ..fields['vehicle_ownership'] = '$vehicleOwnership'
      ..fields['legal_entity_type'] = '$legalEntityType'
      ..fields['company_offerta_accepted'] = companyOffertaAccepted ? '1' : '0';

    if (companyId != null) {
      req.fields['company_id'] = '$companyId';
    }

    if (vehicleOwnership == 2 && ownershipFile != null) {
      req.files.add(await _filePart('ownership_contract_file', ownershipFile));
    }
    if ((legalEntityType == 1 || legalEntityType == 2) && legalCertificatePdf != null) {
      req.files.add(
        await _filePart(
          'legal_certificate_pdf',
          legalCertificatePdf,
          contentTypeOverride: MediaType('application', 'pdf'),
        ),
      );
    }

    final res = await http.Response.fromStream(await req.send());
    final map = _decode(res);
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Javobda data yo‘q');
    }
    return DriverStepResult.fromMap(data);
  }

  // ────────────────────────────── cargo preferences ──────────────────────────────

  /// POST /api/driver/cargo-preferences — qaysi yuk turlarini olishini saqlash + onlayn boshlangan vaqtini qayd qilish.
  Future<void> setCargoPreferences(List<int> cargoTypeIds) async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/cargo-preferences');
    final res = await http.post(
      url,
      headers: _jsonAuth(token),
      body: jsonEncode({'cargo_type_ids': cargoTypeIds}),
    );
    _decode(res);
  }

  /// DELETE /api/driver/cargo-preferences — oflayn (yuk olmaydi).
  Future<void> clearCargoPreferences() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/cargo-preferences');
    final res = await http.delete(url, headers: _jsonAuth(token));
    _decode(res);
  }

  /// GET /api/driver/me/status — driver online holati va saqlangan cargo turlari.
  /// Mobile state'ni server bilan sinxronlash uchun (masalan, buyurtma
  /// yakunlangandan keyin backend driverni avtomat online qilgan bo'ladi).
  Future<DriverStatusSnapshot> driverStatus() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/me/status');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      return const DriverStatusSnapshot(isOnline: false, cargoTypeIds: []);
    }
    return DriverStatusSnapshot.fromMap(data);
  }

  // ────────────────────────────── location ──────────────────────────────

  /// POST /api/driver/current-location (auth.refresh)
  Future<void> saveLocation({required double latitude, required double longitude}) async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/current-location');
    final res = await http
        .post(
          url,
          headers: _jsonAuth(token),
          body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
        )
        .timeout(const Duration(seconds: 10));
    _decode(res);
  }

  // ────────────────────────────── wallet ──────────────────────────────

  /// GET /api/driver/wallet
  Future<DriverWalletSnapshot> wallet() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/wallet');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    return DriverWalletSnapshot.fromMap(map['data']) ?? const DriverWalletSnapshot();
  }

  /// GET /api/driver/wallet/fleet-info — agar driver avtoparkka biriktirilgan
  /// bo'lsa avtopark hamyon balansi va shu driver tushgan tushumlar tarixi.
  Future<DriverFleetInfo?> fleetInfo() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/wallet/fleet-info');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    final data = map['data'];
    if (data is! Map<String, dynamic>) return null;
    return DriverFleetInfo.fromMap(data);
  }

  /// GET /api/driver/wallet/transactions
  Future<List<DriverWalletTx>> walletTransactions() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/wallet/transactions');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    final list = mapListFrom(map['data']);
    return list.map(DriverWalletTx.fromMap).toList();
  }

  // ────────────────────────────── orders ──────────────────────────────

  /// GET /api/driver/orders/active-list (5km radius, capacity-aware)
  Future<List<DriverOrder>> activeOrders() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/active-list');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    final list = mapListFrom(map['data']);
    return list.map(DriverOrder.fromMap).whereType<DriverOrder>().toList();
  }

  /// GET /api/driver/orders/scheduled-list — rejali buyurtmalar (radius'siz).
  /// Faqat kelajakdagi olib ketish vaqti bo'lgan va driver cargo preferences'iga
  /// mos orderlarni qaytaradi, eng yaqin vaqtli birinchi.
  Future<List<DriverOrder>> scheduledOrders() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/scheduled-list');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    final list = mapListFrom(map['data']);
    return list.map(DriverOrder.fromMap).whereType<DriverOrder>().toList();
  }

  /// GET /api/driver/orders/archive-list
  Future<List<DriverOrder>> archiveOrders() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/archive-list');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    final list = mapListFrom(map['data']);
    return list.map(DriverOrder.fromMap).whereType<DriverOrder>().toList();
  }

  /// GET /api/driver/orders/current-order — driver hozir qabul qilgan order
  Future<DriverOrder?> currentOrder() async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/current-order');
    final res = await http.get(url, headers: _jsonAuth(token));
    final map = _decode(res);
    final data = map['data'];
    if (data is! Map<String, dynamic>) return null;
    return DriverOrder.fromMap(data);
  }

  /// POST /api/driver/orders/accept — accept_lat/lng saqlanadi
  Future<void> acceptOrder({
    required int orderId,
    required double acceptLat,
    required double acceptLng,
  }) async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/accept');
    final res = await http.post(
      url,
      headers: _jsonAuth(token),
      body: jsonEncode({
        'order_id': orderId,
        'accept_lat': acceptLat,
        'accept_lng': acceptLng,
      }),
    );
    _decode(res);
  }

  Future<void> _statusEndpoint(String path, int orderId) async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/$path');
    final res = await http.post(
      url,
      headers: _jsonAuth(token),
      body: jsonEncode({'order_id': orderId}),
    );
    _decode(res);
  }

  Future<void> arrivedPickup(int orderId) => _statusEndpoint('arrived-pickup', orderId);

  Future<void> inTransit(int orderId) => _statusEndpoint('in-transit', orderId);

  Future<void> arrivedDelivery(int orderId) => _statusEndpoint('arrived-delivery', orderId);

  Future<void> delivered(int orderId) => _statusEndpoint('delivered', orderId);

  /// POST /api/driver/orders/cancel
  ///
  /// `cancelReasonId` — `cancel_reasons` jadvalidan tanlangan ID (majburiy).
  /// `customText` — "Boshqa" tanlanganda (`is_other=true`) majburiy izoh,
  /// boshqa sabablar uchun e'tiborga olinmaydi.
  Future<void> cancelOrder({required int orderId, required int cancelReasonId, String? customText}) async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/cancel');
    final body = <String, dynamic>{
      'order_id': orderId,
      'cancel_reason_id': cancelReasonId,
    };
    if (customText != null && customText.trim().isNotEmpty) {
      body['cancel_reason'] = customText.trim();
    }
    final res = await http.post(
      url,
      headers: _jsonAuth(token),
      body: jsonEncode(body),
    );
    _decode(res);
  }

  /// GET /api/driver/cancel-reasons — cancel dialogi catalog (cache'lanadi).
  List<CancelReason>? _cancelReasonsCache;
  Future<List<CancelReason>> cancelReasons({bool reload = false}) async {
    if (!reload && _cancelReasonsCache != null) return _cancelReasonsCache!;
    final api = CancelReasonsApi.driver(tokenFn: _requireRefresh);
    final list = await api.list();
    _cancelReasonsCache = list;
    return list;
  }

  /// GET /api/driver/orders/{orderId}/documents
  Future<Map<String, dynamic>> orderDocuments(int orderId) async {
    final token = await _requireRefresh();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/$orderId/documents');
    final res = await http.get(url, headers: _jsonAuth(token));
    return _decode(res);
  }

  // ────────────────────────────── helpers ──────────────────────────────

  MediaType _guessMediaType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.heic')) return MediaType('image', 'heic');
    if (lower.endsWith('.heif')) return MediaType('image', 'heif');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return MediaType('image', 'jpeg');
  }

  Future<http.MultipartFile> _filePart(
    String field,
    XFile f, {
    MediaType? contentTypeOverride,
  }) async {
    final mt = contentTypeOverride ?? _guessMediaType(f.name);
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
}
