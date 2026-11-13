import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/activity_event_entity.dart';
import '../../domain/entities/incident_entity.dart';
import '../../domain/entities/incident_status.dart';

class IncidentTimelineView extends StatelessWidget {
  final List<ActivityEventEntity> timeline;
  final bool isLoading;
  final UserEntity? currentUser;
  final IncidentEntity? incident;

  const IncidentTimelineView({
    super.key,
    required this.timeline,
    this.isLoading = false,
    this.currentUser,
    this.incident,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final displayTimeline = _getDisplayTimeline();

    if (displayTimeline.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No activity events recorded yet.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayTimeline.length,
      itemBuilder: (context, index) {
        final event = displayTimeline[index];
        final isFirst = index == 0; // Top item (Current/Latest activity)
        final isLast = index == displayTimeline.length - 1; // Bottom item (Initial milestone)
        return _buildTimelineRow(context, event, index, isFirst, isLast, isDark, displayTimeline.length);
      },
    );
  }

  /// Builds a complete chronological tree of lifecycle milestones and recorded activities:
  /// Reverse chronological progression (Latest/recent events at TOP, initial creation at BOTTOM).
  /// Preserves the complete historical tree even when an incident is reopened from Resolved/Closed.
  List<ActivityEventEntity> _getDisplayTimeline() {
    final events = List<ActivityEventEntity>.from(timeline);

    if (incident != null) {
      const lifecycleOrder = [
        IncidentStatus.newIncident,
        IncidentStatus.assigned,
        IncidentStatus.inProgress,
        IncidentStatus.resolved,
        IncidentStatus.closed,
      ];

      // 1. Ensure creation milestone exists at the start
      final hasCreated = events.any((e) => e.eventType == ActivityEventType.incidentCreated);
      if (!hasCreated) {
        events.insert(
          0,
          ActivityEventEntity(
            id: 'milestone-created',
            incidentId: incident!.id,
            actorId: incident!.createdBy,
            eventType: ActivityEventType.incidentCreated,
            newValue: IncidentStatus.newIncident.value,
            timestamp: incident!.createdAt,
          ),
        );
      }

      // 2. If events has no status changes but incident has progressed beyond newIncident,
      // backfill intermediate milestones (skipping Assigned if an assignmentChange event exists)
      final currentIdx = lifecycleOrder.indexOf(incident!.status);
      final hasAssignmentEvent =
          events.any((e) => e.eventType == ActivityEventType.assignmentChange);
      if (events.where((e) => e.eventType == ActivityEventType.statusChange).isEmpty && currentIdx > 0) {
        for (int i = 1; i <= currentIdx; i++) {
          final status = lifecycleOrder[i];
          if (status == IncidentStatus.assigned && hasAssignmentEvent) {
            continue;
          }
          final stepTime = i == currentIdx
              ? incident!.updatedAt
              : incident!.createdAt.add(Duration(minutes: i * 5));
          events.add(
            ActivityEventEntity(
              id: 'milestone-${status.value}',
              incidentId: incident!.id,
              actorId: incident!.createdBy,
              eventType: ActivityEventType.statusChange,
              oldValue: lifecycleOrder[i - 1].value,
              newValue: status.value,
              timestamp: stepTime,
            ),
          );
        }
      }

      // 3. For any reopen event in history (Resolved/Closed -> In Progress),
      // ensure the prior Resolved/Closed milestone exists before it in time.
      for (int k = 0; k < events.length; k++) {
        final ev = events[k];
        if (ev.eventType == ActivityEventType.statusChange) {
          final oldVal = ev.oldValue?.replaceAll('IncidentStatus.', '').toLowerCase();
          final newVal = ev.newValue?.replaceAll('IncidentStatus.', '').toLowerCase();
          if ((oldVal == 'resolved' || oldVal == 'closed') && newVal == 'in_progress') {
            final priorStatusName = oldVal == 'closed' ? 'closed' : 'resolved';
            final hasPrior = events.any(
              (e) => e != ev &&
                     e.eventType == ActivityEventType.statusChange &&
                     e.newValue?.replaceAll('IncidentStatus.', '').toLowerCase() == priorStatusName &&
                     e.timestamp.isBefore(ev.timestamp),
            );
            if (!hasPrior) {
              events.add(
                ActivityEventEntity(
                  id: 'milestone-$priorStatusName-${ev.id}',
                  incidentId: incident!.id,
                  actorId: incident!.createdBy,
                  eventType: ActivityEventType.statusChange,
                  oldValue: priorStatusName == 'closed' ? 'resolved' : 'in_progress',
                  newValue: priorStatusName.toUpperCase(),
                  timestamp: ev.timestamp.subtract(const Duration(minutes: 2)),
                ),
              );
            }
          }
        }
      }

      // 4. Ensure predecessor status milestones exist if an event's oldValue was missing in history
      for (final ev in List<ActivityEventEntity>.from(events)) {
        if (ev.eventType == ActivityEventType.statusChange && ev.oldValue != null) {
          final oldStatusClean = ev.oldValue!.replaceAll('IncidentStatus.', '').toLowerCase();
          if (oldStatusClean != 'new' && oldStatusClean != 'newincident') {
            final hasPredecessor = events.any(
              (e) =>
                  (e.eventType == ActivityEventType.statusChange &&
                      e.newValue?.replaceAll('IncidentStatus.', '').toLowerCase() == oldStatusClean &&
                      e.timestamp.isBefore(ev.timestamp)) ||
                  (oldStatusClean == 'assigned' &&
                      e.eventType == ActivityEventType.assignmentChange &&
                      e.timestamp.isBefore(ev.timestamp)),
            );
            if (!hasPredecessor) {
              final predStatus = lifecycleOrder.firstWhere(
                (s) => s.value.replaceAll('IncidentStatus.', '').toLowerCase() == oldStatusClean,
                orElse: () => IncidentStatus.assigned,
              );
              final predIdx = lifecycleOrder.indexOf(predStatus);
              final prevStatus = predIdx > 0 ? lifecycleOrder[predIdx - 1] : IncidentStatus.newIncident;
              events.add(
                ActivityEventEntity(
                  id: 'milestone-backfill-${predStatus.value}-${ev.id}',
                  incidentId: incident!.id,
                  actorId: incident!.createdBy,
                  eventType: ActivityEventType.statusChange,
                  oldValue: prevStatus.value,
                  newValue: predStatus.value,
                  timestamp: ev.timestamp.subtract(const Duration(minutes: 5)),
                ),
              );
            }
          }
        }
      }
    }

    // Sort descending by timestamp: Newest event at TOP, initial creation at BOTTOM
    events.sort((a, b) {
      final cmp = b.timestamp.compareTo(a.timestamp);
      if (cmp != 0) return cmp;
      if (a.eventType == ActivityEventType.incidentCreated) return 1;
      if (b.eventType == ActivityEventType.incidentCreated) return -1;
      return 0;
    });
    return events;
  }

  Widget _buildTimelineRow(
    BuildContext context,
    ActivityEventEntity event,
    int index,
    bool isFirst,
    bool isLast,
    bool isDark,
    int totalCount,
  ) {
    final theme = Theme.of(context);
    final isCurrent = isFirst; // The newest event logged at the top represents the current active status

    // Normal, simple colors: subtle neutral track with separate primary highlight for current
    final currentDotColor = isDark ? AppColors.accentDark : AppColors.primaryLight;
    final normalDotColor = isDark ? const Color(0xFF4A5248) : const Color(0xFFB8BCB2);
    final dotColor = isCurrent ? currentDotColor : normalDotColor;
    final connectingLineColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final title = _eventTitle(event);
    final subtitle = _eventSubtitle(event);
    final timeStr = _formatTimestamp(event.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Timeline Track (Dot Node + Vertical Connecting Line)
          SizedBox(
            width: 20,
            child: Column(
              children: [
                // Top line spacer
                Container(
                  width: 2,
                  height: 4,
                  color: isFirst ? Colors.transparent : connectingLineColor,
                ),
                // Dot Node
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                // Bottom connecting line down to previous activity below it
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : connectingLineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right Content Area (Title, Timestamp, Actor/Details)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0.0 : 22.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _eventTitle(ActivityEventEntity event) {
    switch (event.eventType) {
      case ActivityEventType.incidentCreated:
        return 'Incident Reported';
      case ActivityEventType.incidentEdited:
        return 'Incident Edited';
      case ActivityEventType.statusChange:
        final oldVal = event.oldValue?.replaceAll('IncidentStatus.', '').toLowerCase();
        final newVal = event.newValue?.replaceAll('IncidentStatus.', '').toLowerCase();

        // Distinct title for Reopen events
        if ((oldVal == 'resolved' || oldVal == 'closed') && newVal == 'in_progress') {
          return 'Incident Reopened';
        }

        if (event.newValue != null && event.newValue!.trim().isNotEmpty) {
          return 'Status: ${_cleanStatus(event.newValue!)}';
        }
        return 'Status Updated';
      case ActivityEventType.assignmentChange:
        if (event.oldValue != null && event.oldValue!.trim().isNotEmpty) {
          return 'Responder Reassigned';
        }
        return 'Responder Assigned';
      case ActivityEventType.resourceLogged:
        return 'Resource Logged';
      case ActivityEventType.conflictResolved:
        return 'Conflict Resolved';
    }
  }

  String _eventSubtitle(ActivityEventEntity event) {
    final actor = _resolveActorName(event.actorId);
    final parts = <String>['by $actor'];

    if (event.eventType == ActivityEventType.statusChange &&
        event.oldValue != null &&
        event.newValue != null) {
      parts.add('${_cleanStatus(event.oldValue!)} → ${_cleanStatus(event.newValue!)}');
    } else if (event.eventType == ActivityEventType.assignmentChange &&
        event.newValue != null &&
        event.newValue!.trim().isNotEmpty) {
      if (event.oldValue != null && event.oldValue!.trim().isNotEmpty) {
        parts.add('${event.oldValue!.trim()} → ${event.newValue!.trim()}');
      } else {
        parts.add('Assigned to ${event.newValue!.trim()}');
      }
    } else if (event.newValue != null &&
        event.newValue!.trim().isNotEmpty &&
        event.eventType != ActivityEventType.statusChange) {
      parts.add(event.newValue!.trim());
    }

    return parts.join(' • ');
  }

  String _resolveActorName(String rawActor) {
    final clean = rawActor.trim();
    if (clean.isEmpty) return 'System';

    // 1. Matches current user
    if (currentUser != null) {
      if (clean == currentUser!.id || clean == currentUser!.email) {
        if (currentUser!.displayName.trim().isNotEmpty) {
          return currentUser!.displayName.trim();
        }
        return currentUser!.role.displayName;
      }
    }

    // 2. Matches demo accounts
    if (clean == 'user-coordinator-01') return 'Sarah Chen';
    if (clean == 'user-responder-01') return 'Marcus Vance';
    if (clean == 'user-viewer-01') return 'Auditor Evans';

    // 3. Matches incident creator
    if (incident != null && incident!.createdBy.trim().isNotEmpty) {
      if (clean == incident!.createdBy) {
        return _isRawUuidOrId(clean)
            ? (currentUser?.displayName.trim().isNotEmpty ?? false
                ? currentUser!.displayName.trim()
                : 'Coordinator')
            : clean;
      }
    }

    // 4. Raw UUID / Firebase UID check
    if (_isRawUuidOrId(clean)) {
      if (currentUser != null && currentUser!.displayName.trim().isNotEmpty) {
        return currentUser!.displayName.trim();
      }
      return 'Coordinator';
    }

    return clean;
  }

  bool _isRawUuidOrId(String str) {
    if (str.length >= 20 && !str.contains(' ')) return true;
    final uuidPattern = RegExp(r'^[0-9a-fA-F-]{28,}$');
    return uuidPattern.hasMatch(str);
  }

  String _cleanStatus(String raw) {
    final clean = raw.replaceAll('IncidentStatus.', '').replaceAll('_', ' ').trim();
    if (clean.isEmpty) return clean;
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $ampm';

    if (isToday) {
      return 'Today · $timeStr';
    } else if (isYesterday) {
      return 'Yesterday · $timeStr';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthStr = months[dt.month - 1];
      return '$monthStr ${dt.day} · $timeStr';
    }
  }
}
