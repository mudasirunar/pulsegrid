import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/widgets/role_guard.dart';
import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/presentation/bloc/incident_bloc.dart';
import '../../../incidents/presentation/bloc/incident_state.dart';
import '../../../incidents/presentation/screens/create_incident_screen.dart';
import '../../../incidents/presentation/screens/incident_details_screen.dart';
import '../../../incidents/presentation/widgets/incident_card.dart';
import '../widgets/quick_role_switcher.dart';
import '../widgets/role_capabilities_section.dart';
import '../widgets/user_profile_header.dart';

class HomeScreen extends StatelessWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 108.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. User Session Profile Header (Extracted Reusable Component)
            UserProfileHeader(user: user),

            Divider(
              height: 36,
              thickness: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),

            // 2. Active Incidents Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVE INCIDENTS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                if (!user.role.isReadOnly)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateIncidentScreen(currentUser: user),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Report', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            BlocBuilder<IncidentBloc, IncidentState>(
              builder: (context, state) {
                if (state is IncidentLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                List<IncidentEntity> incidents = [];
                if (state is IncidentLoaded) {
                  incidents = state.incidents;
                } else if (state is IncidentCreatedSuccess) {
                  incidents = state.incidents;
                } else if (state is IncidentOperationSuccess) {
                  incidents = state.incidents;
                } else if (state is IncidentDeletedSuccess) {
                  incidents = state.incidents;
                } else if (state is IncidentOperating) {
                  incidents = state.incidents;
                }

                if (incidents.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.borderLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.emergency_outlined,
                          size: 36,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No Emergency Incidents Reported',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "+ Report Incident" to log and dispatch field responders.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: incidents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final inc = incidents[index];
                    return IncidentCard(
                      incident: inc,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IncidentDetailsScreen(
                              incident: inc,
                              currentUser: user,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),

            Divider(
              height: 36,
              thickness: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),

            // 3. Active Role Capabilities Section (Extracted Reusable Component)
            RoleCapabilitiesSection(role: user.role),

            Divider(
              height: 36,
              thickness: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),

            // 4. Role Guard Action Section
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

            // 5. Quick Role Switcher (Extracted Reusable Component)
            const QuickRoleSwitcher(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
