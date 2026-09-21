import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/api_exception.dart';
import '../core/api/auth_api.dart';
import '../core/config/api_config.dart';
import '../core/i18n/i18n.dart';
import '../core/session/session_store.dart';
import '../core/brand/alix_logo.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/gradient_button.dart';
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
        backgroundColor: error ? AppPalette.danger : AppPalette.inkStrong,
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
        backgroundColor: AppPalette.danger,
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
    // Har doim driver moderatsiya holatini tekshiramiz: foydalanuvchi driver
    // bo'lib ro'yxatdan o'tган va hali tasdiqlanmagan (pending/rejected/failed)
    // bo'lsa — user_type 'customer' bo'lsa ham driver holat sahifasiga chiqaramiz.
    _routeDriverByStatus(phone: phone, userId: userId, userType: userType);
  }

  Future<void> _routeDriverByStatus({
    required String phone,
    required int userId,
    required String userType,
  }) async {
    DriverRegistrationStatus? status;
    try {
      status = await DriverApi.instance.registrationStatus();
    } on ApiException catch (_) {
      // Status olib bo'lmadi — pastda user_type bo'yicha davom etamiz.
    } catch (_) {}
    if (!mounted) return;

    // Driver yozuvi bor va hali ACTIVE emas → tegishli driver holat sahifasi
    // (pending/rejected/failed). user_type dan qat'i nazar shu ko'rsatiladi,
    // shunda logout/qayta kirishda ham driver o'z holat sahifasida turadi.
    if (status != null &&
        status.driverId != null &&
        status.status != DriverRegistrationStatus.statusActive) {
      Widget target;
      switch (status.status) {
        case DriverRegistrationStatus.statusRejected: // 2 — xatolarni tuzatish
          target = DriverRejectedPage(phoneDisplay: phone, userId: userId, status: status);
          break;
        case DriverRegistrationStatus.statusFailed: // 3 — 3 martadan ortiq rad etilgan
          target = DriverFailedPage(phoneDisplay: phone);
          break;
        default: // 1 = pending (moderatsiya kutilmoqda)
          target = DriverPendingPage(phoneDisplay: phone, userId: userId, initialStatus: status);
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => target));
      return;
    }

    // Active driver yoki driver yozuvi yo'q → user_type bo'yicha asosiy shell.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MainShell(
          initialMode: userType == 'driver' ? 'driver' : 'customer',
          phoneDisplay: phone,
          userId: userId,
          hasRefreshSession: true,
        ),
      ),
    );
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

  /// Maydon bezagi — ranglar `AppTheme.inputDecorationTheme` dan keladi,
  /// shuning uchun bu yerda faqat matn, ikonka va xato qoladi.
  InputDecoration _fieldDecoration(String label, String hint,
      {Widget? prefix, String? errorText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: prefix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showExchangeRetry = _otpSent && _exchangeFailed && _isVerifiedUser == true;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;

    return Scaffold(
      body: Stack(
        children: [
          // Brend foni: logotip panellaridan olingan diagonal naqsh va
          // yumshoq orange nur. Juda past kontrastda — matnga xalaqit bermaydi.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BrandBackdropPainter(
                  lineColor: cs.onSurface.withValues(alpha: 0.055),
                  glowColor: AppPalette.orange.withValues(alpha: 0.13),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: AlixLogo(height: 28),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        I18n.t('auth.login_title'),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        I18n.t('auth.login_with_phone'),
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        enabled: !_otpSent,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: AppPalette.orange,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-]')),
                          _MaxDigitsFormatter(12),
                        ],
                        decoration: _fieldDecoration(
                          I18n.t('auth.phone_number'),
                          I18n.t('auth.phone_hint'),
                          prefix: const Icon(Icons.phone_iphone_rounded),
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
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 22,
                            letterSpacing: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: AppPalette.orange,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _fieldDecoration(
                            I18n.t('auth.sms_code_label'),
                            '• • • • • •',
                            prefix: const Icon(Icons.shield_outlined),
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
                                    Icon(Icons.timer_outlined, size: 16, color: muted),
                                    const SizedBox(width: 6),
                                    Text(
                                      I18n.t('auth.otp_expires_in',
                                          {'time': _fmtMmSs(_otpRemaining)}),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                )
                              : TextButton.icon(
                                  onPressed: _loading ? null : _sendOtp,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  label: Text(I18n.t('auth.resend_otp')),
                                ),
                        ),
                        if (_devCodeHint != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppPalette.radiusField),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.developer_mode_rounded,
                                    color: AppPalette.orange, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    I18n.t('auth.dev_otp_label', {
                                      'code': _devCodeHint ?? '',
                                      'rest': _otpExpiresSec != null ? ' · ${_otpExpiresSec}s' : '',
                                    }),
                                    style: theme.textTheme.bodySmall,
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
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      GradientButton(
                        label: _otpSent
                            ? (showExchangeRetry
                                ? I18n.t('auth.retry_exchange')
                                : I18n.t('auth.verify'))
                            : I18n.t('auth.send_otp'),
                        loading: _loading,
                        onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _loading ? null : _resetOtpStep,
                          style: TextButton.styleFrom(foregroundColor: muted),
                          child: Text(I18n.t('auth.change_number')),
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

/// Login foni — logotipdagi vertikal panellarni eslatuvchi diagonal chiziqlar
/// va yuqori o'ng burchakdagi orange nur. Kontrast ataylab juda past.
class _BrandBackdropPainter extends CustomPainter {
  const _BrandBackdropPainter({required this.lineColor, required this.glowColor});

  final Color lineColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final glowCenter = Offset(size.width * 0.92, -size.height * 0.05);
    final glowRadius = size.width * 0.75;
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [glowColor, glowColor.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    // Logotip panellarining ritmi — faqat yuqori o'ng burchakda, nur ichida.
    // Butun ekranga yoyilsa fon shovqinga aylanadi, shuning uchun qirqilgan.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(size.width * 0.42, -size.height * 0.1,
          size.width * 0.75, size.height * 0.46),
    );
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    const step = 34.0;
    final slant = size.height * 0.30;
    for (var x = size.width * 0.35; x < size.width + slant; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + slant, 0), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandBackdropPainter old) =>
      old.lineColor != lineColor || old.glowColor != glowColor;
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
