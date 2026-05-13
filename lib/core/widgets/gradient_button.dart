import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Send-OTP page'dagi tugma stilida — amber→amberDeep gradient, soya, qalin matn.
/// Asosiy CTA tugmalarda ishlatish kerak.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.gradient,
    this.height = 52,
    this.borderRadius = 14,
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
    final grad = gradient ?? AppPalette.amberGradient;
    final fg = foregroundColor ?? const Color(0xFF111827);
    final shadowColor = grad.colors.first.withValues(alpha: disabled ? 0.0 : 0.32);

    return SizedBox(
      height: height,
      child: AnimatedOpacity(
        opacity: disabled ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: grad,
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 16,
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
                        width: 24,
                        height: 24,
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
                              letterSpacing: 0.2,
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

/// Teal varianti (secondary CTA uchun).
class GradientTealButton extends StatelessWidget {
  const GradientTealButton({
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
    return GradientButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      gradient: AppPalette.tealGradient,
      foregroundColor: Colors.white,
    );
  }
}
