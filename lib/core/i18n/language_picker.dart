import 'package:flutter/material.dart';

import 'i18n.dart';

/// Settings card uchun til tanlash ListTile. AnimatedBuilder bilan
/// `I18n.instance`ni tinglaydi, joriy tilni belgilab beradi.
class LanguagePickerTile extends StatelessWidget {
  const LanguagePickerTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: I18n.instance,
      builder: (_, __) {
        return ListTile(
          leading: const Icon(Icons.language_rounded),
          title: Text(I18n.t('settings.language')),
          subtitle: Text(I18n.instance.locale.nativeName),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _openSheet(context),
        );
      },
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final current = I18n.instance.locale;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.language_rounded),
                    const SizedBox(width: 8),
                    Text(
                      I18n.t('settings.language'),
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              for (final l in AppLocaleCode.values)
                RadioListTile<AppLocaleCode>(
                  value: l,
                  groupValue: current,
                  title: Text(l.nativeName),
                  onChanged: (v) async {
                    if (v == null) return;
                    await I18n.instance.setLocale(v);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
