import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Yetkazish muddati banner. Status hayotchan bo'lsa qolgan vaqt countdown
/// bilan, kechikkan bo'lsa ogohlantirish + jarima taxmini bilan ko'rsatadi.
class DeadlineBanner extends StatelessWidget {
  const DeadlineBanner({
    super.key,
    required this.deadlineAtIso,
    required this.slaHours,
    required this.deliveredAtIso,
    this.latePenaltyAmount,
    this.penaltyPerHour,
    required this.isDriver,
  });

  /// `delivery_deadline_at` ISO string.
  final String deadlineAtIso;
  final int? slaHours;

  /// Buyurtma `delivered_at`. Tugatilgan bo'lsa shu vaqtga nisbatan
  /// kechikishni ko'rsatamiz, bo'lmasa hozirgi vaqtga.
  final String? deliveredAtIso;

  /// Yakunlangandan keyin server yozgan jarima (so'm). null bo'lsa ko'rsatilmaydi.
  final String? latePenaltyAmount;

  /// Soatlik jarima tarifi (so'm) — kechikish jarayonida tahminiy summa uchun.
  final double? penaltyPerHour;

  /// `true` — driver pespektivasi (jarima ogohlantirish), `false` — customer (kompensatsiya).
  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    final deadline = DateTime.tryParse(deadlineAtIso);
    if (deadline == null) return const SizedBox.shrink();

    final reference = deliveredAtIso != null
        ? (DateTime.tryParse(deliveredAtIso!) ?? DateTime.now())
        : DateTime.now();

    final isLate = reference.isAfter(deadline);
    final diff = isLate ? reference.difference(deadline) : deadline.difference(reference);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bgColor = isLate
        ? AppPalette.dangerLight.withValues(alpha: 0.15)
        : AppPalette.success.withValues(alpha: 0.12);
    final borderColor = isLate ? AppPalette.dangerLight : AppPalette.success;
    final icon = isLate ? Icons.warning_amber_rounded : Icons.access_time_rounded;
    final fg = isLate ? AppPalette.dangerLight : AppPalette.success;

    // Estimated penalty (server tarafidan yozilmasa, hisoblaymiz)
    String? penaltyText;
    final serverPenalty = num.tryParse(latePenaltyAmount ?? '');
    if (serverPenalty != null && serverPenalty > 0) {
      penaltyText = _money(serverPenalty.toString());
    } else if (isLate && penaltyPerHour != null && penaltyPerHour! > 0) {
      final lateHours = (diff.inSeconds / 3600.0).ceil();
      penaltyText = _money((lateHours * penaltyPerHour!).toString());
    }

    final detailLine = isLate
        ? (isDriver
            ? (penaltyText != null
                ? 'Jarima: $penaltyText so‘m (sizdan yechiladi)'
                : 'Yetkazish muddati o‘tib ketdi')
            : (penaltyText != null
                ? 'Kompensatsiya: $penaltyText so‘m'
                : 'Yetkazish muddati o‘tib ketdi'))
        : (slaHours != null
            ? 'SLA: $slaHours soat • muddat ${_fmtDateTime(deadline)}'
            : 'Muddat: ${_fmtDateTime(deadline)}');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isLate ? 'Kechikkan' : 'Yetkazish muddati',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                    Text(
                      _fmtDuration(diff, isLate: isLate),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  detailLine,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d, {required bool isLate}) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    final prefix = isLate ? '+' : '−';
    if (hours >= 1) return '$prefix${hours}s ${mins}d';
    final secs = d.inSeconds.remainder(60);
    return '$prefix${mins}d ${secs}s';
  }

  String _fmtDateTime(DateTime dt) {
    final local = dt.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${p2(local.month)}-${p2(local.day)} ${p2(local.hour)}:${p2(local.minute)}';
  }

  String _money(String raw) {
    final n = num.tryParse(raw);
    if (n == null) return raw;
    final i = n.round();
    final s = i.abs().toString();
    final buf = StringBuffer();
    for (int k = 0; k < s.length; k++) {
      if (k > 0 && (s.length - k) % 3 == 0) buf.write(' ');
      buf.write(s[k]);
    }
    return buf.toString();
  }
}
