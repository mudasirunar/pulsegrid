import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Reusable animated shimmer box component scoped to the incident feature.
class IncidentShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  const IncidentShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.shape = BoxShape.rectangle,
    this.margin,
  });

  const IncidentShimmerBox.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = BoxShape.circle;

  @override
  State<IncidentShimmerBox> createState() => _IncidentShimmerBoxState();
}

class _IncidentShimmerBoxState extends State<IncidentShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? AppColors.surfaceDark
        : AppColors.borderLight.withValues(alpha: 0.5);
    final highlightColor = isDark
        ? AppColors.borderDark.withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.7);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final ctrlValue = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (ctrlValue - 0.3).clamp(0.0, 1.0),
                ctrlValue.clamp(0.0, 1.0),
                (ctrlValue + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Full screen shimmer skeleton that replicates the exact layout of [IncidentDetailsScreen].
/// Renders without a top-right status chip until the incident data is loaded.
class IncidentDetailsSkeleton extends StatelessWidget {
  const IncidentDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Eyebrow Badges Row Shimmer (Category & Severity on left, Status on right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  IncidentShimmerBox(height: 26, width: 90, borderRadius: 8),
                  SizedBox(width: 8),
                  IncidentShimmerBox(height: 26, width: 76, borderRadius: 8),
                ],
              ),
              const IncidentShimmerBox(height: 26, width: 96, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Incident Title Line Shimmer
          const IncidentShimmerBox(
            height: 26,
            width: 260,
            borderRadius: 6,
          ),
          const SizedBox(height: 8),

          // 3. Metadata Lines Shimmer
          // Reporter + Time ago line
          Row(
            children: const [
              IncidentShimmerBox.circle(size: 15),
              SizedBox(width: 6),
              IncidentShimmerBox(height: 12, width: 190, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 6),

          // Clock + Timestamp line
          Row(
            children: const [
              IncidentShimmerBox.circle(size: 15),
              SizedBox(width: 6),
              IncidentShimmerBox(height: 12, width: 140, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Incident Location Section Shimmer
          const IncidentShimmerBox(height: 14, width: 130, borderRadius: 4),
          const SizedBox(height: 8),
          Row(
            children: const [
              IncidentShimmerBox.circle(size: 15),
              SizedBox(width: 8),
              IncidentShimmerBox(height: 13, width: 180, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: const [
              IncidentShimmerBox.circle(size: 15),
              SizedBox(width: 8),
              IncidentShimmerBox(height: 13, width: 220, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 24),

          // 5. Photo Preview Area Shimmer (Decoupled Image Carousel Box)
          const IncidentShimmerBox(
            height: 220,
            width: double.infinity,
            borderRadius: 14,
          ),
          const SizedBox(height: 24),

          // 6. Sequential Lifecycle Stepper Row Shimmer
          const IncidentShimmerBox(height: 14, width: 120, borderRadius: 4),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < 5; i++) ...[
                if (i > 0)
                  const Expanded(
                    child: IncidentShimmerBox(
                      height: 2,
                      borderRadius: 1,
                      margin: EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ),
                const IncidentShimmerBox.circle(size: 24),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Stepper label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              IncidentShimmerBox(height: 10, width: 28, borderRadius: 3),
              IncidentShimmerBox(height: 10, width: 44, borderRadius: 3),
              IncidentShimmerBox(height: 10, width: 56, borderRadius: 3),
              IncidentShimmerBox(height: 10, width: 44, borderRadius: 3),
              IncidentShimmerBox(height: 10, width: 34, borderRadius: 3),
            ],
          ),
          const SizedBox(height: 22),

          // 7. Action Button Shimmer
          const IncidentShimmerBox(
            height: 50,
            width: double.infinity,
            borderRadius: 24,
          ),
          const SizedBox(height: 28),

          // 8. Allocated Resources Flat Shimmer
          const IncidentShimmerBox(height: 14, width: 160, borderRadius: 4),
          const SizedBox(height: 12),
          const Center(child: IncidentShimmerBox.circle(size: 32)),
          const SizedBox(height: 8),
          const Center(child: IncidentShimmerBox(height: 12, width: 140, borderRadius: 4)),
          const SizedBox(height: 28),

          // 9. Activity Timeline Section Shimmer
          const IncidentShimmerBox(height: 14, width: 140, borderRadius: 4),
          const SizedBox(height: 12),
          const IncidentShimmerBox(
            height: 64,
            width: double.infinity,
            borderRadius: 12,
          ),
          const SizedBox(height: 10),
          const IncidentShimmerBox(
            height: 64,
            width: double.infinity,
            borderRadius: 12,
          ),
        ],
      ),
    );
  }
}

