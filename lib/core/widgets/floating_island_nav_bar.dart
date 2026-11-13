import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A two-part floating island bottom navigation bar:
/// - Left stadium pill dock (~75% width) with draggable, liquid-stretching
///   active pill switching between Home (0) and Profile (1).
/// - Right standalone circular CTA button (`64x64`) for creating an incident.
class FloatingIslandNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onActionPressed;
  final bool showActionButton;

  const FloatingIslandNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.onActionPressed,
    this.showActionButton = true,
  });

  @override
  State<FloatingIslandNavBar> createState() => _FloatingIslandNavBarState();
}

class _FloatingIslandNavBarState extends State<FloatingIslandNavBar>
    with SingleTickerProviderStateMixin {
  static const double _barHeight = 64.0;
  static const double _dockInnerPadding = 6.0;
  static const double _splitGap = 12.0;

  static const SpringDescription _spring = SpringDescription(
    mass: 1.0,
    stiffness: 320.0,
    damping: 18.0,
  );

  late final AnimationController _controller;
  bool _isDragging = false;
  bool _ctaPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.currentIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant FloatingIslandNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_isDragging) {
      _animateTo(widget.currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target, {double velocity = 0.0}) {
    final simulation = SpringSimulation(
      _spring,
      _controller.value,
      target,
      velocity,
    );
    _controller.animateWith(simulation);
  }

  void _selectIndex(int index, {double velocity = 0.0}) {
    if (index != widget.currentIndex) {
      HapticFeedback.selectionClick();
      widget.onTabSelected(index);
    }
    _animateTo(index.toDouble(), velocity: velocity);
  }

  void _handleTapUp(TapUpDetails details, double trackWidth) {
    final target = details.localPosition.dx < trackWidth * 0.5 ? 0 : 1;
    _selectIndex(target);
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details, double basePillWidth) {
    if (basePillWidth <= 0) return;
    final delta = (details.primaryDelta ?? 0.0) / basePillWidth;
    _controller.value = (_controller.value + delta).clamp(-0.06, 1.06);
  }

  void _handleDragEnd(DragEndDetails details, double basePillWidth) {
    _isDragging = false;
    final pxVelocity = details.primaryVelocity ?? 0.0;
    final unitVelocity =
        basePillWidth > 0 ? (pxVelocity / basePillWidth).clamp(-4.0, 4.0) : 0.0;

    final int target;
    if (pxVelocity > 240) {
      target = 1;
    } else if (pxVelocity < -240) {
      target = 0;
    } else {
      target = _controller.value >= 0.5 ? 1 : 0;
    }

    _selectIndex(target, velocity: unitVelocity);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Surface & depth tokens
    final dockSurface = isDark ? const Color(0xFF1B1C20) : Colors.white;
    final dockBorder =
        isDark ? const Color(0xFF2E3036) : AppColors.borderLight;
    final dockShadow = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.08);

    // Amber / Gold accent tokens
    final activeColor =
        isDark ? const Color(0xFFF5A623) : const Color(0xFFD97706);
    final inactiveColor =
        isDark ? const Color(0xFF7D838E) : AppColors.textSecondaryLight;
    final pillColor = isDark
        ? const Color(0xFFF5A623).withValues(alpha: 0.16)
        : const Color(0xFFD97706).withValues(alpha: 0.13);

    const ctaColor = Color(0xFFF59E0B);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18.0, 0.0, 18.0, 12.0),
        child: Row(
          children: [
            // Left Pill Dock (~75% width)
            Expanded(
              child: Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  color: dockSurface,
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                  border: Border.all(color: dockBorder, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: dockShadow,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final trackWidth = constraints.maxWidth;
                    final innerWidth = trackWidth - (_dockInnerPadding * 2);
                    final basePillWidth = innerWidth / 2;
                    final basePillHeight =
                        _barHeight - (_dockInnerPadding * 2);

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleTapUp(details, trackWidth),
                      onHorizontalDragStart: _handleDragStart,
                      onHorizontalDragUpdate: (details) =>
                          _handleDragUpdate(details, basePillWidth),
                      onHorizontalDragEnd: (details) =>
                          _handleDragEnd(details, basePillWidth),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final progress = _controller.value;
                          final clamped = progress.clamp(0.0, 1.0);

                          // Liquid stretch & squash across the center gap
                          final travel = math.sin(math.pi * clamped);
                          final overshoot = progress < 0.0
                              ? -progress
                              : (progress > 1.0 ? progress - 1.0 : 0.0);
                          final stretchFactor =
                              1.0 + (0.16 * travel) + (overshoot * 0.25);
                          final squashFactor = 1.0 - (0.10 * travel);

                          final pillWidth = (basePillWidth * stretchFactor)
                              .clamp(basePillWidth, innerWidth);
                          final pillHeight = basePillHeight * squashFactor;

                          final restCenterLeft =
                              _dockInnerPadding + (basePillWidth * 0.5);
                          final restCenterRight =
                              _dockInnerPadding + (basePillWidth * 1.5);
                          final centerX = lerpDouble(
                            restCenterLeft,
                            restCenterRight,
                            clamped,
                          )!;
                          final pillLeft = (centerX - (pillWidth * 0.5)).clamp(
                            _dockInnerPadding,
                            trackWidth - _dockInnerPadding - pillWidth,
                          );
                          final pillTop = (_barHeight - pillHeight) * 0.5;

                          // Smooth color morphing based on pill coverage
                          final homeCoverage =
                              (1.0 - (clamped - 0.0).abs() * 1.35)
                                  .clamp(0.0, 1.0);
                          final profileCoverage =
                              (1.0 - (clamped - 1.0).abs() * 1.35)
                                  .clamp(0.0, 1.0);

                          final homeColor = Color.lerp(
                            inactiveColor,
                            activeColor,
                            homeCoverage,
                          )!;
                          final profileColor = Color.lerp(
                            inactiveColor,
                            activeColor,
                            profileCoverage,
                          )!;

                          return Stack(
                            children: [
                              // Liquid tinted active pill
                              Positioned(
                                left: pillLeft,
                                top: pillTop,
                                width: pillWidth,
                                height: pillHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: pillColor,
                                    borderRadius: BorderRadius.circular(
                                      pillHeight / 2,
                                    ),
                                  ),
                                ),
                              ),

                              // Foreground labels & icons
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _dockInnerPadding,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _NavTabItem(
                                          icon: homeCoverage >= 0.5
                                              ? Icons.home_rounded
                                              : Icons.home_outlined,
                                          label: 'Home',
                                          color: homeColor,
                                          isActive: homeCoverage >= 0.5,
                                        ),
                                      ),
                                      Expanded(
                                        child: _NavTabItem(
                                          icon: profileCoverage >= 0.5
                                              ? Icons.person_rounded
                                              : Icons.person_outline_rounded,
                                          label: 'Profile',
                                          color: profileColor,
                                          isActive: profileCoverage >= 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            if (widget.showActionButton) ...[
              const SizedBox(width: _splitGap),

              // Right Action Circle (64x64 standalone CTA)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _ctaPressed = true),
                onTapUp: (_) {
                  setState(() => _ctaPressed = false);
                  HapticFeedback.lightImpact();
                  widget.onActionPressed?.call();
                },
                onTapCancel: () => setState(() => _ctaPressed = false),
                child: AnimatedScale(
                  scale: _ctaPressed ? 0.90 : 1.0,
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: _barHeight,
                    height: _barHeight,
                    decoration: const BoxDecoration(
                      color: ctaColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;

  const _NavTabItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isActive,
      button: true,
      label: label,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 14.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
