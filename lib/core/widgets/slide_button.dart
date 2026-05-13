import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Slide-to-confirm tugma. Foydalanuvchi thumb'ni o'ngga sudraydi → onSlide chaqiriladi.
/// Popup tasdiqlash kerak emas, slide o'zi tasdiqdir.
class SlideButton extends StatefulWidget {
  const SlideButton({
    super.key,
    required this.label,
    required this.onSlide,
    this.icon = Icons.arrow_forward_rounded,
    this.gradient,
    this.height = 60,
    this.borderRadius = 30,
    this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onSlide;
  final LinearGradient? gradient;
  final double height;
  final double borderRadius;
  final Color? foregroundColor;

  @override
  State<SlideButton> createState() => _SlideButtonState();
}

class _SlideButtonState extends State<SlideButton> with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _maxX = 0;
  bool _busy = false;
  bool _completed = false;

  Future<void> _onSlideComplete() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _completed = true;
      _dragX = _maxX;
    });
    try {
      await widget.onSlide();
    } catch (_) {
      // hook handles errors via snackbar; we just reset thumb
    } finally {
      if (mounted) {
        setState(() {
          _dragX = 0;
          _busy = false;
          _completed = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grad = widget.gradient ?? AppPalette.amberGradient;
    final fg = widget.foregroundColor ?? const Color(0xFF111827);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final thumbSize = widget.height - 8;
        _maxX = w - thumbSize - 8;

        final progress = (_dragX / _maxX).clamp(0.0, 1.0);

        return SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              // Track
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: grad,
                  boxShadow: [
                    BoxShadow(
                      color: grad.colors.first.withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
              // Progress fill (more saturated as user slides)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    color: Colors.white.withValues(alpha: 0.05 + 0.15 * progress),
                  ),
                ),
              ),
              // Label
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: 1.0 - progress,
                  child: _busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded, color: fg.withValues(alpha: 0.85)),
                            Icon(Icons.chevron_right_rounded, color: fg.withValues(alpha: 0.55)),
                            Icon(Icons.chevron_right_rounded, color: fg.withValues(alpha: 0.3)),
                          ],
                        ),
                ),
              ),
              // Thumb
              AnimatedPositioned(
                duration: _busy
                    ? const Duration(milliseconds: 80)
                    : Duration.zero,
                left: 4 + _dragX,
                top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: _busy
                      ? null
                      : (details) {
                          setState(() {
                            _dragX = (_dragX + details.delta.dx).clamp(0.0, _maxX);
                          });
                        },
                  onHorizontalDragEnd: _busy
                      ? null
                      : (_) {
                          if (_dragX >= _maxX * 0.85) {
                            _onSlideComplete();
                          } else {
                            setState(() => _dragX = 0);
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(thumbSize / 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _completed ? Icons.check_rounded : widget.icon,
                      color: grad.colors.last,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
