import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppSnackBarType {
  error,
  success,
  warning,
  info,
}

/// Custom tactical SnackBar for Pulse Grid.
/// Supports error, success, warning, and info notifications.
class AppSnackBar {
  const AppSnackBar._();

  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title ?? 'Authentication Error',
      type: AppSnackBarType.error,
      duration: duration,
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title ?? 'Success',
      type: AppSnackBarType.success,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title ?? 'Warning',
      type: AppSnackBarType.warning,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title ?? 'Information',
      type: AppSnackBarType.info,
      duration: duration,
    );
  }

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    AppSnackBarType type = AppSnackBarType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (primaryColor, bgColor, iconData) = switch (type) {
      AppSnackBarType.error => (
          AppColors.severityCritical,
          isDark ? const Color(0xFF241515) : const Color(0xFFFEF2F2),
          Icons.error_outline_rounded,
        ),
      AppSnackBarType.success => (
          AppColors.statusResolved,
          isDark ? const Color(0xFF142418) : const Color(0xFFF0FDF4),
          Icons.check_circle_outline_rounded,
        ),
      AppSnackBarType.warning => (
          AppColors.severityMedium,
          isDark ? const Color(0xFF262013) : const Color(0xFFFFFBEB),
          Icons.warning_amber_rounded,
        ),
      AppSnackBarType.info => (
          isDark ? AppColors.accentDark : AppColors.primaryLight,
          isDark ? const Color(0xFF161E28) : const Color(0xFFEFF6FF),
          Icons.info_outline_rounded,
        ),
    };

    final textColor = isDark ? Colors.white : const Color(0xFF1C1F1A);
    final subtextColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : const Color(0xFF4B5563);

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: EdgeInsets.zero,
        duration: duration,
        content: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primaryColor.withValues(alpha: isDark ? 0.45 : 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Accent Indicator Strip
                Container(
                  width: 5,
                  color: primaryColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icon Badge
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            iconData,
                            size: 20,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Text Area
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (title != null && title.isNotEmpty) ...[
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                message,
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Close Action
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: subtextColor,
                          ),
                          splashRadius: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () {
                            messenger.hideCurrentSnackBar();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

