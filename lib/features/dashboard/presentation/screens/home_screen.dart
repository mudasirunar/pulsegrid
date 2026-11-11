import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/widgets/role_guard.dart';

class HomeScreen extends StatelessWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pulse Grid Field Ops'),
        actions: [
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () {
              context.read<ThemeCubit>().toggleTheme(MediaQuery.of(context).platformBrightness);
            },
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () {
              context.read<AuthBloc>().add(const SignOutEvent());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. User Session Profile (Flat on screen)
            Row(
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
            ),

            // Section Divider
            Divider(
              height: 36,
              thickness: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),

            // 2. Active Role Capabilities Section (Flat)
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
              context,
              label: 'Create Incidents',
              allowed: !user.role.isReadOnly,
            ),
            _buildPermissionRow(
              context,
              label: 'Assign Incidents to Responders',
              allowed: user.role.canAssignAndClose,
            ),
            _buildPermissionRow(
              context,
              label: 'Update Status & Log Resources',
              allowed: user.role.canUpdateAssignedAndLogResources,
            ),
            _buildPermissionRow(
              context,
              label: 'Close Incidents (Final Approval)',
              allowed: user.role.canAssignAndClose,
            ),

            // Section Divider
            Divider(
              height: 36,
              thickness: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),

            // 3. Role Guard Action Section (Flat)
            Text(
              'ROLE-BASED ACTION GUARDS',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Buttons below demonstrate dynamic role guarding per specification:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 14),

            // Coordinator Only Action
            RoleGuard.coordinatorOnly(
              fallback: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.borderLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Coordinator Only: "Close Incident" action hidden for this role.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              child: AppButton(
                text: 'Close Incident (Coordinator Permission)',
                leadingIcon: Icons.check_circle_outline,
                variant: AppButtonVariant.destructive,
                onPressed: () {},
              ),
            ),
            const SizedBox(height: 12),

            // Responder & Coordinator Action (Mutations)
            RoleGuard.mutations(
              fallback: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.borderLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Viewers: All edit & resource logging actions disabled.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              child: AppButton(
                text: 'Log Resources & Update Status',
                leadingIcon: Icons.add_circle_outline,
                variant: AppButtonVariant.primary,
                onPressed: () {},
              ),
            ),
            const SizedBox(height: 28),

            // 4. Quick Role Switcher (Flat)
            Text(
              'SWITCH ROLE (DEMO / REVIEW)',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Coordinator',
                    variant: AppButtonVariant.outlined,
                    height: 38,
                    onPressed: () {
                      context.read<AuthBloc>().add(
                            const SignInWithRoleEvent(UserRole.coordinator),
                          );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    text: 'Responder',
                    variant: AppButtonVariant.outlined,
                    height: 38,
                    onPressed: () {
                      context.read<AuthBloc>().add(
                            const SignInWithRoleEvent(UserRole.responder),
                          );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    text: 'Viewer',
                    variant: AppButtonVariant.outlined,
                    height: 38,
                    onPressed: () {
                      context.read<AuthBloc>().add(
                            const SignInWithRoleEvent(UserRole.viewer),
                          );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow(
    BuildContext context, {
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

