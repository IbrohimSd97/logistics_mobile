import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../core/session/session_store.dart';
import '../driver/driver_api.dart';
import '../driver/driver_models.dart';
import '../driver/pages/driver_failed_page.dart';
import '../driver/pages/driver_pending_page.dart';
import '../driver/pages/driver_rejected_page.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Ilova ochilishidagi sessiya darvozasi.
///
/// App har ishga tushganda LoginScreen'ni ochish o'rniga, avval saqlangan
/// sessiyani (refresh token) tekshiradi:
///   • token bor  → foydalanuvchini QAYTA login qildirmasdan to'g'ri ekranga
///     yo'naltiradi (customer → MainShell; driver → moderatsiya statusi bo'yicha);
///   • token yo'q → LoginScreen.
///
/// Shu tufayli foydalanuvchi bir marta kirgach, ilovadan chiqib qayta kirsa ham
/// login holati saqlanib qoladi. Logout esa sessiyani tozalaydi, shuning uchun
/// undan keyingi ishga tushirishda yana LoginScreen ochiladi.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _session = SessionStore();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final token = await _session.getRefreshToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      _go(const LoginScreen());
      return;
    }

    final userType = (await _session.getUserType())?.toLowerCase() ?? 'customer';
    final userId = await _session.getUserId();
    final phone = await _session.getPhoneDisplay() ?? '';
    if (!mounted) return;

    if (userType == 'driver') {
      await _routeDriver(phone: phone, userId: userId ?? 0);
      return;
    }

    _go(MainShell(
      initialMode: 'customer',
      phoneDisplay: phone,
      userId: userId,
      hasRefreshSession: true,
    ));
  }

  /// Driver uchun moderatsiya statusini so'rab, mos ekranga yo'naltiradi.
  /// Login ekranidagi `_routeDriverByStatus` bilan bir xil mantiq.
  Future<void> _routeDriver({required String phone, required int userId}) async {
    DriverRegistrationStatus? status;
    try {
      status = await DriverApi.instance.registrationStatus();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Sessiya yaroqsiz (token eskirgan) — tozalab, login'ga qaytaramiz.
        await _session.clear();
        if (!mounted) return;
        _go(const LoginScreen());
        return;
      }
      // Boshqa xato (masalan tarmoq) — optimistik: driver shellga ochamiz.
    } catch (_) {
      // Tarmoq xatosi — driver shellga fallback.
    }
    if (!mounted) return;

    if (status == null) {
      _go(MainShell(
        initialMode: 'driver',
        phoneDisplay: phone,
        userId: userId,
        hasRefreshSession: true,
      ));
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
        target = DriverRejectedPage(phoneDisplay: phone, userId: userId, status: status);
        break;
      case DriverRegistrationStatus.statusFailed: // 3 = failed
        target = DriverFailedPage(phoneDisplay: phone);
        break;
      case DriverRegistrationStatus.statusPending: // 1 = pending
      default:
        target = DriverPendingPage(phoneDisplay: phone, userId: userId, initialStatus: status);
    }
    _go(target);
  }

  void _go(Widget page) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sessiya tekshirilayotgan qisqa oniy holat uchun splash.
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
