import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/incidents/domain/entities/activity_event_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/incidents/domain/repositories/incident_repository.dart';
import 'package:pulsegrid/features/incidents/presentation/bloc/incident_bloc.dart';
import 'package:pulsegrid/features/incidents/presentation/screens/create_incident_screen.dart';
import 'package:pulsegrid/features/incidents/presentation/screens/incident_details_screen.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_log_entity.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_summary_item.dart';
import 'package:pulsegrid/features/resources/domain/repositories/resource_repository.dart';
import 'package:pulsegrid/features/resources/presentation/cubit/resource_cubit.dart';

class _FakeIncidentRepository implements IncidentRepository {
  final List<IncidentEntity> items = [];
  final List<ActivityEventEntity> timeline = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Duration deleteDelay = Duration.zero;

  @override
  Stream<void> get onIncidentsChanged => _changes.stream;

  @override
  Future<IncidentEntity> createIncident(IncidentEntity incident) async {
    items.add(incident);
    return incident;
  }

  @override
  Future<List<IncidentEntity>> getIncidents({
    IncidentStatus? statusFilter,
    IncidentSeverity? severityFilter,
    String? searchQuery,
  }) async => List<IncidentEntity>.from(items);

  @override
  Future<IncidentEntity?> getIncidentById(String id) async {
    try {
      return items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<IncidentEntity> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus targetStatus,
    required UserEntity actor,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<IncidentEntity> updateIncident({
    required IncidentEntity updatedIncident,
    required UserEntity actor,
  }) async {
    final idx = items.indexWhere((e) => e.id == updatedIncident.id);
    if (idx >= 0) items[idx] = updatedIncident;
    return updatedIncident;
  }

  @override
  Future<void> deleteIncident({
    required String incidentId,
    required UserEntity actor,
  }) async {
    if (deleteDelay > Duration.zero) {
      await Future.delayed(deleteDelay);
    }
    items.removeWhere((e) => e.id == incidentId);
  }

  @override
  Future<List<ActivityEventEntity>> getActivityTimeline(String incidentId) async =>
      timeline.where((e) => e.incidentId == incidentId).toList();

  @override
  Future<IncidentEntity> assignResponder({
    required String incidentId,
    required UserEntity responder,
    required UserEntity actor,
  }) async => throw UnimplementedError();

  @override
  Future<List<UserEntity>> getResponders({bool forceRefresh = false}) async => const [];

  @override
  Future<Map<String, int>> getResponderActiveCounts() async => const {};
}

class _FakeResourceRepo implements ResourceRepository {
  @override
  Stream<void> get onResourcesChanged => const Stream.empty();

  @override
  Future<List<ResourceLogEntity>> getResourceLogs(String incidentId) async => const [];

  @override
  Future<List<ResourceSummaryItem>> getResourceSummary(String incidentId) async => const [];

  @override
  Future<ResourceLogEntity> logResource({
    required String incidentId,
    required String resourceType,
    required double quantity,
    required String unit,
    String? notes,
    required String loggedBy,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 13, 10, 0);

  const coordinator = UserEntity(
    id: 'coord-1',
    email: 'coord@pulsegrid.com',
    displayName: 'Sarah Chen',
    role: UserRole.coordinator,
  );

  const otherResponder = UserEntity(
    id: 'resp-2',
    email: 'resp2@pulsegrid.com',
    displayName: 'Ali Khan',
    role: UserRole.responder,
  );

  const viewer = UserEntity(
    id: 'view-1',
    email: 'viewer@pulsegrid.com',
    displayName: 'Auditor Evans',
    role: UserRole.viewer,
  );

  final sampleIncident = IncidentEntity(
    id: 'inc-edit-1',
    title: 'Substation Outage',
    category: 'Infrastructure',
    severity: IncidentSeverity.high,
    description: 'Sector 4 power loss',
    status: IncidentStatus.newIncident,
    createdBy: 'Marcus Vance',
    createdAt: now,
    updatedAt: now,
  );

  Widget wrapDetails({
    required _FakeIncidentRepository repo,
    required UserEntity user,
    required IncidentEntity incident,
  }) {
    final bloc = IncidentBloc(incidentRepository: repo);
    final resCubit = ResourceCubit(resourceRepository: _FakeResourceRepo());
    return MaterialApp(
      home: BlocProvider.value(
        value: bloc,
        child: IncidentDetailsScreen(
          incident: incident,
          currentUser: user,
          resourceCubit: resCubit,
        ),
      ),
    );
  }

  testWidgets('Overflow menu visible for Coordinator, hidden for Viewer and non-creator Responder',
      (tester) async {
    final repo = _FakeIncidentRepository()..items.add(sampleIncident);

    // 1. Coordinator sees 3-dot icon
    await tester.pumpWidget(wrapDetails(repo: repo, user: coordinator, incident: sampleIncident));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    // 2. Viewer does not
    await tester.pumpWidget(wrapDetails(repo: repo, user: viewer, incident: sampleIncident));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);

    // 3. Other Responder does not
    await tester.pumpWidget(wrapDetails(repo: repo, user: otherResponder, incident: sampleIncident));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });

  testWidgets('Overflow menu opens with text-only Edit & red Delete, and Delete shows confirmation dialog with loader',
      (tester) async {
    final repo = _FakeIncidentRepository()
      ..items.add(sampleIncident)
      ..deleteDelay = const Duration(milliseconds: 150);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => IncidentBloc(incidentRepository: repo),
          child: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: ctx.read<IncidentBloc>(),
                        child: IncidentDetailsScreen(
                          incident: sampleIncident,
                          currentUser: coordinator,
                          resourceCubit: ResourceCubit(resourceRepository: _FakeResourceRepo()),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap 3-dot menu
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap Delete -> opens AppDialog
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Incident'), findsOneWidget);

    // Confirm Delete -> shows loader while deleting, then pops back
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();
    expect(repo.items, isEmpty);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('CreateIncidentScreen in Edit Mode pre-populates fields and dispatches UpdateIncidentEvent',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = _FakeIncidentRepository()..items.add(sampleIncident);
    final bloc = IncidentBloc(incidentRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: CreateIncidentScreen(
            currentUser: coordinator,
            existingIncident: sampleIncident,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Incident'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Substation Outage'), findsOneWidget);
    expect(find.text('Sector 4 power loss'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Substation Fire Updated');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(repo.items.first.title, equals('Substation Fire Updated'));
  });
}

