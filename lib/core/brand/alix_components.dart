import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// ALIX ekranlarining qurilish bloklari.
///
/// Maqsad — har bir sahifada `Card` + `Padding` + `TextStyle` ni qaytadan
/// yozmaslik. Bu yerdagi komponentlar brend maketidagi ritmni ushlab turadi:
/// bo'lim sarlavhalari kichik va katta harfli, kartalar 18 radius, faol
/// buyurtma to'q plastinkada, ikkinchi darajali bloklar krem fonda.

/// Bo'lim sarlavhasi — kichik, katta harfli, keng oraliqli.
class AlixSectionTitle extends StatelessWidget {
  const AlixSectionTitle(this.text, {super.key, this.trailing});

  final String text;

  /// O'ng tomondagi ixtiyoriy element (masalan "Hammasi" havolasi).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: style)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Umumiy karta. `tone` yuzani tanlaydi:
///   • [AlixSurfaceTone.plain] — asosiy fon ustidagi oq/qora karta;
///   • [AlixSurfaceTone.cream] — krem (yoki to'q rejimda ko'tarilgan) yuza;
///   • [AlixSurfaceTone.ink]   — brendning to'q plastinkasi, oq matn bilan.
enum AlixSurfaceTone { plain, cream, ink }

class AlixCard extends StatelessWidget {
  const AlixCard({
    super.key,
    required this.child,
    this.tone = AlixSurfaceTone.plain,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final AlixSurfaceTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (background, border) = switch (tone) {
      AlixSurfaceTone.plain => (cs.surfaceContainer, cs.outlineVariant),
      AlixSurfaceTone.cream => (cs.surfaceContainerHighest, Colors.transparent),
      AlixSurfaceTone.ink => (AppPalette.inkStrong, Colors.transparent),
    };

    // Diqqat: `Material` bir vaqtda `shape` va `borderRadius` ni qabul
    // qilmaydi — chegara kerak bo'lgani uchun faqat `shape` beriladi.
    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppPalette.radiusCard),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Raqamli ko'rsatkich kartasi (joriy buyurtmalar, arxiv, balans).
class AlixStatTile extends StatelessWidget {
  const AlixStatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppPalette.orange),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}

/// Faol buyurtmaning to'q kartasi — brend maketidagi asosiy element.
class AlixTrackingCard extends StatelessWidget {
  const AlixTrackingCard({
    super.key,
    required this.trackingLabel,
    required this.route,
    required this.statusLabel,
    required this.progress,
    this.onTap,
  });

  /// Yuqoridagi kichik satr, masalan "TRACKING · AX-20481".
  final String trackingLabel;

  /// "Toshkent → Almaty" ko'rinishidagi yo'nalish.
  final String route;

  final String statusLabel;

  /// 0..1. Buyurtma statusidan hisoblanadi.
  final double progress;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return AlixCard(
      tone: AlixSurfaceTone.ink,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trackingLabel.toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            route,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              color: AppPalette.orange,
              backgroundColor: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  statusLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$percent%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status chipi. Rang ma'no bo'yicha tanlanadi, brend orange faqat
/// "jarayonda" holatiga tegishli — shunda CTA bilan chalkashmaydi.
enum AlixTone { neutral, progress, success, warning, danger }

class AlixStatusChip extends StatelessWidget {
  const AlixStatusChip({super.key, required this.label, this.tone = AlixTone.neutral});

  final String label;
  final AlixTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (bg, fg) = switch (tone) {
      AlixTone.neutral => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      AlixTone.progress => (
          isDark ? AppPalette.orange.withValues(alpha: 0.18) : AppPalette.orangeSoft,
          AppPalette.orange,
        ),
      AlixTone.success => (
          isDark ? AppPalette.success.withValues(alpha: 0.18) : AppPalette.successSoft,
          AppPalette.success,
        ),
      AlixTone.warning => (
          isDark ? AppPalette.amber.withValues(alpha: 0.18) : AppPalette.amberSoft,
          isDark ? AppPalette.amber : const Color(0xFF8A5A00),
        ),
      AlixTone.danger => (
          isDark ? AppPalette.dangerLight.withValues(alpha: 0.18) : AppPalette.dangerSoft,
          AppPalette.dangerLight,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppPalette.radiusChip),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Bo'sh holat — ro'yxat bo'sh bo'lganda "hech narsa yo'q" o'rniga
/// keyingi qadamni taklif qiladi.
class AlixEmptyState extends StatelessWidget {
  const AlixEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppPalette.radiusChip),
            ),
            child: Icon(icon, color: AppPalette.orange, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Ekran tepasidagi xabar — xato, ogohlantirish yoki ma'lumot.
class AlixBanner extends StatelessWidget {
  const AlixBanner({
    super.key,
    required this.message,
    this.tone = AlixTone.danger,
    this.icon,
    this.action,
  });

  final String message;
  final AlixTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (bg, fg) = switch (tone) {
      AlixTone.danger => (
          isDark ? AppPalette.danger.withValues(alpha: 0.24) : AppPalette.dangerSoft,
          isDark ? Colors.white : AppPalette.danger,
        ),
      AlixTone.warning => (
          isDark ? AppPalette.amber.withValues(alpha: 0.20) : AppPalette.amberSoft,
          isDark ? AppPalette.amber : const Color(0xFF8A5A00),
        ),
      AlixTone.success => (
          isDark ? AppPalette.success.withValues(alpha: 0.20) : AppPalette.successSoft,
          isDark ? AppPalette.success : const Color(0xFF0B6B35),
        ),
      _ => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurface,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppPalette.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline_rounded, color: fg, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pul harakati qatori — hamyon tarixida (mijoz va haydovchi) bir xil.
///
/// Model turlari ikki tomonda har xil bo'lgani uchun bu yerga faqat tayyor
/// matnlar uzatiladi.
class AlixTxRow extends StatelessWidget {
  const AlixTxRow({
    super.key,
    required this.title,
    required this.amount,
    this.meta,
    this.negative = false,
    this.icon,
  });

  final String title;

  /// Formatlangan summa (valyutasi bilan yoki usiz).
  final String amount;

  /// Sana, buyurtma raqami va shunga o'xshash ikkinchi darajali ma'lumot.
  final String? meta;

  /// Chiqim bo'lsa `true` — summa neytral rangda chiqadi.
  /// Chiqim xato emas, shuning uchun qizil ishlatilmaydi.
  final bool negative;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = negative ? cs.onSurface : AppPalette.success;

    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppPalette.radiusChip),
            ),
            child: Icon(
              icon ??
                  (negative ? Icons.north_east_rounded : Icons.south_west_rounded),
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  // Tranzaksiya nomlari uzun ("Buyurtma bekor qilindi — to'lov
                  // qaytarildi"), bir qatorda ma'no yo'qoladi.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((meta ?? '').isNotEmpty)
                  Text(
                    meta!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ko'p qadamli formalar uchun bosqich ko'rsatkichi.
///
/// Ingichka `LinearProgressIndicator` dan farqli — foydalanuvchi nechta qadam
/// borligini va qaysi biridaligini aniq ko'radi.
class AlixStepHeader extends StatelessWidget {
  const AlixStepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.label,
    this.title,
  });

  /// Joriy qadam, 1 dan boshlanadi.
  final int step;
  final int total;

  /// "Qadam 2 / 3" ko'rinishidagi tayyor matn.
  final String label;

  /// Qadamning nomi (ixtiyoriy).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(total, (i) {
            final done = i < step;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: done ? AppPalette.orange : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(label, style: theme.textTheme.titleSmall),
        if (title != null) ...[
          const SizedBox(height: 4),
          Text(title!, style: theme.textTheme.headlineSmall),
        ],
      ],
    );
  }
}

/// Hujjat/rasm yuklash qatori — ro'yxatdan o'tish formalarida.
///
/// Tanlangan bo'lsa yashil belgi, bo'lmasa orange kamera ikonkasi: foydalanuvchi
/// nima qolganini ro'yxatga qaramasdan ko'radi.
class AlixUploadRow extends StatelessWidget {
  const AlixUploadRow({
    super.key,
    required this.label,
    required this.status,
    required this.onPick,
    required this.filled,
    this.thumbnail,
  });

  final String label;

  /// Fayl nomi yoki "tanlanmagan" matni.
  final String status;

  final VoidCallback onPick;

  /// Fayl tanlangan yoki serverda mavjud.
  final bool filled;

  /// Rasm oldindan ko'rinishi (bo'lmasa joy egallovchi ikonka chiziladi).
  final Widget? thumbnail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.all(12),
      onTap: onPick,
      child: Row(
        children: [
          thumbnail ??
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppPalette.radiusChip),
                ),
                child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            filled ? Icons.check_circle_rounded : Icons.photo_camera_outlined,
            color: filled ? AppPalette.success : AppPalette.orange,
          ),
        ],
      ),
    );
  }
}

/// Tasdiqlash dialogi — barcha "ishonchingiz komilmi?" savollari uchun.
///
/// Oldin har bir joyda alohida `AlertDialog` yig'ilar edi va tugmalar
/// bir xil bo'lmasdi. Bu yerda ular bitta ko'rinishga keltirilgan:
/// chapda jim bekor qilish, o'ngda amalni bajaradigan tugma.
///
/// `danger: true` — qaytarib bo'lmaydigan amal (chiqish, o'chirish):
/// tasdiq tugmasi qizil bo'ladi.
Future<bool> showAlixConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool danger = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      final accent = danger ? cs.error : AppPalette.orange;

      return AlertDialog(
        icon: icon == null
            ? null
            : Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppPalette.radiusChip),
                ),
                child: Icon(icon, color: accent),
              ),
        iconPadding: const EdgeInsets.only(top: 24, bottom: 4),
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              // Dialogda tugma butun enni egallamaydi — shuning uchun
              // umumiy `minimumSize` bekor qilinadi.
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
