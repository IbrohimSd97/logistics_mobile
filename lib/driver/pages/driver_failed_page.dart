import 'package:flutter/material.dart';

import '../../core/brand/alix_components.dart';
import '../../core/theme/app_palette.dart';
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
              _StatusBadge(icon: Icons.do_not_disturb_alt_rounded, color: cs.error),
              const SizedBox(height: 18),
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
              AlixCard(
                tone: AlixSurfaceTone.cream,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.support_agent_rounded, color: AppPalette.orange),
                  title: Text(I18n.t('common.app_name')),
                  subtitle: const Text('+998 71 200 00 00'),
                ),
              ),
              const SizedBox(height: 10),
              AlixCard(
                tone: AlixSurfaceTone.cream,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
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

/// Holat ekranlaridagi katta belgi — yumaloq plastinka ichida ikonka.
/// Yalang'och 80px ikonkadan ko'ra tartibli ko'rinadi va brend
/// yuzalari bilan bir xil tilda.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppPalette.radiusCard),
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }
}
