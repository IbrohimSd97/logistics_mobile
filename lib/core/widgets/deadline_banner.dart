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
    this.arrivedDeliveryAtIso,
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

  /// Driver yetkazish nuqtasiga yetib kelgan vaqt (`arrived_delivery_at`).
  /// Driver jarimasi FAQAT kechikib yetib kelgani uchun — yetib kelgandan
  /// keyingi tushirish kutishi mijoz aybi. Shuning uchun bu qiymat mavjud
  /// bo'lsa, kechikish shu vaqtda "muzlaydi" (tushirish davomida o'smaydi).
  final String? arrivedDeliveryAtIso;

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

    // Kechikish o'lchov nuqtasi: yetib kelgan vaqt (arrived) bo'lsa — o'sha
    // (tushirish davomida jarima o'smaydi); bo'lmasa delivered; u ham bo'lmasa
    // hozirgi vaqt (driver hali yo'lda). Bu backenddagi jarima mantig'iga mos
    // (ApplyLateDeliveryPenaltyAction `arrived_delivery_at` bo'yicha o'lchaydi).
    final reference = arrivedDeliveryAtIso != null
        ? (DateTime.tryParse(arrivedDeliveryAtIso!) ?? DateTime.now())
        : (deliveredAtIso != null
            ? (DateTime.tryParse(deliveredAtIso!) ?? DateTime.now())
            : DateTime.now());

    final isLate = reference.isAfter(deadline);
    final diff = isLate ? reference.difference(deadline) : deadline.difference(reference);

    // SLA tier'iga yaxlitlash: agar SLA snapshot mavjud bo'lsa, qolgan
    // soatni keyingi SLA qadamigacha yumalaqlaymiz. Misol: SLA=24, qoldi=22h
    // → "24 soat"; qoldi=30h → "48 soat"; qoldi=50h → "72 soat".
    final int? roundedHours = !isLate && slaHours != null && slaHours! > 0
        ? _ceilToTier(diff, slaHours!)
        : null;

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
                      roundedHours != null
                          ? '$roundedHours soat'
                          : _fmtDuration(diff, isLate: isLate),
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

  /// Qolgan vaqtni SLA qadamiga (masalan, 24 soatga) yumalaqlaymiz.
  /// Misol: sla=24, d=22h → 24; d=24h00m → 24; d=24h01m → 48; d=49h → 72.
  int _ceilToTier(Duration d, int sla) {
    // Soniyalardan SLA qadamiga ceiling ko'tarish (har qanday qoldiq → keyingi tier)
    final totalSecs = d.inSeconds;
    final tierSecs = sla * 3600;
    if (totalSecs <= 0) return sla;
    final tiers = (totalSecs + tierSecs - 1) ~/ tierSecs;
    return tiers * sla;
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
