import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_role.dart';

class UserProfileHeader extends StatelessWidget {
  final UserModel user;

  const UserProfileHeader({
    super.key,
    required this.user,
  });

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.coordinator:
        return AppColors.primaryLight;
      case UserRole.responder:
        return AppColors.severityMedium;
      case UserRole.viewer:
        return AppColors.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final roleColor = _roleColor(user.role);

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Icon(
            user.role == UserRole.coordinator
                ? Icons.admin_panel_settings_outlined
                : user.role == UserRole.responder
                    ? Icons.medical_services_outlined
                    : Icons.visibility_outlined,
            color: roleColor,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (user.rank != null && user.rank!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  user.rank!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? AppColors.accentDark : AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                user.email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        AppBadge(
          text: user.role.displayName.toUpperCase(),
          color: roleColor,
        ),
      ],
    );
  }
}

