import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

/// AppBar uchun standart "Yangilash" tugmasi. `loading=true` paytida
/// CircularProgressIndicator ko'rsatadi va onPressed null bo'ladi
/// (qayta bosib yangi so'rov yuborib bo'lmasin).
///
/// `tooltip` o'rniga `I18n.t('common.refresh')` ishlatamiz — bu standart
/// matn rus/o'zbek tilda avtomatik ko'rinadi.
class AppBarRefreshButton extends StatelessWidget {
  const AppBarRefreshButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: I18n.instance,
      builder: (_, __) {
        if (loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        return IconButton(
          tooltip: I18n.t('common.refresh'),
          icon: const Icon(Icons.refresh_rounded),
          onPressed: onPressed,
        );
      },
    );
  }
}
