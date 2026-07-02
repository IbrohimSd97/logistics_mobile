import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

/// Xaritalarda joriy joylashuvga olib boradigan dumaloq tugma.
///
/// Barcha xarita ochilgan ekranlarda bir xil ko'rinish uchun yagona widget.
/// [busy] true bo'lsa joylashuv aniqlanayotganini ko'rsatadi (spinner).
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.heroTag,
  });

  final VoidCallback onPressed;
  final bool busy;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FloatingActionButton.small(
      heroTag: heroTag ?? 'my_location_fab',
      tooltip: I18n.t('location.my_location'),
      backgroundColor: cs.surface,
      foregroundColor: cs.primary,
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            )
          : const Icon(Icons.my_location_rounded),
    );
  }
}
