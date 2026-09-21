import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'alix_logo.dart';

/// Ilova ochilishidagi brend ekrani.
///
/// Native splash (Android `launch_background`, iOS `LaunchScreen`) ham xuddi
/// shu kompozitsiyani ko'rsatadi — oq fon, markazda belgi — shuning uchun
/// native ekrandan Flutter ekraniga o'tish sezilmaydi.
class AlixSplash extends StatelessWidget {
  const AlixSplash({super.key, this.showProgress = true});

  /// Pastdagi ingichka orange indikator. Sessiya tekshirilayotganini bildiradi.
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AlixLogoStacked(markHeight: 58, color: cs.onSurface),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: Center(
                child: AnimatedOpacity(
                  opacity: showProgress ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const SizedBox(
                    width: 56,
                    height: 3,
                    child: LinearProgressIndicator(
                      color: AppPalette.orange,
                      backgroundColor: Colors.transparent,
                      minHeight: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
