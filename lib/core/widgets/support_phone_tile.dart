import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';
import '../i18n/i18n.dart';

/// Profildagi "Qo'llab-quvvatlash" qatori — bosilganda raqamga qo'ng'iroq.
class SupportPhoneTile extends StatelessWidget {
  const SupportPhoneTile({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: const Icon(Icons.support_agent_rounded),
      title: Text(I18n.t('settings.support')),
      subtitle: const Text(AppLinks.supportPhoneDisplay),
      trailing: Icon(Icons.call_rounded, color: cs.primary),
      onTap: () => launchUrl(Uri.parse('tel:${AppLinks.supportPhone}')),
    );
  }
}
