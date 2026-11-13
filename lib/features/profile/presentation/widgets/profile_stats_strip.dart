import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/profile_stats.dart';

/// Role-aware 3-column hairline stats strip for Coordinator & Responder.
/// Completely hidden for Viewer.
class ProfileStatsStrip extends StatelessWidget {
  final UserRole role;
  final ProfileStats stats;

  const ProfileStatsStrip({
    super.key,
    required this.role,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    if (role == UserRole.viewer) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final List<({String label, int count})> items = role == UserRole.coordinator
        ? [
            (label: 'Reported', count: stats.primaryCount),
            (label: 'Assigned Out', count: stats.secondaryCount),
            (label: 'Closed', count: stats.tertiaryCount),
          ]
        : [
            (label: 'Assigned', count: stats.primaryCount),
            (label: 'In Progress', count: stats.secondaryCount),
            (label: 'Resolved', count: stats.tertiaryCount),
          ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 30,
                color: borderColor,
              ),
            Expanded(
              child: _StatColumn(
                label: items[i].label,
                count: items[i].count,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final int count;

  const _StatColumn({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
