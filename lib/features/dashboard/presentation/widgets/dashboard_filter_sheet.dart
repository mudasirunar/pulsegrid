import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../incidents/domain/entities/incident_severity.dart';
import 'dashboard_filter_state.dart';

/// Opens the rounded Filter & Sort bottom sheet and returns the updated
/// [DashboardFilterState], or null if dismissed.
Future<DashboardFilterState?> showDashboardFilterSheet({
  required BuildContext context,
  required DashboardFilterState initialState,
  required bool isReadOnly,
}) {
  var tempStatus = initialState.statusFilter;
  var tempSeverity = initialState.severityFilter;
  var tempAssignment = initialState.assignmentFilter;
  var tempSort = initialState.sortBy;

  return showModalBottomSheet<DashboardFilterState>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final isDark = theme.brightness == Brightness.dark;
      final secondaryText =
          isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  Row(
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
                  const SizedBox(height: 12),
                  _SheetSectionLabel(label: 'SORT BY', color: secondaryText),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Most Recent'),
                        selected: tempSort == DashboardSort.recent,
                        onSelected: (_) =>
                            setSheetState(() => tempSort = DashboardSort.recent),
                      ),
                      ChoiceChip(
                        label: const Text('Highest Severity'),
                        selected: tempSort == DashboardSort.severity,
                        onSelected: (_) => setSheetState(
                          () => tempSort = DashboardSort.severity,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SheetSectionLabel(label: 'SEVERITY', color: secondaryText),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: tempSeverity == null,
                        onSelected: (_) =>
                            setSheetState(() => tempSeverity = null),
                      ),
                      ...IncidentSeverity.values.map(
                        (sev) => ChoiceChip(
                          label: Text(sev.displayName),
                          selected: tempSeverity == sev,
                          onSelected: (_) =>
                              setSheetState(() => tempSeverity = sev),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SheetSectionLabel(label: 'STATUS', color: secondaryText),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: DashboardStatusFilter.values.map((st) {
                      return ChoiceChip(
                        label: Text(st.label),
                        selected: tempStatus == st,
                        onSelected: (_) =>
                            setSheetState(() => tempStatus = st),
                      );
                    }).toList(),
                  ),
                  if (!isReadOnly) ...[
                    const SizedBox(height: 16),
                    _SheetSectionLabel(
                      label: 'ASSIGNMENT',
                      color: secondaryText,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected:
                              tempAssignment == DashboardAssignmentFilter.all,
                          onSelected: (_) => setSheetState(
                            () =>
                                tempAssignment = DashboardAssignmentFilter.all,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Assigned to Me'),
                          selected: tempAssignment ==
                              DashboardAssignmentFilter.assignedToMe,
                          onSelected: (_) => setSheetState(
                            () => tempAssignment =
                                DashboardAssignmentFilter.assignedToMe,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Unassigned'),
                          selected: tempAssignment ==
                              DashboardAssignmentFilter.unassigned,
                          onSelected: (_) => setSheetState(
                            () => tempAssignment =
                                DashboardAssignmentFilter.unassigned,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
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
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _SheetSectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SheetSectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: color,
      ),
    );
  }
}

