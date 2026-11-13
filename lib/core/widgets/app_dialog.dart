import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Tactical PulseGrid confirmation & alert dialog.
///
/// Styled with the military olive & tactical solar gold palette,
/// responsive to dark and light modes, featuring icon badging,
/// clear hierarchical typography, and balanced action buttons.
class AppDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String? confirmText;
  final VoidCallback? onConfirm;
  final VoidCallback? onConfirmPressed;
  final bool isConfirmLoading;
  final String? cancelText;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool barrierDismissible;
  final List<Widget>? customActions;

  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.confirmText = 'Confirm',
    this.onConfirm,
    this.onConfirmPressed,
    this.isConfirmLoading = false,
    this.cancelText = 'Cancel',
    this.onCancel,
    this.isDestructive = false,
    this.barrierDismissible = true,
    this.customActions,
  });

  /// Displays the tactical [AppDialog] with a smooth scale and fade transition.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    IconData? icon,
    Color? iconColor,
    Color? iconBackgroundColor,
    String? confirmText = 'Confirm',
    VoidCallback? onConfirm,
    Future<void> Function()? onAsyncConfirm,
    String? cancelText = 'Cancel',
    VoidCallback? onCancel,
    bool isDestructive = false,
    List<Widget>? customActions,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        if (onAsyncConfirm == null) {
          return AppDialog(
            title: title,
            message: message,
            content: content,
            icon: icon,
            iconColor: iconColor,
            iconBackgroundColor: iconBackgroundColor,
            confirmText: confirmText,
            onConfirm: onConfirm,
            cancelText: cancelText,
            onCancel: onCancel,
            isDestructive: isDestructive,
            barrierDismissible: barrierDismissible,
            customActions: customActions,
          );
        }

        bool isLoading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AppDialog(
              title: title,
              message: message,
              content: content,
              icon: icon,
              iconColor: iconColor,
              iconBackgroundColor: iconBackgroundColor,
              confirmText: confirmText,
              isConfirmLoading: isLoading,
              onConfirmPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      try {
                        await onAsyncConfirm();
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          setDialogState(() => isLoading = false);
                        }
                      }
                    },
              cancelText: cancelText,
              onCancel: onCancel,
              isDestructive: isDestructive,
              barrierDismissible: barrierDismissible && !isLoading,
              customActions: customActions,
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultIconColor = isDestructive
        ? AppColors.severityCritical
        : (isDark ? AppColors.accentDark : AppColors.primaryLight);

    final effectiveIconColor = iconColor ?? defaultIconColor;

    final effectiveIconBg = iconBackgroundColor ??
        (isDestructive
            ? (isDark
                ? AppColors.severityCriticalContainerDark
                : AppColors.severityCriticalContainerLight)
            : (isDark
                ? AppColors.accentDark.withValues(alpha: 0.15)
                : AppColors.primaryContainerLight));

    final confirmBg = isDestructive
        ? AppColors.severityCritical
        : (isDark ? AppColors.accentDark : AppColors.primaryLight);

    final confirmFg = isDestructive
        ? Colors.white
        : (isDark ? AppColors.backgroundDark : Colors.white);

    return PopScope(
      canPop: barrierDismissible && !isConfirmLoading,
      child: Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 24.0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Icon Badge
                if (icon != null) ...[
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: effectiveIconBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: effectiveIconColor.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          color: effectiveIconColor,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),

                // Message or Content
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
                if (content != null) ...[
                  const SizedBox(height: 14),
                  content!,
                ],

                const SizedBox(height: 22),

                // Action Buttons
                if (customActions != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: customActions!,
                  )
                else
                  Row(
                    children: [
                      // Cancel Button
                      if (cancelText != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isConfirmLoading
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                    onCancel?.call();
                                  },
                            child: Text(
                              cancelText!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Confirm Button
                      if (confirmText != null)
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: confirmBg,
                              foregroundColor: confirmFg,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isConfirmLoading
                                ? null
                                : (onConfirmPressed ??
                                    () {
                                      Navigator.of(context).pop();
                                      onConfirm?.call();
                                    }),
                            child: isConfirmLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        confirmFg,
                                      ),
                                    ),
                                  )
                                : Text(
                                    confirmText!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

