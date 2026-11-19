import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

/// Xaritadagi A2…A5 belgilari bilan bir xil rang.
const extraPickupColor = Color(0xFF7C3AED);

/// Ro'yxat kartochkalarida: buyurtmada A'dan tashqari yana nechta olib ketish
/// nuqtasi borligini ko'rsatadi ("＋2 olib ketish nuqtasi").
class ExtraPickupsBadge extends StatelessWidget {
  const ExtraPickupsBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final key = count == 1 ? 'order.list.extra_pickups_one' : 'order.list.extra_pickups_many';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: extraPickupColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_location_alt_rounded, size: 13, color: extraPickupColor),
          const SizedBox(width: 4),
          Text(
            I18n.t(key, {'n': count}),
            style: const TextStyle(color: extraPickupColor, fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
