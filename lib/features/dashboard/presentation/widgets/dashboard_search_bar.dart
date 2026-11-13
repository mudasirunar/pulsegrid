import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'dashboard_filter_state.dart';

/// Pill search input + filter trigger button + removable active filter chips.
class DashboardSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final DashboardFilterState filterState;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenFilters;
  final ValueChanged<DashboardFilterState> onFilterChanged;
  final VoidCallback onClearAllFilters;

  const DashboardSearchBar({
    super.key,
    required this.controller,
    required this.filterState,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onOpenFilters,
    required this.onFilterChanged,
    required this.onClearAllFilters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final activeColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by title or ID...',
                  hintStyle: TextStyle(fontSize: 14, color: secondaryText),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: secondaryText,
                  ),
                  suffixIcon: filterState.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: secondaryText,
                          ),
                          onPressed: onClearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(color: activeColor, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _FilterTriggerButton(
              activeCount: filterState.activeCount,
              isDark: isDark,
              borderColor: borderColor,
              onTap: onOpenFilters,
            ),
          ],
        ),
        if (filterState.activeCount > 0) ...[
          const SizedBox(height: 12),
          _ActiveFilterChipsRow(
            filterState: filterState,
            isDark: isDark,
            borderColor: borderColor,
            activeColor: activeColor,
            onFilterChanged: onFilterChanged,
            onClearAll: onClearAllFilters,
          ),
        ],
      ],
    );
  }
}

class _FilterTriggerButton extends StatelessWidget {
  final int activeCount;
  final bool isDark;
  final Color borderColor;
  final VoidCallback onTap;

  const _FilterTriggerButton({
    required this.activeCount,
    required this.isDark,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.0),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: activeCount > 0
              ? activeColor.withValues(alpha: isDark ? 0.14 : 0.08)
              : surface,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(
            color: activeCount > 0 ? activeColor : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 18,
              color: activeCount > 0
                  ? activeColor
                  : (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$activeCount',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterChipsRow extends StatelessWidget {
  final DashboardFilterState filterState;
  final bool isDark;
  final Color borderColor;
  final Color activeColor;
  final ValueChanged<DashboardFilterState> onFilterChanged;
  final VoidCallback onClearAll;

  const _ActiveFilterChipsRow({
    required this.filterState,
    required this.isDark,
    required this.borderColor,
    required this.activeColor,
    required this.onFilterChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filterState.statusFilter != DashboardStatusFilter.all) {
      chips.add(_RemovableFilterChip(
        label: 'Status: ${filterState.statusFilter.label}',
        isDark: isDark,
        borderColor: borderColor,
        onRemove: () => onFilterChanged(
          filterState.copyWith(statusFilter: DashboardStatusFilter.all),
        ),
      ));
    }
    if (filterState.severityFilter != null) {
      chips.add(_RemovableFilterChip(
        label: 'Severity: ${filterState.severityFilter!.displayName}',
        isDark: isDark,
        borderColor: borderColor,
        onRemove: () => onFilterChanged(
          filterState.copyWith(clearSeverity: true),
        ),
      ));
    }
    if (filterState.assignmentFilter != DashboardAssignmentFilter.all) {
      final label = switch (filterState.assignmentFilter) {
        DashboardAssignmentFilter.assignedToMe => 'Assigned to Me',
        DashboardAssignmentFilter.assigned => 'Assigned',
        DashboardAssignmentFilter.unassigned => 'Unassigned',
        DashboardAssignmentFilter.all => 'All',
      };
      chips.add(_RemovableFilterChip(
        label: label,
        isDark: isDark,
        borderColor: borderColor,
        onRemove: () => onFilterChanged(
          filterState.copyWith(
            assignmentFilter: DashboardAssignmentFilter.all,
          ),
        ),
      ));
    }
    if (filterState.sortBy != DashboardSort.recent) {
      chips.add(_RemovableFilterChip(
        label: 'Sort: Severity',
        isDark: isDark,
        borderColor: borderColor,
        onRemove: () => onFilterChanged(
          filterState.copyWith(sortBy: DashboardSort.recent),
        ),
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...chips,
        GestureDetector(
          onTap: onClearAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              'Clear all',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: activeColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RemovableFilterChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color borderColor;
  final VoidCallback onRemove;

  const _RemovableFilterChip({
    required this.label,
    required this.isDark,
    required this.borderColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 15),
          ),
        ],
      ),
    );
  }
}

