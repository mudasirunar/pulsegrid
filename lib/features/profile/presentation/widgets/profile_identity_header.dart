import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_role.dart';

/// Flat identity header displaying user name (with edit trigger), email, and role badge.
class ProfileIdentityHeader extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEditNamePressed;

  const ProfileIdentityHeader({
    super.key,
    required this.user,
    required this.onEditNamePressed,
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                user.displayName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit display name',
              onPressed: onEditNamePressed,
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: textSecondary,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (user.rank != null && user.rank!.trim().isNotEmpty) ...[
          Text(
            '(${user.rank!.trim()})',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
        ],
        const SizedBox(height: 2),
        Text(
          user.email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: AppBadge(
            text: _roleLabel(user.role),
            color: _roleColor(user.role),
            icon: _roleIcon(user.role),
            borderRadius: 12.0,
            fontSize: 12.0,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
          ),
        ),
      ],
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.coordinator:
        return 'Coordinator';
      case UserRole.responder:
        return 'Responder';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.coordinator:
        return AppColors.accentLight;
      case UserRole.responder:
        return AppColors.severityHigh;
      case UserRole.viewer:
        return AppColors.statusNew;
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.coordinator:
        return Icons.admin_panel_settings_outlined;
      case UserRole.responder:
        return Icons.shield_outlined;
      case UserRole.viewer:
        return Icons.visibility_outlined;
    }
  }
}

