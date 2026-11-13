import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A single action item displayed inside an [AppOverflowMenu].
class AppOverflowMenuItem {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final IconData? icon;

  const AppOverflowMenuItem({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.icon,
  });
}

/// Optional controller to programmatically dismiss an open [AppOverflowMenu].
class AppOverflowMenuController {
  VoidCallback? _closeImmediate;

  void closeImmediate() {
    _closeImmediate?.call();
  }

  void _attach(VoidCallback closeImmediate) {
    _closeImmediate = closeImmediate;
  }

  void _detach() {
    _closeImmediate = null;
  }
}

/// Reusable three-dot overflow menu button that opens a speech-bubble dropdown
/// anchored with a top-right pointer triangle under the trigger icon.
class AppOverflowMenu extends StatefulWidget {
  final List<AppOverflowMenuItem> items;
  final double menuWidth;
  final String tooltip;
  final IconData icon;
  final AppOverflowMenuController? controller;

  const AppOverflowMenu({
    super.key,
    required this.items,
    this.menuWidth = 148.0,
    this.tooltip = 'More options',
    this.icon = Icons.more_vert_rounded,
    this.controller,
  });

  @override
  State<AppOverflowMenu> createState() => _AppOverflowMenuState();
}

class _AppOverflowMenuState extends State<AppOverflowMenu>
    with SingleTickerProviderStateMixin {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 160),
    );
    widget.controller?._attach(_removeOverlayImmediate);
  }

  @override
  void didUpdateWidget(covariant AppOverflowMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(_removeOverlayImmediate);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _removeOverlayImmediate();
    _animController.dispose();
    super.dispose();
  }

  void _removeOverlayImmediate() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_animController.status != AnimationStatus.dismissed) {
      _animController.reset();
    }
  }

  Future<void> _closeMenu() async {
    if (_overlayEntry == null) return;
    await _animController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }

    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final buttonOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final menuWidth = widget.menuWidth;
    const double arrowHeight = 8.0;
    const double arrowWidth = 10.0;
    const double bubbleRadius = 9.0;
    final double topPos = buttonOffset.dy + renderBox.size.height - 10;
    final double rightPos = math.max(
      10.0,
      overlay.size.width - (buttonOffset.dx + renderBox.size.width),
    );
    final double buttonCenterFromRight =
        overlay.size.width - (buttonOffset.dx + renderBox.size.width / 2);
    const double minArrowOffset = bubbleRadius + (arrowWidth / 2);
    final double arrowOffsetFromRight = (buttonCenterFromRight - rightPos)
        .clamp(minArrowOffset, menuWidth - minArrowOffset);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      reverseCurve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
    final tipAlignment = Alignment(
      1.0 - (2.0 * arrowOffsetFromRight / menuWidth),
      -1.0,
    );

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
              ),
            ),
            Positioned(
              top: topPos,
              right: rightPos,
              child: FadeTransition(
                opacity: fadeAnim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.08, end: 1.0).animate(scaleAnim),
                  alignment: tipAlignment,
                  child: CustomPaint(
                    painter: _OverflowBubblePainter(
                      backgroundColor: bgColor,
                      borderColor: borderColor,
                      shadowColor: Colors.black.withValues(
                        alpha: isDark ? 0.45 : 0.14,
                      ),
                      arrowHeight: arrowHeight,
                      arrowWidth: arrowWidth,
                      arrowOffsetFromRight: arrowOffsetFromRight,
                      borderRadius: bubbleRadius,
                    ),
                    child: SizedBox(
                      width: menuWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: arrowHeight),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final item in widget.items)
                                    InkWell(
                                      onTap: () async {
                                        await _closeMenu();
                                        if (mounted) item.onTap();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 9,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (item.icon != null) ...[
                                              Icon(
                                                item.icon,
                                                size: 17,
                                                color: item.isDestructive
                                                    ? AppColors.severityCritical
                                                    : theme.iconTheme.color,
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                            Flexible(
                                              child: Text(
                                                item.label,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  fontWeight: item.isDestructive
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  color: item.isDestructive
                                                      ? AppColors
                                                          .severityCritical
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _buttonKey,
      icon: Icon(widget.icon),
      tooltip: widget.tooltip,
      onPressed: _toggleMenu,
    );
  }
}

class _OverflowBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double arrowHeight;
  final double arrowWidth;
  final double arrowOffsetFromRight;
  final double borderRadius;

  const _OverflowBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.arrowHeight,
    required this.arrowWidth,
    required this.arrowOffsetFromRight,
    required this.borderRadius,
  });

  Path _buildBubblePath(Size size) {
    final top = arrowHeight;
    final left = 0.0;
    final right = size.width;
    final bottom = size.height;
    final r = borderRadius;
    final arrowTipX = right - arrowOffsetFromRight;
    final arrowLeftX = arrowTipX - arrowWidth / 2;
    final arrowRightX = arrowTipX + arrowWidth / 2;

    return Path()
      ..moveTo(left + r, top)
      ..lineTo(arrowLeftX, top)
      ..lineTo(arrowTipX - 1.2, 1.2)
      ..quadraticBezierTo(arrowTipX, 0.0, arrowTipX + 1.2, 1.2)
      ..lineTo(arrowRightX, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
      ..lineTo(left + r, bottom)
      ..arcToPoint(Offset(left, bottom - r), radius: Radius.circular(r))
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildBubblePath(size);

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _OverflowBubblePainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        borderColor != oldDelegate.borderColor ||
        shadowColor != oldDelegate.shadowColor ||
        arrowHeight != oldDelegate.arrowHeight ||
        arrowWidth != oldDelegate.arrowWidth ||
        arrowOffsetFromRight != oldDelegate.arrowOffsetFromRight ||
        borderRadius != oldDelegate.borderRadius;
  }
}

