import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class TimelineStep {
  const TimelineStep({
    required this.label,
    required this.iconData,
    required this.timeIso,
    this.note,
  });

  final String label;
  final IconData iconData;
  final String? timeIso;
  final String? note;
}

/// Buyurtmaning bosqichlari (vertikal timeline) — har bir bosqich vaqti bilan.
/// Vaqti yo'q bosqichlar kulrang.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${p2(local.month)}-${p2(local.day)} ${p2(local.hour)}:${p2(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Status tarixi',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(steps.length, (i) {
            final st = steps[i];
            final isLast = i == steps.length - 1;
            final hasTime = (st.timeIso ?? '').isNotEmpty;
            final activeColor = hasTime ? AppPalette.teal : cs.outlineVariant;
            final textColor = hasTime ? cs.onSurface : cs.onSurfaceVariant;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: hasTime ? activeColor.withValues(alpha: 0.15) : cs.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: activeColor, width: 1.5),
                        ),
                        child: Icon(st.iconData, size: 14, color: activeColor),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(width: 2, color: activeColor.withValues(alpha: 0.4)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  st.label,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (hasTime)
                                Text(
                                  _fmtDate(st.timeIso!),
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          if ((st.note ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              st.note!,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
