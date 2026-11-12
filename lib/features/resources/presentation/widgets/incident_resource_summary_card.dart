import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/resource_log_entity.dart';
import '../cubit/resource_cubit.dart';
import '../cubit/resource_state.dart';
import 'log_resource_bottom_sheet.dart';

class IncidentResourceSummaryCard extends StatefulWidget {
  final String incidentId;
  final UserEntity currentUser;
  final VoidCallback? onResourceLogged;

  const IncidentResourceSummaryCard({
    super.key,
    required this.incidentId,
    required this.currentUser,
    this.onResourceLogged,
  });

  @override
  State<IncidentResourceSummaryCard> createState() => _IncidentResourceSummaryCardState();
}

class _IncidentResourceSummaryCardState extends State<IncidentResourceSummaryCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn.flipped,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.06),
      end: Offset.zero,
    ).animate(_expandAnimation);
    _arrowAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(_expandAnimation);

    _expandController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  bool get _canLogResources =>
      widget.currentUser.role == UserRole.coordinator ||
      widget.currentUser.role == UserRole.responder;

  void _openLogSheet() {
    LogResourceBottomSheet.show(
      context,
      incidentId: widget.incidentId,
      currentUser: widget.currentUser,
      onResourceLogged: widget.onResourceLogged,
    );
  }

  IconData _resourceIcon(String type) {
    switch (type) {
      case 'Water':
        return Icons.water_drop_outlined;
      case 'First Aid Kits':
        return Icons.medical_services_outlined;
      case 'Oxygen Tanks':
        return Icons.air_rounded;
      case 'Blankets':
        return Icons.bed_rounded;
      case 'Food Rations':
        return Icons.restaurant_rounded;
      case 'Fuel':
        return Icons.local_gas_station_rounded;
      case 'Medical Kits':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildLogRow(ResourceLogEntity log, ThemeData theme, bool isDark) {
    final qtyStr = log.quantity.truncateToDouble() == log.quantity
        ? log.quantity.toInt().toString()
        : log.quantity.toStringAsFixed(1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          _resourceIcon(log.resourceType),
          size: 16,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$qtyStr ${log.unit} • ${log.resourceType}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (log.notes != null && log.notes!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  log.notes!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatTimeAgo(log.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<ResourceCubit, ResourceState>(
      builder: (context, state) {
        final List<ResourceLogEntity> logs;
        final bool isLoading = state is ResourceLoading;

        if (state is ResourceLoaded) {
          logs = state.logs;
        } else if (state is ResourceOperationSuccess) {
          logs = state.logs;
        } else if (state is ResourceLoggingInProgress) {
          logs = state.currentLogs;
        } else {
          logs = const [];
        }

        final firstFiveLogs = logs.take(5).toList();
        final extraLogs = logs.length > 5 ? logs.skip(5).toList() : const <ResourceLogEntity>[];
        final showExtra = _isExpanded || _expandController.value > 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Flat On-Screen Heading
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ALLOCATED RESOURCES',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                if (_canLogResources && logs.isNotEmpty)
                  TextButton(
                    onPressed: _openLogSheet,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Log Resource',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Loading State
            if (isLoading && logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                    ),
                  ),
                ),
              )
            // 3. Flat Empty State (No card container, no border)
            else if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 36,
                        color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No resources logged yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _canLogResources
                            ? 'Record deployed supplies to track response logistics'
                            : 'Supplies recorded for this incident will appear here',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                              .withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_canLogResources) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _openLogSheet,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Log Resource',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            // 4. Populated State: Full Flat Rows
            else ...[
              for (int i = 0; i < firstFiveLogs.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _buildLogRow(firstFiveLogs[i], theme, isDark),
              ],

              // Animated extra logs sliding down when "View more" is pressed
              if (showExtra && extraLogs.isNotEmpty)
                ClipRect(
                  child: SizeTransition(
                    sizeFactor: _expandAnimation,
                    alignment: Alignment.topCenter,
                    child: FadeTransition(
                      opacity: _expandAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < extraLogs.length; i++) ...[
                              const SizedBox(height: 10),
                              _buildLogRow(extraLogs[i], theme, isDark),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Centered "View more" / "View less" TextButton when more than 5 logs exist
              if (logs.length > 5) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _toggleExpand,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpanded ? 'View less' : 'View more',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(width: 4),
                        RotationTransition(
                          turns: _arrowAnimation,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}
