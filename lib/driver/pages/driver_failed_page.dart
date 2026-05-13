import 'package:flutter/material.dart';

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
        title: const Text('Ro‘yxatdan o‘tib bo‘lmadi'),
        actions: [
          IconButton(
            tooltip: 'Chiqish',
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
                'Ro‘yxatdan o‘tib bo‘lmadi',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sizning arizangiz 3 marta rad etildi. Yana urinishingiz uchun '
                'iltimos quyidagi raqam orqali aloqaga chiqing.',
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                color: cs.primaryContainer,
                child: ListTile(
                  leading: Icon(Icons.support_agent_rounded, color: cs.onPrimaryContainer),
                  title: Text('ALIX Logistics', style: TextStyle(color: cs.onPrimaryContainer)),
                  subtitle: Text('+998 71 200 00 00', style: TextStyle(color: cs.onPrimaryContainer)),
                ),
              ),
              Card(
                color: cs.surfaceContainerHighest,
                child: ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Sizning raqamingiz'),
                  subtitle: Text(phoneDisplay),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Chiqish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
