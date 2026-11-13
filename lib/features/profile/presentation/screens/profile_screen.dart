import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/database_constants.dart';
import '../../../../core/database/local_data_source.dart';
import '../../../../core/preferences/app_preferences_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/presentation/bloc/incident_bloc.dart';
import '../../../incidents/presentation/bloc/incident_state.dart';
import '../../../sync/domain/services/sync_engine.dart';
import '../../domain/entities/profile_stats.dart';
import '../widgets/animated_preference_tiles.dart';
import '../widgets/edit_display_name_dialog.dart';
import '../widgets/profile_identity_header.dart';
import '../widgets/profile_stats_strip.dart';
import '../widgets/theme_preview_selector.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final ScrollController? scrollController;

  const ProfileScreen({
    super.key,
    required this.user,
    this.scrollController,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileStats _stats = const ProfileStats();
  StreamSubscription<String>? _tableSubscription;
  StreamSubscription<Map<String, Map<String, dynamic>>>? _userStatsSubscription;

  String get _statsPrefKey => 'profile_stats_${widget.user.id}';

  @override
  void initState() {
    super.initState();
    _loadCachedStats();
    _refreshStatsFromDb();

    if (di.sl.isRegistered<LocalDataSource>()) {
      _tableSubscription = di.sl<LocalDataSource>().onTableChanged.listen((table) {
        if (!mounted) return;
        if (table == DatabaseConstants.tableIncidents ||
            table == DatabaseConstants.tableAssignments) {
          _refreshStatsFromDb();
        }
      });
    }

    if (di.sl.isRegistered<SyncEngine>()) {
      _userStatsSubscription =
          di.sl<SyncEngine>().onUserStatsUpdated.listen((statsByUser) {
        final remoteMap = statsByUser[widget.user.id];
        if (remoteMap != null && mounted && !di.sl.isRegistered<LocalDataSource>()) {
          setState(() => _stats = ProfileStats.fromMap(remoteMap));
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.role != widget.user.role) {
      _loadCachedStats();
      _refreshStatsFromDb();
    }
  }

  @override
  void dispose() {
    _tableSubscription?.cancel();
    _userStatsSubscription?.cancel();
    super.dispose();
  }

  void _loadCachedStats() {
    if (widget.user.role == UserRole.viewer) return;
    if (di.sl.isRegistered<SharedPreferences>()) {
      final raw = di.sl<SharedPreferences>().getString(_statsPrefKey);
      if (raw != null) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          _stats = ProfileStats.fromMap(map);
          return;
        } catch (_) {}
      }
    }
    if (di.sl.isRegistered<SyncEngine>()) {
      final remoteMap = di.sl<SyncEngine>().latestUserStats[widget.user.id];
      if (remoteMap != null) {
        _stats = ProfileStats.fromMap(remoteMap);
      }
    }
  }

  Future<void> _refreshStatsFromDb() async {
    if (widget.user.role == UserRole.viewer) return;
    if (!di.sl.isRegistered<LocalDataSource>()) {
      _syncStatsFromBlocIfAvailable();
      return;
    }

    try {
      final local = di.sl<LocalDataSource>();
      final incidentModels = await local.getAllIncidents();
      final assignments = await local.getAllAssignments();

      final incidents = incidentModels.map(IncidentEntity.fromModel).toList();
      final assignees = {
        for (final a in assignments) a.incidentId: a.responderId,
      };

      final computed = ProfileStats.compute(
        role: widget.user.role,
        currentUserId: widget.user.id,
        incidents: incidents,
        incidentAssignees: assignees,
      );

      if (!mounted) return;
      if (computed != _stats) {
        setState(() => _stats = computed);
      }
      await _persistAndSyncStats(computed);
    } catch (_) {}
  }

  void _syncStatsFromBlocIfAvailable() {
    if (widget.user.role == UserRole.viewer) return;
    try {
      final state = context.read<IncidentBloc>().state;
      if (state is IncidentLoaded) {
        final computed = ProfileStats.compute(
          role: widget.user.role,
          currentUserId: widget.user.id,
          incidents: state.incidents,
          incidentAssignees: const {},
        );
        if (computed != _stats && mounted) {
          setState(() => _stats = computed);
        }
      }
    } catch (_) {}
  }

  Future<void> _persistAndSyncStats(ProfileStats stats) async {
    final map = stats.toMap();
    if (di.sl.isRegistered<SharedPreferences>()) {
      await di.sl<SharedPreferences>().setString(_statsPrefKey, jsonEncode(map));
    }
    if (di.sl.isRegistered<SyncEngine>()) {
      await di.sl<SyncEngine>().syncUserStats(widget.user.id, map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final themeMode = context.watch<ThemeCubit>().state;
    final prefsState = _watchPreferences(context);
    final bottomPadding = math.max(
      120.0,
      MediaQuery.viewPaddingOf(context).bottom + 96.0,
    );

    final body = Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Flat Identity Header
              ProfileIdentityHeader(
                user: widget.user,
                onEditNamePressed: () => _openEditNameDialog(context),
              ),

              // 2. Role-Aware Stats Strip (hidden for Viewer)
              if (widget.user.role != UserRole.viewer) ...[
                const SizedBox(height: 16),
                ProfileStatsStrip(
                  role: widget.user.role,
                  stats: _stats,
                ),
              ],

              const SizedBox(height: 18),

              // 3. Appearance (System -> Light -> Dark)
              Text(
                'Appearance',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ThemePreviewSelector(
                selectedMode: themeMode,
                hapticEnabled: prefsState.hapticEnabled,
                onThemeSelected: (mode) {
                  context.read<ThemeCubit>().setThemeMode(mode);
                },
              ),

              const SizedBox(height: 18),

              // 4. Preferences (Animated Haptics & Compact List)
              Text(
                'Preferences',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    AnimatedPreferenceTile(
                      leading: AnimatedShakePhoneIcon(
                        enabled: prefsState.hapticEnabled,
                        color: textPrimary,
                      ),
                      title: 'Haptic Feedback',
                      subtitle: 'Tactile feedback across the app',
                      value: prefsState.hapticEnabled,
                      hapticEnabled: prefsState.hapticEnabled,
                      triggerHapticOnEnableOnly: true,
                      onChanged: (enabled) => _setHaptic(context, enabled),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: borderColor,
                    ),
                    AnimatedPreferenceTile(
                      leading: AnimatedLinesIcon(
                        isCompact: prefsState.compactCards,
                        color: textPrimary,
                      ),
                      title: 'Compact Incident List',
                      subtitle: 'Single-line titles on home incident cards',
                      value: prefsState.compactCards,
                      hapticEnabled: prefsState.hapticEnabled,
                      onChanged: (enabled) => _setCompact(context, enabled),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 5. Sign Out (Solid Red + White Text, no icon)
              AppButton(
                text: 'Sign Out',
                borderRadius: 24.0,
                height: 50.0,
                customBackgroundColor: AppColors.severityCritical,
                customForegroundColor: Colors.white,
                onPressed: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ),
    );

    if (_hasIncidentBloc(context)) {
      return BlocListener<IncidentBloc, IncidentState>(
        listener: (_, state) {
          if (state is IncidentLoaded) {
            _refreshStatsFromDb();
          }
        },
        child: body,
      );
    }
    return body;
  }

  bool _hasIncidentBloc(BuildContext context) {
    try {
      context.read<IncidentBloc>();
      return true;
    } catch (_) {
      return false;
    }
  }

  AppPreferencesState _watchPreferences(BuildContext context) {
    try {
      return context.watch<AppPreferencesCubit>().state;
    } catch (_) {
      return const AppPreferencesState();
    }
  }

  void _setHaptic(BuildContext context, bool enabled) {
    try {
      context.read<AppPreferencesCubit>().setHapticEnabled(enabled);
    } catch (_) {}
  }

  void _setCompact(BuildContext context, bool enabled) {
    try {
      context.read<AppPreferencesCubit>().setCompactCards(enabled);
    } catch (_) {}
  }

  Future<void> _openEditNameDialog(BuildContext context) async {
    final newName = await EditDisplayNameDialog.show(
      context,
      initialName: widget.user.displayName,
    );
    if (newName != null && context.mounted) {
      context.read<AuthBloc>().add(UpdateDisplayNameEvent(newName));
    }
  }

  void _confirmSignOut(BuildContext context) {
    AppDialog.show<void>(
      context: context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of Pulse Grid?',
      icon: Icons.logout_rounded,
      confirmText: 'Sign Out',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () {
        context.read<AuthBloc>().add(const SignOutEvent());
      },
    );
  }
}
