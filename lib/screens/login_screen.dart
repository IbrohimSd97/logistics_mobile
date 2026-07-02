import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/api_exception.dart';
import '../core/api/auth_api.dart';
import '../core/config/api_config.dart';
import '../core/i18n/i18n.dart';
import '../core/session/session_store.dart';
import '../core/theme/app_palette.dart';
import '../core/util/network_error_message.dart';
import '../core/util/phone_util.dart';
import '../driver/driver_api.dart';
import '../driver/driver_models.dart';
import '../driver/pages/driver_failed_page.dart';
import '../driver/pages/driver_pending_page.dart';
import '../driver/pages/driver_rejected_page.dart';
import 'main_shell.dart';

// Palitra `core/theme/app_palette.dart` ga ko'chirildi (AppPalette).

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with I18nObserverMixin<LoginScreen> {
  static const _auth = AuthApi();
  final _session = SessionStore();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  bool _otpSent = false;
  bool _loading = false;
  /// `true` — avval ro‘yxatdan o‘tgan; `exchange-token` majburiy va xato bo‘lsa qayta urinish.
  bool _exchangeFailed = false;
  bool? _isVerifiedUser;
  /// Avtomat verify har bir kod uchun faqat bir marta — `Tasdiqlash` tugmasi bilan
  /// `otp-verify` ikki marta yuborilib, ikkinchisi "kod ishlatilgan" xatosini bermasligi uchun.
  String? _autoSubmittedCode;

  String? _phoneApi;
  String? _devCodeHint;
  int? _otpExpiresSec;
  String? _tempToken;
  String? _verifyUserType;

  /// OTP teskari sanoq (qolgan soniyalar) va uni boshqaruvchi timer.
  int _otpRemaining = 0;
  Timer? _otpTimer;

  /// Noto'g'ri kod xatosi — input tagida qizil yozuv + qizil border uchun.
  String? _otpError;

  @override
  void dispose() {
    _otpTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  /// OTP yuborilgach teskari sanoqni boshlaydi (expires_in_sec bo'yicha).
  void _startOtpCountdown(int? seconds) {
    _otpTimer?.cancel();
    final total = seconds ?? 0;
    setState(() => _otpRemaining = total);
    if (total <= 0) return;
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _otpRemaining = _otpRemaining > 0 ? _otpRemaining - 1 : 0;
      });
      if (_otpRemaining <= 0) t.cancel();
    });
  }

  String _fmtMmSs(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toast(String msg, {bool error = false, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(height: 1.35)),
        behavior: SnackBarBehavior.floating,
        duration: duration ?? Duration(seconds: error ? 6 : 3),
        backgroundColor: error ? const Color(0xFF991B1B) : const Color(0xFF1F2937),
      ),
    );
  }

  void _showNetworkHelpDialog(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('auth.network_cors_title')),
        content: SingleChildScrollView(
          child: SelectableText(
            networkFailureDetailGuide(url),
            style: const TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(I18n.t('common.close')),
          ),
        ],
      ),
    );
  }

  void _toastNetworkFailure(Object e, {String? messageSuffix}) {
    if (!mounted) return;
    final url = ApiConfig.baseUrl;
    var content = formatNetworkFailureShort(e, url: url);
    if (messageSuffix != null) {
      content = '$content\n\n$messageSuffix';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(content, style: const TextStyle(height: 1.35)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        backgroundColor: const Color(0xFF991B1B),
        action: SnackBarAction(
          label: I18n.t('auth.details_action'),
          textColor: Colors.white,
          onPressed: () => _showNetworkHelpDialog(url),
        ),
      ),
    );
  }

  String? _validatePhoneInput() {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) return I18n.t('auth.enter_phone_number');
    final api = normalizeUzbekPhoneForApi(raw);
    if (api.length < 12) {
      return I18n.t('auth.full_uz_phone_required');
    }
    return null;
  }

  Future<void> _sendOtp() async {
    final err = _validatePhoneInput();
    if (err != null) {
      _toast(err, error: true);
      return;
    }
    final apiPhone = normalizeUzbekPhoneForApi(_phoneController.text);

    setState(() {
      _loading = true;
      _devCodeHint = null;
      _otpExpiresSec = null;
      _exchangeFailed = false;
      _isVerifiedUser = null;
      _tempToken = null;
      _verifyUserType = null;
      _autoSubmittedCode = null;
    });
    try {
      final r = await _auth.otpSend(apiPhone);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _otpSent = true;
        _phoneApi = apiPhone;
        _devCodeHint = r.devCode;
        _otpExpiresSec = r.expiresInSec;
        _otpError = null;
      });
      _otpFocus.requestFocus();
      _startOtpCountdown(r.expiresInSec);
      final sec = r.expiresInSec != null ? ' (${r.expiresInSec} s)' : '';
      _toast(
        r.devCode != null
            ? I18n.t('auth.otp_sent_dev', {'sec': sec, 'code': r.devCode})
            : I18n.t('auth.otp_sent_basic', {'sec': sec}),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.firstFieldMessage, error: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toastNetworkFailure(e);
    }
  }

  /// Ro‘yxatdan o‘tgan foydalanuvchi: `exchange-token` → `user_type` bo‘yicha driver yoki customer sahifa.
  Future<void> _exchangeAndRouteRegistered(String phone) async {
    final temp = _tempToken;
    if (temp == null) return;

    setState(() {
      _loading = true;
      _exchangeFailed = false;
    });
    try {
      final ex = await _auth.exchangeToken(tempToken: temp);
      if (!mounted) return;
      final userType = (ex.userType ?? _verifyUserType ?? 'customer').toLowerCase();
      await _session.saveSession(
        refreshToken: ex.refreshToken,
        userId: ex.userId,
        userType: userType,
        phoneDisplay: phone,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _pushByUserType(phone: phone, userId: ex.userId, userType: userType);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _exchangeFailed = true;
      });
      _toast(e.firstFieldMessage, error: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _exchangeFailed = true;
      });
      _toastNetworkFailure(e);
    }
  }

  /// `otp-verify`da `is_verified=false`: temp_token + telefon saqlanadi, customer asosiy sahifaga
  /// (ko‘rish rejimi). Foydalanuvchi keyin profil orqali "Haydovchi bo‘lish"ni tanlashi mumkin.
  Future<void> _openCustomerForNewNumber(String phone, {required int otpUserId}) async {
    final temp = _tempToken;
    if (temp == null) return;

    setState(() => _loading = true);
    await _session.clear();
    await _session.saveTempRegistrationToken(temp);
    await _session.savePhoneDisplayOnly(phone);
    if (!mounted) return;
    setState(() => _loading = false);
    final uid = otpUserId != 0 ? otpUserId : null;
    // Login ekranidagi eski (masalan, tarmoq) SnackBar yangi ekranga "yopishib" qolmasin.
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MainShell(
          initialMode: 'customer',
          phoneDisplay: phone,
          userId: uid,
          hasRefreshSession: false,
        ),
      ),
    );
  }

  void _pushByUserType({
    required String phone,
    required int userId,
    required String userType,
  }) {
    // Login ekranidagi eski (masalan, tarmoq) SnackBar yangi ekranga "yopishib" qolmasin.
    ScaffoldMessenger.of(context).clearSnackBars();
    if (userType == 'driver') {
      // Driver uchun status'ni so'raymiz va shunga qarab yo'naltiramiz.
      _routeDriverByStatus(phone: phone, userId: userId);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MainShell(
          initialMode: 'customer',
          phoneDisplay: phone,
          userId: userId,
          hasRefreshSession: true,
        ),
      ),
    );
  }

  Future<void> _routeDriverByStatus({
    required String phone,
    required int userId,
  }) async {
    DriverRegistrationStatus? status;
    try {
      status = await DriverApi.instance.registrationStatus();
    } on ApiException catch (e) {
      _toast(I18n.t('auth.status_label', {'msg': e.firstFieldMessage}), error: true);
    } catch (e) {
      _toastNetworkFailure(e);
    }
    if (!mounted) return;

    if (status == null) {
      // Fallback: status olib bo'lmadi — driver main shellga ochamiz.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MainShell(
            initialMode: 'driver',
            phoneDisplay: phone,
            userId: userId,
            hasRefreshSession: true,
          ),
        ),
      );
      return;
    }

    Widget target;
    switch (status.status) {
      case DriverRegistrationStatus.statusActive: // 4 = active
        target = MainShell(
          initialMode: 'driver',
          phoneDisplay: phone,
          userId: userId,
          hasRefreshSession: true,
        );
        break;
      case DriverRegistrationStatus.statusRejected: // 2 = rejected — xatolarni tuzatish
        target = DriverRejectedPage(
          phoneDisplay: phone,
          userId: userId,
          status: status,
        );
        break;
      case DriverRegistrationStatus.statusFailed: // 3 = failed
        target = DriverFailedPage(phoneDisplay: phone);
        break;
      case DriverRegistrationStatus.statusPending: // 1 = pending
      default:
        // status null bo'lsa va next_step > 0 bo'lsa — registratsiya yarim. Ammo bu yo'lda exchange muvaffaqiyatli bo'lgan,
        // ya'ni driver record bor; demak status null kelmaydi. null kelsa ham pending sifatida ko'rsatamiz.
        target = DriverPendingPage(
          phoneDisplay: phone,
          userId: userId,
          initialStatus: status,
        );
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => target));
  }

  Future<void> _verifyOtp() async {
    // Re-entrancy qo'riqchisi: in-flight so'rov ustiga ikkinchisi tushmasin
    // (klaviatura "done", tugma va avto-submit bir vaqtda tegishi mumkin).
    if (_loading) return;
    if (_tempToken != null && _exchangeFailed && _isVerifiedUser == true) {
      final phone = _phoneApi;
      if (phone != null) await _exchangeAndRouteRegistered(phone);
      return;
    }

    final code = _otpController.text.trim();
    final phone = _phoneApi;
    if (code.length != 6) {
      _toast(I18n.t('auth.enter_6_digit_otp'), error: true);
      return;
    }
    if (phone == null) return;

    setState(() {
      _loading = true;
      _exchangeFailed = false;
      _isVerifiedUser = null;
    });
    try {
      final v = await _auth.otpVerify(phoneNumber: phone, code: code);
      if (!mounted) return;
      setState(() {
        _tempToken = v.tempToken;
        _verifyUserType = v.userType;
        _isVerifiedUser = v.isVerified;
      });

      if (v.isVerified) {
        await _exchangeAndRouteRegistered(phone);
      } else {
        await _openCustomerForNewNumber(phone, otpUserId: v.userId);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Noto'g'ri kod — snackbar o'rniga input tagida qizil xato + qizil border.
      setState(() {
        _loading = false;
        _otpError = e.firstFieldMessage;
        _autoSubmittedCode = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toastNetworkFailure(e);
    }
  }

  void _resetOtpStep() {
    _otpTimer?.cancel();
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _devCodeHint = null;
      _otpExpiresSec = null;
      _otpRemaining = 0;
      _otpError = null;
      _tempToken = null;
      _verifyUserType = null;
      _exchangeFailed = false;
      _isVerifiedUser = null;
      _autoSubmittedCode = null;
    });
    _phoneFocus.requestFocus();
  }

  InputDecoration _fieldDecoration(String label, String hint,
      {Widget? prefix, String? errorText}) {
    const errorColor = Color(0xFFE53935);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      errorStyle: const TextStyle(color: errorColor, height: 1.3),
      labelStyle: const TextStyle(color: AppPalette.muted),
      hintStyle: TextStyle(color: AppPalette.muted.withValues(alpha: 0.65)),
      prefixIcon: prefix,
      filled: true,
      fillColor: AppPalette.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.teal, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: errorColor, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: errorColor, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showExchangeRetry = _otpSent && _exchangeFailed && _isVerifiedUser == true;

    return Scaffold(
      backgroundColor: AppPalette.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LogisticsGridPainter()),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppPalette.amber.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppPalette.teal.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [AppPalette.amber, AppPalette.amberDeep],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppPalette.amber.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.route_rounded,
                              color: Color(0xFF111827),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ALIX',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: AppPalette.onDark,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.6,
                                      ),
                                ),
                                Text(
                                  'Logistics',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: AppPalette.amber,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.6,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        I18n.t('auth.login_with_phone'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppPalette.muted,
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        enabled: !_otpSent,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: AppPalette.onDark, fontSize: 16),
                        cursorColor: AppPalette.teal,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-]')),
                          _MaxDigitsFormatter(12),
                        ],
                        decoration: _fieldDecoration(
                          I18n.t('auth.phone_number'),
                          I18n.t('auth.phone_hint'),
                          prefix: const Icon(Icons.phone_iphone_rounded, color: AppPalette.muted),
                        ),
                        onFieldSubmitted: (_) =>
                            _otpSent ? _otpFocus.requestFocus() : _sendOtp(),
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _otpController,
                          focusNode: _otpFocus,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            color: AppPalette.onDark,
                            fontSize: 22,
                            letterSpacing: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          cursorColor: AppPalette.amber,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _fieldDecoration(
                            I18n.t('auth.sms_code_label'),
                            '• • • • • •',
                            prefix: const Icon(Icons.shield_outlined, color: AppPalette.muted),
                            errorText: _otpError,
                          ).copyWith(counterText: ''),
                          onChanged: (v) {
                            // Yangi kod kiritila boshlasa, oldingi xatoni tozalaymiz.
                            if (_otpError != null) {
                              setState(() => _otpError = null);
                            }
                            // 6 ta raqam kiritilganda avtomat verify — har bir kod uchun faqat bir marta
                            // ('Tasdiqlash' tugmasi bilan takror yubormaslik uchun).
                            if (v.length == 6 && !_loading && v != _autoSubmittedCode) {
                              _autoSubmittedCode = v;
                              _verifyOtp();
                            }
                          },
                          onFieldSubmitted: (_) => _verifyOtp(),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _otpRemaining > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_outlined,
                                        size: 16,
                                        color: AppPalette.muted.withValues(alpha: 0.8)),
                                    const SizedBox(width: 6),
                                    Text(
                                      I18n.t('auth.otp_expires_in',
                                          {'time': _fmtMmSs(_otpRemaining)}),
                                      style: const TextStyle(
                                          color: AppPalette.muted, fontSize: 13),
                                    ),
                                  ],
                                )
                              : TextButton.icon(
                                  onPressed: _loading ? null : _sendOtp,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppPalette.amber,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  label: Text(I18n.t('auth.resend_otp')),
                                ),
                        ),
                        if (_devCodeHint != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppPalette.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppPalette.teal.withValues(alpha: 0.45)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.developer_mode_rounded,
                                    color: AppPalette.teal.withValues(alpha: 0.9), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    I18n.t('auth.dev_otp_label', {
                                      'code': _devCodeHint ?? '',
                                      'rest': _otpExpiresSec != null ? ' · ${_otpExpiresSec}s' : '',
                                    }),
                                    style: const TextStyle(color: AppPalette.muted, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (showExchangeRetry) ...[
                          const SizedBox(height: 12),
                          Text(
                            I18n.t('auth.token_exchange_failed_retry'),
                            style: TextStyle(color: AppPalette.muted.withValues(alpha: 0.9), height: 1.35),
                          ),
                        ],
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [AppPalette.amber, AppPalette.amberDeep],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.amber.withValues(alpha: 0.28),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _loading
                                  ? null
                                  : (_otpSent ? _verifyOtp : _sendOtp),
                              child: Center(
                                child: _loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Color(0xFF111827),
                                        ),
                                      )
                                    : Text(
                                        _otpSent
                                            ? (showExchangeRetry
                                                ? I18n.t('auth.retry_exchange')
                                                : I18n.t('auth.verify'))
                                            : I18n.t('auth.send_otp'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading ? null : _resetOtpStep,
                          child: Text(
                            I18n.t('auth.change_number'),
                            style: const TextStyle(color: AppPalette.muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogisticsGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 42.0;
    for (var x = 0.0; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height * 0.55, size.height), line);
    }
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Max N ta **raqam** kiritishga ruxsat beradi (+/spaces/dashes hisobga olinmaydi).
class _MaxDigitsFormatter extends TextInputFormatter {
  _MaxDigitsFormatter(this.maxDigits);

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits) {
      return oldValue;
    }
    return newValue;
  }
}
