import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// 3-way visual theme selector matching the System | Light | Dark phone-mockup strip.
class ThemePreviewSelector extends StatelessWidget {
  final ThemeMode selectedMode;
  final bool hapticEnabled;
  final ValueChanged<ThemeMode> onThemeSelected;

  const ThemePreviewSelector({
    super.key,
    required this.selectedMode,
    required this.hapticEnabled,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ThemeOptionTile(
              label: 'System',
              mode: ThemeMode.system,
              isSelected: selectedMode == ThemeMode.system,
              onTap: () => _handleTap(ThemeMode.system),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ThemeOptionTile(
              label: 'Light',
              mode: ThemeMode.light,
              isSelected: selectedMode == ThemeMode.light,
              onTap: () => _handleTap(ThemeMode.light),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ThemeOptionTile(
              label: 'Dark',
              mode: ThemeMode.dark,
              isSelected: selectedMode == ThemeMode.dark,
              onTap: () => _handleTap(ThemeMode.dark),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(ThemeMode mode) {
    if (hapticEnabled) {
      HapticFeedback.selectionClick();
    }
    onThemeSelected(mode);
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.label,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final textColor = isSelected
        ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);
    final unselectedRingColor =
        isDark ? AppColors.borderDark : const Color(0xFFBDBDBD);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.03 : 0.97,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _PhoneMockupPreview(
              mode: mode,
              isSelected: isSelected,
              accentColor: primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? primary : Colors.transparent,
              border: Border.all(
                color: isSelected ? primary : unselectedRingColor,
                width: 1.8,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('checked'),
                      size: 14,
                      color: Colors.white,
                    )
                  : const SizedBox.shrink(key: ValueKey('unchecked')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneMockupPreview extends StatelessWidget {
  final ThemeMode mode;
  final bool isSelected;
  final Color accentColor;

  const _PhoneMockupPreview({
    required this.mode,
    required this.isSelected,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isAppDark = Theme.of(context).brightness == Brightness.dark;
    final outerBorder = isSelected
        ? accentColor
        : (isAppDark ? AppColors.borderDark : const Color(0xFFD5D2CB));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 66,
      height: 112,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: outerBorder,
          width: isSelected ? 2.0 : 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: switch (mode) {
          ThemeMode.light => const _HalfPhoneFace(isDarkFace: false),
          ThemeMode.dark => const _HalfPhoneFace(isDarkFace: true),
          ThemeMode.system => LayoutBuilder(
              builder: (context, constraints) {
                final fullWidth = constraints.maxWidth;
                return Row(
                  children: [
                    Expanded(
                      child: ClipRect(
                        child: OverflowBox(
                          minWidth: fullWidth,
                          maxWidth: fullWidth,
                          alignment: Alignment.centerLeft,
                          child: const _HalfPhoneFace(isDarkFace: false),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: OverflowBox(
                          minWidth: fullWidth,
                          maxWidth: fullWidth,
                          alignment: Alignment.centerRight,
                          child: const _HalfPhoneFace(isDarkFace: true),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        },
      ),
    );
  }
}

class _HalfPhoneFace extends StatelessWidget {
  final bool isDarkFace;

  const _HalfPhoneFace({required this.isDarkFace});

  @override
  Widget build(BuildContext context) {
    final bg = isDarkFace ? const Color(0xFF0E100F) : const Color(0xFFF3F4F6);
    final pillColor =
        isDarkFace ? const Color(0xFF6B7280) : const Color(0xFF1F2937);
    final dotColor =
        isDarkFace ? const Color(0xFF2B302C) : const Color(0xFFD1D5DB);
    final cardColor =
        isDarkFace ? const Color(0xFF1D211E) : const Color(0xFFFFFFFF);
    final tileLeft =
        isDarkFace ? const Color(0xFF2E2417) : const Color(0xFFEDE2D6);
    final tileRight =
        isDarkFace ? const Color(0xFF162C25) : const Color(0xFFD5EDE5);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top status pill
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          // 4 mini header dots
          Row(
            children: List.generate(
              4,
              (index) => Container(
                width: 8,
                height: 3.5,
                margin: EdgeInsets.only(right: index < 3 ? 3.5 : 0),
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Main preview card
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Tiny divider pill
          Container(
            width: 10,
            height: 3,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(height: 4),
          // Two bottom accent tiles
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: tileLeft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: tileRight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

