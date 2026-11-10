import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

/// Reusable widget to conditionally display or disable UI elements based on user role permissions.
class RoleGuard extends StatelessWidget {
  final Set<UserRole> allowedRoles;
  final Widget child;
  final Widget? fallback;
  final String? permissionDeniedMessage;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
    this.permissionDeniedMessage,
  });

  /// Factory for Coordinator-only actions (Assign Responder, Close Incident)
  factory RoleGuard.coordinatorOnly({
    Key? key,
    required Widget child,
    Widget? fallback,
    String? message = 'Only Coordinators can perform this action.',
  }) {
    return RoleGuard(
      key: key,
      allowedRoles: const {UserRole.coordinator},
      fallback: fallback,
      permissionDeniedMessage: message,
      child: child,
    );
  }

  /// Factory for Mutating actions (Responders & Coordinators can update status & log resources; Viewers cannot)
  factory RoleGuard.mutations({
    Key? key,
    required Widget child,
    Widget? fallback,
    String? message = 'Viewers have read-only access.',
  }) {
    return RoleGuard(
      key: key,
      allowedRoles: const {UserRole.coordinator, UserRole.responder},
      fallback: fallback,
      permissionDeniedMessage: message,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return fallback ?? const SizedBox.shrink();
        }

        final userRole = state.user.role;
        final hasPermission = allowedRoles.contains(userRole);

        if (hasPermission) {
          return child;
        }

        if (fallback != null) {
          return fallback!;
        }

        return const SizedBox.shrink();
      },
    );
  }
}

