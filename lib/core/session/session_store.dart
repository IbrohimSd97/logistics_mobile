import 'package:shared_preferences/shared_preferences.dart';

/// Mobil API: `exchange-token` dan keyin JWT refresh token saqlanadi (TZ 3.0).
/// Jismoniy ro‘yxatdan o‘tish: `POST /api/customer/registration/physical` uchun **temp** token (Postman).
class SessionStore {
  static const _kRefresh = 'alix_refresh_token';
  static const _kUserId = 'alix_user_id';
  static const _kUserType = 'alix_user_type';
  static const _kPhone = 'alix_phone_display';
  static const _kTempReg = 'alix_customer_temp_registration_token';

  Future<void> saveSession({
    required String refreshToken,
    required int userId,
    required String userType,
    required String phoneDisplay,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRefresh, refreshToken);
    await p.setInt(_kUserId, userId);
    await p.setString(_kUserType, userType);
    await p.setString(_kPhone, phoneDisplay);
    await p.remove(_kTempReg);
  }

  /// Refresh token bo‘lmasa ham telefon (jismoniy ro‘yxatdan o‘tish / UI uchun).
  Future<void> savePhoneDisplayOnly(String phoneDisplay) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPhone, phoneDisplay);
  }

  Future<void> saveTempRegistrationToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTempReg, token);
  }

  Future<String?> getTempRegistrationToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTempReg);
  }

  Future<void> clearTempRegistrationToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTempReg);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kRefresh);
    await p.remove(_kUserId);
    await p.remove(_kUserType);
    await p.remove(_kPhone);
    await p.remove(_kTempReg);
  }

  Future<String?> getRefreshToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kRefresh);
  }

  Future<int?> getUserId() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_kUserId);
    if (v == null || v == 0) return null;
    return v;
  }

  Future<String?> getPhoneDisplay() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kPhone);
  }
}
