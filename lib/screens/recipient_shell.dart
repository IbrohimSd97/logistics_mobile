import 'package:flutter/material.dart';

import '../core/api/auth_api.dart';
import '../core/brand/alix_components.dart';
import '../core/i18n/i18n.dart';
import '../core/session/session_store.dart';
import '../customer/pages/customer_physical_registration_page.dart';
import '../recipient/pages/recipient_home_page.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Ro'yxatdan o'tmagan yuk qabul qiluvchisining asosiy ekrani: unga
/// yuborilgan yuklar. Xohlasa shu yerdan mijoz bo'lib ro'yxatdan o'tadi va
/// ilovaning boshqa imkoniyatlari ochiladi.
class RecipientShell extends StatelessWidget {
  const RecipientShell({super.key, required this.phoneDisplay});

  final String phoneDisplay;

  Future<void> _logout(BuildContext context) async {
    final ok = await showAlixConfirm(
      context,
      icon: Icons.logout_rounded,
      title: I18n.t('auth.logout'),
      message: I18n.t('auth.logout_confirm'),
      confirmLabel: I18n.t('auth.logout'),
      cancelLabel: I18n.t('common.cancel'),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    await SessionStore().clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _register(BuildContext context) async {
    final session = SessionStore();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final refresh = await session.getRefreshToken();
      if (refresh == null || refresh.isEmpty) throw StateError('no session');
      await session.saveTempRegistrationToken(await const AuthApi().issueTempTokenFromRefresh(refresh));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => CustomerPhysicalRegistrationPage(phoneDisplay: phoneDisplay)),
    );
    if (ok != true || !context.mounted) return;

    // Endi oddiy mijoz: keyingi ishga tushirishda ham mijoz ekrani ochilsin.
    final refresh = await session.getRefreshToken();
    final userId = await session.getUserId();
    if (refresh == null || userId == null) return;
    await session.saveSession(refreshToken: refresh, userId: userId, userType: 'customer', phoneDisplay: phoneDisplay);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MainShell(initialMode: 'customer', phoneDisplay: phoneDisplay, userId: userId, hasRefreshSession: true),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RecipientHomePage(
      onLogout: () => _logout(context),
      onRegister: () => _register(context),
    );
  }
}
