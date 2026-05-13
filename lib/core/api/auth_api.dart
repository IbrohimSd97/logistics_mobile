import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';
import 'http_response_codec.dart';

class OtpSendResult {
  const OtpSendResult({
    required this.sent,
    this.expiresInSec,
    this.devCode,
  });

  final bool sent;
  final int? expiresInSec;
  final String? devCode;
}

class OtpVerifyResult {
  const OtpVerifyResult({
    required this.isVerified,
    required this.tempToken,
    required this.userType,
    required this.userId,
  });

  final bool isVerified;
  final String tempToken;
  final String userType;
  final int userId;
}

class ExchangeTokenResult {
  const ExchangeTokenResult({
    required this.refreshToken,
    required this.userId,
    this.role,
    this.userType,
    this.meta,
  });

  final String refreshToken;
  final int userId;
  final int? role;
  final String? userType;
  final Map<String, dynamic>? meta;
}

String authDeviceInfo() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    default:
      return 'flutter';
  }
}

class AuthApi {
  const AuthApi();

  static const _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<OtpSendResult> otpSend(String phoneNumber) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/otp-send');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'phone_number': phoneNumber}),
    );
    final map = decodeJsonEnvelopeOrThrow(res);

    final data = map['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const OtpSendResult(sent: true);
    }
    return OtpSendResult(
      sent: data['sent'] as bool? ?? true,
      expiresInSec: data['expires_in_sec'] as int?,
      devCode: data['dev_code'] as String?,
    );
  }

  Future<OtpVerifyResult> otpVerify({
    required String phoneNumber,
    required String code,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/otp-verify');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'phone_number': phoneNumber,
        'code': code,
        'device_info': authDeviceInfo(),
      }),
    );
    final map = decodeJsonEnvelopeOrThrow(res);

    final data = map['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('Javobda data yo‘q');
    }
    // Backend contract (2026-05): temp token may be `data.temp_token`.
    // Backward-compat: accept legacy `data.access_token`.
    final token = (data['temp_token'] ?? data['access_token']) as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Temp token kelmadi');
    }
    return OtpVerifyResult(
      isVerified: _asBool(data['is_verified']),
      tempToken: token,
      userType: data['user_type']?.toString() ?? 'customer',
      userId: _asInt(data['user_id']),
    );
  }

  /// POST /api/auth/switch-role (auth.refresh)
  /// Foydalanuvchi rejimini ('customer' yoki 'driver') backend'ga saqlash.
  /// Mos profil bo'lmasa server xato qaytaradi.
  Future<void> switchRole({
    required String refreshToken,
    required String role,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/switch-role');
    final res = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $refreshToken',
      },
      body: jsonEncode({'role': role}),
    );
    decodeJsonEnvelopeOrThrow(res);
  }

  /// POST /api/auth/issue-temp-token (auth.refresh)
  /// Aktiv refresh-tokenli foydalanuvchi yangi temp_token oladi (driver bo'lish uchun OTP qayta so'ralmasin).
  Future<String> issueTempTokenFromRefresh(String refreshToken) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/issue-temp-token');
    final res = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $refreshToken',
      },
    );
    final map = decodeJsonEnvelopeOrThrow(res);
    final data = map['data'] as Map<String, dynamic>?;
    final tt = data?['temp_token']?.toString();
    if (tt == null || tt.isEmpty) {
      throw ApiException('Temp token kelmadi');
    }
    return tt;
  }

  Future<ExchangeTokenResult> exchangeToken({
    required String tempToken,
    String? firebaseToken,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/exchange-token');
    final body = <String, dynamic>{
      'temp_token': tempToken,
      'firebase_token': firebaseToken ?? '',
    };
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(body),
    );
    final map = decodeJsonEnvelopeOrThrow(res);

    final data = map['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('Javobda data yo‘q');
    }
    // Backend contract (2026-05): refresh token is `data.refresh_token`.
    // Backward-compat: accept legacy `data.access_token`.
    final token = (data['refresh_token'] ?? data['access_token']) as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Refresh token kelmadi');
    }
    Map<String, dynamic>? meta;
    final rawMeta = data['meta'];
    if (rawMeta is Map<String, dynamic>) meta = rawMeta;
    final userType = (data['user_type']?.toString()) ?? (meta?['user_type']?.toString());

    return ExchangeTokenResult(
      refreshToken: token,
      userId: _asInt(data['user_id']),
      role: data['role'] as int?,
      userType: userType,
      meta: meta,
    );
  }

  bool _asBool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
