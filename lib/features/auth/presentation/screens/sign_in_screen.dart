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
import '../widgets/sign_in_header.dart';

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
      body: BlocConsumer<AuthBloc, AuthState>(
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

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Tactical Chamfer Header (Concept 1)
                TacticalChamferHeader(isDark: isDark),

                const SizedBox(height: 24),

                // Center Form Body (Responsive)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Role Segmented Horizontal Toggle
                          Text(
                            'SELECT OPERATIONAL ROLE',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildHorizontalRoleToggle(context, isDark),
                          const SizedBox(height: 8),

                          // Role description caption with fixed height to prevent layout jump
                          SizedBox(
                            height: 34,
                            child: Center(
                              child: Text(
                                _getRoleCaption(_selectedRole),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

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
                                  customForegroundColor: Colors.white,
                                  onPressed: isLoading ? null : _onSignIn,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalRoleToggle(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final bgColor = isDark
        ? AppColors.surfaceDark
        : AppColors.borderLight.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Row(
        children: UserRole.values.map((role) {
          final isSelected = _selectedRole == role;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onRoleSelected(role),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? theme.colorScheme.primary : AppColors.surfaceLight)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  role.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark
                            ? theme.colorScheme.onPrimary
                            : AppColors.textPrimaryLight)
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
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
        return 'Full control to create, assign, and close incidents.';
      case UserRole.responder:
        return 'Field work to update assigned incidents and log resources.';
      case UserRole.viewer:
        return 'Strictly read-only monitoring of all metrics and reports.';
    }
  }
}
