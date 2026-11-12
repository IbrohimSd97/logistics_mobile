import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_palette.dart';
import '../customer_api.dart';
import '../customer_models.dart';

/// Bitta raqamda bir nechta mijoz profili bo'lsa (shaxsiy + kompaniya xodimi)
/// profil tanlash oynasi. Tanlangan profil serverda faol bo'ladi; `true` —
/// tanlov o'zgardi (ilova ma'lumotlarni qayta yuklashi kerak).
Future<bool> pickCustomerProfile(
  BuildContext context,
  CustomerProfilesInfo info, {
  bool dismissible = true,
}) async {
  final chosen = await showModalBottomSheet<CustomerProfileOption>(
    context: context,
    isDismissible: dismissible,
    enableDrag: dismissible,
    showDragHandle: dismissible,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(I18n.t('profile_switch.title'), style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(I18n.t('profile_switch.subtitle'), style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
            for (final p in info.profiles) ...[
              _ProfileTile(profile: p, selected: p.id == info.active?.id, onTap: () => Navigator.pop(ctx, p)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );
  if (chosen == null) return false;
  if (!context.mounted) return false;
  try {
    await CustomerApi.instance.selectProfile(chosen.id);
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.firstFieldMessage)));
    }
    return false;
  }
  return chosen.id != info.activeId;
}

/// Kirishdan keyin: profil bittadan ko'p bo'lsa — majburiy tanlov.
Future<void> askCustomerProfileIfNeeded(BuildContext context) async {
  CustomerProfilesInfo info;
  try {
    info = await CustomerApi.instance.profiles();
  } catch (_) {
    return; // tanlovsiz davom etamiz — server shaxsiy profilni oladi
  }
  if (info.profiles.length < 2 || !context.mounted) return;
  await pickCustomerProfile(context, info, dismissible: false);
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile, required this.selected, required this.onTap});

  final CustomerProfileOption profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlixCard(
      tone: selected ? AlixSurfaceTone.cream : AlixSurfaceTone.plain,
      onTap: onTap,
      child: Row(
        children: [
          Icon(profile.isCompanyStaff ? Icons.business_rounded : Icons.person_rounded, color: AppPalette.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.isCompanyStaff
                      ? (profile.companyName ?? I18n.t('profile_switch.company'))
                      : I18n.t('profile_switch.personal'),
                  style: t.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  I18n.t(profile.isCompanyStaff ? 'profile_switch.company_hint' : 'profile_switch.personal_hint'),
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_circle_rounded, color: AppPalette.success),
        ],
      ),
    );
  }
}

/// Profil sahifasidagi karta: hozirgi profil (shaxsiy yoki kompaniya nomidan),
/// almashtirish va — faqat xodim profili bo'lsa — shaxsiy profil ochish.
class CustomerProfileSwitchCard extends StatefulWidget {
  const CustomerProfileSwitchCard({super.key, required this.onSwitched, required this.onOpenPersonalRegistration});

  final VoidCallback onSwitched;
  final Future<void> Function() onOpenPersonalRegistration;

  @override
  State<CustomerProfileSwitchCard> createState() => _CustomerProfileSwitchCardState();
}

class _CustomerProfileSwitchCardState extends State<CustomerProfileSwitchCard> {
  CustomerProfilesInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await CustomerApi.instance.profiles();
      if (mounted) setState(() => _info = info);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final active = info?.active;
    if (info == null || active == null) return const SizedBox.shrink();
    // Faqat shaxsiy profil — ko'rsatadigan narsa yo'q.
    if (info.profiles.length == 1 && !active.isCompanyStaff) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: AlixCard(
        tone: AlixSurfaceTone.cream,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(active.isCompanyStaff ? Icons.business_rounded : Icons.person_rounded, color: AppPalette.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(I18n.t('profile_switch.current'), style: t.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        active.isCompanyStaff
                            ? I18n.t('profile_switch.as_staff', {'company': active.companyName ?? ''})
                            : I18n.t('profile_switch.personal'),
                        style: t.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (info.profiles.length > 1)
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(I18n.t('profile_switch.switch')),
                onPressed: () async {
                  final changed = await pickCustomerProfile(context, info);
                  if (changed) widget.onSwitched();
                },
              ),
            if (!info.hasPersonal) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(I18n.t('profile_switch.open_personal')),
                onPressed: () async {
                  await widget.onOpenPersonalRegistration();
                  if (mounted) widget.onSwitched();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
