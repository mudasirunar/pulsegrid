import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

class QuickRoleSwitcher extends StatelessWidget {
  const QuickRoleSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}

