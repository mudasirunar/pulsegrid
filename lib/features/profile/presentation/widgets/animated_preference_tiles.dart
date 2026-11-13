import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Phone icon that performs a dampened horizontal shake when toggled ON.
class AnimatedShakePhoneIcon extends StatefulWidget {
  final bool enabled;
  final Color color;

  const AnimatedShakePhoneIcon({
    super.key,
    required this.enabled,
    required this.color,
  });

  @override
  State<AnimatedShakePhoneIcon> createState() => _AnimatedShakePhoneIconState();
}

class _AnimatedShakePhoneIconState extends State<AnimatedShakePhoneIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedShakePhoneIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final shake = _controller.isAnimating
            ? math.sin(t * math.pi * 6) * (1.0 - t) * 4.5
            : 0.0;
        final angle = _controller.isAnimating
            ? math.sin(t * math.pi * 6) * (1.0 - t) * 0.14
            : 0.0;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Transform.rotate(
            angle: angle,
            child: child,
          ),
        );
      },
      child: Icon(
        widget.enabled ? Icons.vibration_rounded : Icons.smartphone_rounded,
        size: 22,
        color: widget.color,
      ),
    );
  }
}

/// Animated density icon:
/// - Full mode (`isCompact == false`): 4 horizontal lines
/// - Compact mode (`isCompact == true`): bottom 2 lines fade out & collapse,
///   leaving 2 centered lines (reverses smoothly when toggled off).
class AnimatedLinesIcon extends StatefulWidget {
  final bool isCompact;
  final Color color;

  const AnimatedLinesIcon({
    super.key,
    required this.isCompact,
    required this.color,
  });

  @override
  State<AnimatedLinesIcon> createState() => _AnimatedLinesIconState();
}

class _AnimatedLinesIconState extends State<AnimatedLinesIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isCompact ? 1.0 : 0.0,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedLinesIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompact != widget.isCompact) {
      if (widget.isCompact) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CustomPaint(
            painter: _LinesIconPainter(
              compactProgress: _progress.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _LinesIconPainter extends CustomPainter {
  final double compactProgress; // 0.0 = 4 lines (full), 1.0 = 2 lines (compact)
  final Color color;

  _LinesIconPainter({
    required this.compactProgress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeHeight = 2.0;
    final left = 2.5;
    final fullWidth = size.width - 5.0;

    // 4-line y-positions: [4, 9, 14, 19] -> 2-line centered y-positions: [8, 14]
    final y0 = _lerp(3.5, 7.5, compactProgress);
    final y1 = _lerp(8.5, 14.5, compactProgress);
    final y2 = _lerp(13.5, 16.0, compactProgress);
    final y3 = _lerp(18.5, 19.5, compactProgress);

    final primaryPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Top two persistent lines
    _drawLine(canvas, left, y0, fullWidth, strokeHeight, primaryPaint);
    _drawLine(canvas, left, y1, fullWidth * _lerp(1.0, 0.78, compactProgress),
        strokeHeight, primaryPaint);

    // Bottom two collapsing/fading lines
    final fadingAlpha = (1.0 - compactProgress).clamp(0.0, 1.0);
    if (fadingAlpha > 0.01) {
      final fadingPaint = Paint()
        ..color = color.withValues(alpha: color.a * fadingAlpha)
        ..style = PaintingStyle.fill;
      final shrinkFactor = _lerp(1.0, 0.35, compactProgress);
      _drawLine(
        canvas,
        left,
        y2,
        fullWidth * shrinkFactor,
        strokeHeight * fadingAlpha,
        fadingPaint,
      );
      _drawLine(
        canvas,
        left,
        y3,
        fullWidth * 0.72 * shrinkFactor,
        strokeHeight * fadingAlpha,
        fadingPaint,
      );
    }
  }

  void _drawLine(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    Paint paint,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y - height / 2, width, height),
      Radius.circular(height / 2),
    );
    canvas.drawRRect(rect, paint);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _LinesIconPainter oldDelegate) {
    return oldDelegate.compactProgress != compactProgress ||
        oldDelegate.color != color;
  }
}

/// Flat hairline-separated preference toggle row used inside the Preferences group.
class AnimatedPreferenceTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool value;
  final bool hapticEnabled;
  final bool triggerHapticOnEnableOnly;
  final ValueChanged<bool> onChanged;

  const AnimatedPreferenceTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.hapticEnabled,
    this.triggerHapticOnEnableOnly = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return InkWell(
      onTap: () => _toggle(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              onChanged: _toggle,
              activeTrackColor: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(bool next) {
    final shouldVibrate =
        triggerHapticOnEnableOnly ? next : hapticEnabled;
    if (shouldVibrate) {
      HapticFeedback.mediumImpact();
    }
    onChanged(next);
  }
}

