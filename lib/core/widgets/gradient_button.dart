import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// ALIX asosiy CTA tugmasi — to'ldirilgan orange, oq matn, yumshoq soya.
///
/// Brendda tugmalar tekis rangda; `orangeGradient` ikki juda yaqin bosqichdan
/// iborat, u faqat sezilmas chuqurlik beradi. Boshqa rang kerak bo'lsa
/// `gradient` orqali beriladi (masalan [AlixInkButton] charcoal variantda).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.gradient,
    this.height = 52,
    this.borderRadius = AppPalette.radiusButton,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final LinearGradient? gradient;
  final double height;
  final double borderRadius;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final grad = gradient ?? AppPalette.orangeGradient;
    final fg = foregroundColor ?? Colors.white;
    final shadowColor = grad.colors.first.withValues(alpha: disabled ? 0.0 : 0.28);

    return SizedBox(
      height: height,
      child: AnimatedOpacity(
        opacity: disabled ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: grad,
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: disabled ? null : onPressed,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: fg,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: fg, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ikkilamchi CTA — brendning to'q (charcoal) tugmasi.
/// Orange tugma bilan yonma-yon turganda ikkinchi darajali amal uchun.
class AlixInkButton extends StatelessWidget {
  const AlixInkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    // To'q rejimda charcoal tugma fonga singib ketadi, shuning uchun u
    // teskarisiga aylanadi: krem plastinka + to'q matn.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GradientButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      gradient: isDark
          ? const LinearGradient(colors: [AppPalette.darkOn, Color(0xFFE2DFD8)])
          : AppPalette.inkGradient,
      foregroundColor: isDark ? AppPalette.inkStrong : Colors.white,
    );
  }
}
