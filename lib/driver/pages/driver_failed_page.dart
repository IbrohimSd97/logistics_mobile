import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../../core/session/session_store.dart';
import '../../screens/login_screen.dart';

class DriverFailedPage extends StatelessWidget {
  const DriverFailedPage({super.key, required this.phoneDisplay});

  final String phoneDisplay;

  Future<void> _logout(BuildContext context) async {
    await SessionStore().clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('driver.failed.title_short')),
        actions: [
          IconButton(
            tooltip: I18n.t('common.refresh'),
            icon: const Icon(Icons.refresh_rounded),
            // Bu sahifa terminal status — reload UI'ni qayta chizadi (kelajakda
            // status server'da o'zgargan bo'lsa, foydalanuvchi ko'ra olsin).
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(I18n.t('common.refresh'))),
              );
            },
          ),
          IconButton(
            tooltip: I18n.t('auth.logout'),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.do_not_disturb_alt_rounded, size: 80, color: cs.error),
              const SizedBox(height: 16),
              Text(
                I18n.t('driver.failed.title_short'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                I18n.t('driver.failed.body_full'),
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                color: cs.primaryContainer,
                child: ListTile(
                  leading: Icon(Icons.support_agent_rounded, color: cs.onPrimaryContainer),
                  title: Text(I18n.t('common.app_name'), style: TextStyle(color: cs.onPrimaryContainer)),
                  subtitle: Text('+998 71 200 00 00', style: TextStyle(color: cs.onPrimaryContainer)),
                ),
              ),
              Card(
                color: cs.surfaceContainerHighest,
                child: ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(I18n.t('driver.failed.your_phone')),
                  subtitle: Text(phoneDisplay),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded),
                label: Text(I18n.t('auth.logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
