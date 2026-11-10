import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController(text: AuthRepositoryImpl.coordinatorEmail);
  final _passwordController = TextEditingController(text: AuthRepositoryImpl.defaultPassword);
  final _formKey = GlobalKey<FormState>();

  UserRole _selectedRole = UserRole.coordinator;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onRoleSelected(UserRole role) {
    setState(() {
      _selectedRole = role;
      switch (role) {
        case UserRole.coordinator:
          _emailController.text = AuthRepositoryImpl.coordinatorEmail;
          break;
        case UserRole.responder:
          _emailController.text = AuthRepositoryImpl.responderEmail;
          break;
        case UserRole.viewer:
          _emailController.text = AuthRepositoryImpl.viewerEmail;
          break;
      }
      _passwordController.text = AuthRepositoryImpl.defaultPassword;
    });
  }

  void _onSignIn() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            SignInWithEmailPasswordEvent(
              email: _emailController.text,
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.severityCritical,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Mark & Titles
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.crisis_alert_rounded,
                            size: 34,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PULSE GRID',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Offline-First Incident & Resource Coordination',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Role Segmented Horizontal Toggle
                      Text(
                        'SELECT OPERATIONAL ROLE',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildHorizontalRoleToggle(context, isDark),
                      const SizedBox(height: 8),

                      // Role description caption
                      Text(
                        _getRoleCaption(_selectedRole),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _emailController,
                              label: 'Email',
                              hintText: 'name@pulsegrid.org',
                              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              borderRadius: 24.0,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hintText: '••••••••',
                              obscureText: _obscurePassword,
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              textInputAction: TextInputAction.done,
                              onEditingComplete: _onSignIn,
                              borderRadius: 24.0,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Password is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            AppButton(
                              text: 'Sign In',
                              isLoading: isLoading,
                              borderRadius: 24.0,
                              height: 50.0,
                              onPressed: isLoading ? null : _onSignIn,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalRoleToggle(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.borderLight.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: UserRole.values.map((role) {
          final isSelected = _selectedRole == role;
          final activeColor = role == UserRole.coordinator
              ? AppColors.primaryBlueLight
              : role == UserRole.responder
                  ? AppColors.severityMedium
                  : AppColors.primaryNavyLight;

          return Expanded(
            child: GestureDetector(
              onTap: () => _onRoleSelected(role),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? theme.colorScheme.primary : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        role == UserRole.coordinator
                            ? Icons.admin_panel_settings_rounded
                            : role == UserRole.responder
                                ? Icons.medical_services_rounded
                                : Icons.visibility_rounded,
                        size: 15,
                        color: isSelected
                            ? (isDark ? Colors.white : activeColor)
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          role.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getRoleCaption(UserRole role) {
    switch (role) {
      case UserRole.coordinator:
        return 'Coordinator: Full control to create, assign, and close incidents.';
      case UserRole.responder:
        return 'Responder: Field work to update assigned incidents and log resources.';
      case UserRole.viewer:
        return 'Viewer: Strictly read-only monitoring of all metrics and reports.';
    }
  }
}
