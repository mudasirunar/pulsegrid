import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/repositories/incident_repository.dart';
import '../bloc/incident_bloc.dart';
import '../bloc/incident_event.dart';
import '../bloc/incident_state.dart';

class ResponderPickerBottomSheet extends StatefulWidget {
  final String incidentId;
  final UserEntity currentUser;
  final String? currentResponderId;
  final VoidCallback? onAssigned;
  final IncidentRepository? repository;

  const ResponderPickerBottomSheet({
    super.key,
    required this.incidentId,
    required this.currentUser,
    this.currentResponderId,
    this.onAssigned,
    this.repository,
  });

  static Future<void> show(
    BuildContext context, {
    required String incidentId,
    required UserEntity currentUser,
    String? currentResponderId,
    VoidCallback? onAssigned,
    IncidentRepository? repository,
  }) {
    final bloc = context.read<IncidentBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: ResponderPickerBottomSheet(
          incidentId: incidentId,
          currentUser: currentUser,
          currentResponderId: currentResponderId,
          onAssigned: onAssigned,
          repository: repository,
        ),
      ),
    );
  }

  @override
  State<ResponderPickerBottomSheet> createState() =>
      _ResponderPickerBottomSheetState();
}

class _ResponderPickerBottomSheetState
    extends State<ResponderPickerBottomSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _refreshAnimController;

  List<UserEntity> _responders = const [];
  Map<String, int> _activeCounts = const {};
  String? _selectedResponderId;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSubmitting = false;
  String? _loadError;

  bool get _isReassign => widget.currentResponderId != null;

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _selectedResponderId = widget.currentResponderId;
    _loadResponders();
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  IncidentRepository get _repo =>
      widget.repository ?? sl<IncidentRepository>();

  Future<void> _loadResponders({bool forceRefresh = false}) async {
    final keepExistingList = forceRefresh && _responders.isNotEmpty;
    if (keepExistingList) {
      setState(() {
        _isRefreshing = true;
        _loadError = null;
      });
      _refreshAnimController.repeat();
    } else {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final results = await Future.wait([
        _repo.getResponders(forceRefresh: forceRefresh),
        _repo.getResponderActiveCounts(),
      ]);
      if (!mounted) return;
      final responders = List<UserEntity>.from(results[0] as List<UserEntity>)
        ..sort((a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      final counts = results[1] as Map<String, int>;
      _refreshAnimController.stop();
      _refreshAnimController.reset();
      setState(() {
        _responders = responders;
        _activeCounts = counts;
        _isLoading = false;
        _isRefreshing = false;
      });
      if (!forceRefresh) {
        _refreshRespondersQuietly();
      }
    } catch (e) {
      if (!mounted) return;
      _refreshAnimController.stop();
      _refreshAnimController.reset();
      if (keepExistingList) {
        setState(() => _isRefreshing = false);
        AppSnackBar.showError(context, 'Could not refresh responders.');
      } else {
        setState(() {
          _loadError = 'Could not load responders. Please try again.';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshRespondersQuietly() async {
    try {
      final results = await Future.wait([
        _repo.getResponders(forceRefresh: true),
        _repo.getResponderActiveCounts(),
      ]);
      if (!mounted) return;
      final responders = List<UserEntity>.from(results[0] as List<UserEntity>)
        ..sort((a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      final counts = results[1] as Map<String, int>;
      if (responders.isNotEmpty) {
        setState(() {
          _responders = responders;
          _activeCounts = counts;
        });
      }
    } catch (_) {}
  }

  List<UserEntity> get _filteredResponders {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _responders;
    return _responders.where((r) {
      return r.displayName.toLowerCase().contains(q) ||
          r.email.toLowerCase().contains(q);
    }).toList();
  }

  void _submit() {
    final selectedId = _selectedResponderId;
    if (selectedId == null || _isSubmitting) return;
    final responder = _responders.cast<UserEntity?>().firstWhere(
          (r) => r?.id == selectedId,
          orElse: () => null,
        );
    if (responder == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    context.read<IncidentBloc>().add(
          AssignResponderEvent(
            incidentId: widget.incidentId,
            responder: responder,
            actor: widget.currentUser,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final selectedChanged = _selectedResponderId != null &&
        _selectedResponderId != widget.currentResponderId;

    return BlocListener<IncidentBloc, IncidentState>(
      listener: (context, state) {
        if (!_isSubmitting) return;
        if (state is IncidentOperationSuccess) {
          setState(() => _isSubmitting = false);
          Navigator.of(context).pop();
          AppSnackBar.showSuccess(context, state.message);
          widget.onAssigned?.call();
        } else if (state is IncidentOperationFailure) {
          setState(() => _isSubmitting = false);
          AppSnackBar.showError(context, state.message);
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 20,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isReassign ? 'Reassign Responder' : 'Assign Responder',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Select a responder',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: RotationTransition(
                      turns: _refreshAnimController,
                      child: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                    tooltip: 'Refresh responders',
                    onPressed: _isLoading || _isRefreshing || _isSubmitting
                        ? null
                        : () => _loadResponders(forceRefresh: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: AppTextField(
                controller: _searchController,
                hintText: 'Search responders by name or email',
                borderRadius: 24.0,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Flexible(
              child: _buildBody(theme, isDark),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: AppButton(
                text: _isReassign ? 'Reassign Responder' : 'Assign Responder',
                isLoading: _isSubmitting,
                isDisabled: !selectedChanged,
                onPressed: selectedChanged ? _submit : null,
                borderRadius: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.severityCritical, size: 32),
            const SizedBox(height: 10),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _loadResponders(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredResponders;
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 36,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 10),
            Text(
              _responders.isEmpty
                  ? 'No responders found'
                  : 'No responders match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final responder = filtered[index];
        final isSelected = responder.id == _selectedResponderId;
        final isCurrent = responder.id == widget.currentResponderId;
        final activeCount = _activeCounts[responder.id] ?? 0;

        return _ResponderTile(
          responder: responder,
          activeCount: activeCount,
          isSelected: isSelected,
          isCurrent: isCurrent,
          onTap: _isSubmitting
              ? null
              : () => setState(() => _selectedResponderId = responder.id),
        );
      },
    );
  }
}

class _ResponderTile extends StatelessWidget {
  final UserEntity responder;
  final int activeCount;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _ResponderTile({
    required this.responder,
    required this.activeCount,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final initial = responder.displayName.isNotEmpty
        ? responder.displayName[0].toUpperCase()
        : '?';

    final badgeColor = activeCount == 0
        ? AppColors.statusResolved
        : (activeCount >= 3 ? AppColors.statusInProgress : primaryColor);

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: isDark ? 0.16 : 0.08)
          : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryColor.withValues(alpha: 0.14),
                child: Text(
                  initial,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            responder.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Current',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      responder.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$activeCount active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: isSelected
                    ? primaryColor
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
