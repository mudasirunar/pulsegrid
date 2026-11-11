import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/user_role.dart';

class RoleCapabilitiesSection extends StatelessWidget {
  final UserRole role;

  const RoleCapabilitiesSection({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ACTIVE ROLE CAPABILITIES',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 12),
        _buildPermissionRow(
          label: 'Create Incidents',
          allowed: !role.isReadOnly,
        ),
        _buildPermissionRow(
          label: 'Assign Incidents to Responders',
          allowed: role.canAssignAndClose,
        ),
        _buildPermissionRow(
          label: 'Update Status & Log Resources',
          allowed: role.canUpdateAssignedAndLogResources,
        ),
        _buildPermissionRow(
          label: 'Close Incidents (Final Approval)',
          allowed: role.canAssignAndClose,
        ),
      ],
    );
  }

  Widget _buildPermissionRow({
    required String label,
    required bool allowed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: allowed ? AppColors.syncSynced : AppColors.severityCritical,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: allowed ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            allowed ? 'Allowed' : 'Restricted',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: allowed ? AppColors.syncSynced : AppColors.severityCritical,
            ),
          ),
        ],
      ),
    );
  }
}

