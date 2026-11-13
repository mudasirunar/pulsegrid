import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../incidents/domain/entities/incident_severity.dart';
import 'dashboard_filter_state.dart';

/// Opens the rounded Filter & Sort bottom sheet and returns the updated
/// [DashboardFilterState], or null if dismissed.
Future<DashboardFilterState?> showDashboardFilterSheet({
  required BuildContext context,
  required DashboardFilterState initialState,
  required UserRole userRole,
}) {
  var tempStatus = initialState.statusFilter;
  var tempSeverity = initialState.severityFilter;
  var tempAssignment = initialState.assignmentFilter;
  var tempSort = initialState.sortBy;

  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<DashboardFilterState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final secondaryText =
          isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.88;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: secondaryText.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter & Sort',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempStatus = DashboardStatusFilter.all;
                                tempSeverity = null;
                                tempAssignment = DashboardAssignmentFilter.all;
                                tempSort = DashboardSort.recent;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SheetSectionLabel(label: 'SORT BY', color: secondaryText),
                    const SizedBox(height: 8),
                    _HorizontalChipRow(
                      children: [
                        _FilterOptionChip(
                          label: 'Most Recent',
                          selected: tempSort == DashboardSort.recent,
                          onTap: () => setSheetState(
                            () => tempSort = DashboardSort.recent,
                          ),
                        ),
                        _FilterOptionChip(
                          label: 'Oldest',
                          selected: tempSort == DashboardSort.oldest,
                          onTap: () => setSheetState(
                            () => tempSort = DashboardSort.oldest,
                          ),
                        ),
                        _FilterOptionChip(
                          label: 'Highest Severity',
                          selected: tempSort == DashboardSort.severity,
                          onTap: () => setSheetState(
                            () => tempSort = DashboardSort.severity,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SheetSectionLabel(
                      label: 'SEVERITY',
                      color: secondaryText,
                    ),
                    const SizedBox(height: 8),
                    _HorizontalChipRow(
                      children: [
                        _FilterOptionChip(
                          label: 'All',
                          selected: tempSeverity == null,
                          onTap: () => setSheetState(() => tempSeverity = null),
                        ),
                        ...IncidentSeverity.values.map(
                          (sev) => _FilterOptionChip(
                            label: sev.displayName,
                            selected: tempSeverity == sev,
                            onTap: () =>
                                setSheetState(() => tempSeverity = sev),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SheetSectionLabel(label: 'STATUS', color: secondaryText),
                    const SizedBox(height: 8),
                    _HorizontalChipRow(
                      children: DashboardStatusFilter.values.map((st) {
                        return _FilterOptionChip(
                          label: st.label,
                          selected: tempStatus == st,
                          onTap: () => setSheetState(() => tempStatus = st),
                        );
                      }).toList(),
                    ),
                    if (!userRole.isReadOnly) ...[
                      const SizedBox(height: 16),
                      _SheetSectionLabel(
                        label: 'ASSIGNMENT',
                        color: secondaryText,
                      ),
                      const SizedBox(height: 8),
                      _HorizontalChipRow(
                        children: [
                          _FilterOptionChip(
                            label: 'All',
                            selected:
                                tempAssignment == DashboardAssignmentFilter.all,
                            onTap: () => setSheetState(
                              () =>
                                  tempAssignment = DashboardAssignmentFilter.all,
                            ),
                          ),
                          if (userRole == UserRole.coordinator)
                            _FilterOptionChip(
                              label: 'Assigned',
                              selected: tempAssignment ==
                                  DashboardAssignmentFilter.assigned,
                              onTap: () => setSheetState(
                                () => tempAssignment =
                                    DashboardAssignmentFilter.assigned,
                              ),
                            )
                          else
                            _FilterOptionChip(
                              label: 'Assigned to Me',
                              selected: tempAssignment ==
                                  DashboardAssignmentFilter.assignedToMe,
                              onTap: () => setSheetState(
                                () => tempAssignment =
                                    DashboardAssignmentFilter.assignedToMe,
                              ),
                            ),
                          _FilterOptionChip(
                            label: 'Unassigned',
                            selected: tempAssignment ==
                                DashboardAssignmentFilter.unassigned,
                            onTap: () => setSheetState(
                              () => tempAssignment =
                                  DashboardAssignmentFilter.unassigned,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                              initialState.copyWith(
                                statusFilter: tempStatus,
                                severityFilter: tempSeverity,
                                clearSeverity: tempSeverity == null,
                                assignmentFilter: tempAssignment,
                                sortBy: tempSort,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _HorizontalChipRow extends StatelessWidget {
  final List<Widget> children;

  const _HorizontalChipRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _FilterOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final unselectedBg =
        isDark ? AppColors.backgroundDark : AppColors.surfaceLight;
    final unselectedText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
              : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : borderColor,
            width: selected ? 1.3 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? activeColor : unselectedText,
          ),
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SheetSectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: color,
        ),
      ),
    );
  }
}
