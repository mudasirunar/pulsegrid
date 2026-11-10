import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppButtonVariant {
  primary,
  outlined,
  destructive,
  secondary,
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final Color? customBackgroundColor;
  final Color? customForegroundColor;
  final double borderRadius;
  final double height;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.customBackgroundColor,
    this.customForegroundColor,
    this.borderRadius = 8.0,
    this.height = 48.0,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveDisabled = isDisabled || isLoading || onPressed == null;

    final (bgColor, fgColor, borderColor) = _getColors(theme, effectiveDisabled);

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 18, color: fgColor),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: fgColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!isLoading && trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: 18, color: fgColor),
        ],
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: borderColor != null
          ? BorderSide(color: borderColor, width: 1.5)
          : BorderSide.none,
    );

    Widget button = Material(
      color: bgColor,
      shape: shape,
      child: InkWell(
        onTap: effectiveDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    if (isFullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return button;
  }

  (Color bg, Color fg, Color? border) _getColors(ThemeData theme, bool disabled) {
    if (disabled) {
      final disabledBg = theme.brightness == Brightness.dark
          ? AppColors.borderDark
          : AppColors.borderLight;
      final disabledFg = theme.brightness == Brightness.dark
          ? AppColors.textSecondaryDark
          : AppColors.textSecondaryLight;
      return (disabledBg, disabledFg, null);
    }

    if (customBackgroundColor != null) {
      return (
        customBackgroundColor!,
        customForegroundColor ?? Colors.white,
        null,
      );
    }

    switch (variant) {
      case AppButtonVariant.primary:
        return (
          theme.colorScheme.primary,
          Colors.white,
          null,
        );
      case AppButtonVariant.outlined:
        return (
          Colors.transparent,
          customForegroundColor ?? theme.colorScheme.primary,
          customForegroundColor ?? theme.colorScheme.primary,
        );
      case AppButtonVariant.destructive:
        return (
          AppColors.severityCritical,
          Colors.white,
          null,
        );
      case AppButtonVariant.secondary:
        final bg = theme.brightness == Brightness.dark
            ? AppColors.surfaceDark
            : AppColors.backgroundLight;
        final fg = theme.brightness == Brightness.dark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight;
        final border = theme.brightness == Brightness.dark
            ? AppColors.borderDark
            : AppColors.borderLight;
        return (bg, fg, border);
    }
  }
}

