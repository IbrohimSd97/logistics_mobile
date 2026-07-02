import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';

/// Offertani tashqi brauzerda ochadi. Ochib bo'lmasa SnackBar ko'rsatadi.
/// [url] berilmasa — ilova offertasi (default).
Future<void> openOfferta(BuildContext context, {String? url}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(
      Uri.parse(url ?? AppLinks.offertaUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Offertani ochib bo‘lmadi.')),
      );
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Offertani ochib bo‘lmadi.')),
    );
  }
}

/// `CheckboxListTile.title` uchun: offerta matni + bosiladigan «Offertani o‘qish» havolasi.
class OffertaCheckboxTitle extends StatelessWidget {
  const OffertaCheckboxTitle({super.key, required this.text, this.url});

  /// Checkbox yonidagi asosiy matn (masalan: "Offertani o‘qidim va qabul qilaman *").
  final String text;

  /// Qaysi offerta ochilsin (null — ilova offertasi).
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(height: 2),
        InkWell(
          onTap: () => openOfferta(context, url: url),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new_rounded, size: 15, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  'Offertani o‘qish',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
