import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/incident_status.dart';

class IncidentLifecycleStepper extends StatelessWidget {
  final IncidentStatus currentStatus;

  const IncidentLifecycleStepper({
    super.key,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const completedGreen = Color(0xFF22C55E);
    final activeColor = isDark ? AppColors.accentDark : AppColors.primaryLight;
    const activeTextColor = Colors.white;

    const statuses = [
      IncidentStatus.newIncident,
      IncidentStatus.assigned,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.closed,
    ];
    final currentIndex = statuses.indexOf(currentStatus);
    final isClosed = currentStatus == IncidentStatus.closed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const circleSize = 24.0;
        final stepSpacing = (totalWidth - circleSize) / (statuses.length - 1);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Circles and connecting lines with equal 6px gap to every circle
            Row(
              children: [
                for (int i = 0; i < statuses.length; i++) ...[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        height: 2,
                        decoration: BoxDecoration(
                          color: (isClosed || i <= currentIndex)
                              ? completedGreen
                              : (isDark ? AppColors.borderDark : Colors.grey.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  Builder(
                    builder: (context) {
                      final isPassed = isClosed || i < currentIndex;
                      final isActive = !isClosed && i == currentIndex;

                      return CircleAvatar(
                        radius: 12,
                        backgroundColor: isPassed
                            ? completedGreen
                            : isActive
                                ? activeColor
                                : (isDark ? AppColors.surfaceDark : Colors.grey.withValues(alpha: 0.2)),
                        child: isPassed
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? activeTextColor
                                      : (isDark ? AppColors.textSecondaryDark : Colors.grey),
                                ),
                              ),
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // 2. Labels centered directly beneath their corresponding circle
            SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int i = 0; i < statuses.length; i++) ...[
                    Builder(
                      builder: (context) {
                        final center = 12.0 + i * stepSpacing;
                        const labelWidth = 72.0;
                        final isHighlighted = (isClosed && i == statuses.length - 1) ||
                            (!isClosed && i == currentIndex);
                        final status = statuses[i];

                        return Positioned(
                          left: center - (labelWidth / 2),
                          width: labelWidth,
                          child: Text(
                            status.displayName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                              color: isHighlighted
                                  ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

