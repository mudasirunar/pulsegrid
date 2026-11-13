import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/database/database_constants.dart';
import 'package:pulsegrid/core/database/local_data_source.dart';
import 'package:pulsegrid/core/network/network_info.dart';
import 'package:pulsegrid/core/widgets/app_button.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/incidents/data/models/activity_event_model.dart';
import 'package:pulsegrid/features/incidents/data/models/assignment_model.dart';
import 'package:pulsegrid/features/incidents/data/models/incident_model.dart';
import 'package:pulsegrid/features/incidents/domain/entities/activity_event_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/incidents/domain/repositories/incident_repository.dart';
import 'package:pulsegrid/features/incidents/domain/services/location_service.dart';
import 'package:pulsegrid/features/incidents/domain/services/media_service.dart';
import 'package:pulsegrid/features/incidents/presentation/bloc/incident_bloc.dart';
import 'package:pulsegrid/features/incidents/presentation/screens/create_incident_screen.dart';
import 'package:pulsegrid/features/incidents/presentation/screens/incident_details_screen.dart';
import 'package:pulsegrid/features/incidents/presentation/widgets/responder_picker_bottom_sheet.dart';
import 'package:pulsegrid/features/resources/data/models/resource_log_model.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_log_entity.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_summary_item.dart';
import 'package:pulsegrid/features/resources/domain/repositories/resource_repository.dart';
import 'package:pulsegrid/features/resources/presentation/cubit/resource_cubit.dart';
import 'package:pulsegrid/features/resources/presentation/widgets/log_resource_bottom_sheet.dart';
import 'package:pulsegrid/features/sync/data/models/sync_operation_model.dart';
import 'package:pulsegrid/injection_container.dart';

class _TestLocalDataSource implements LocalDataSource {
  final StreamController<String> _tableChanges =
      StreamController<String>.broadcast();
  AssignmentModel? currentAssignment;

  void emitAssignmentChange(AssignmentModel assignment) {
    currentAssignment = assignment;
    _tableChanges.add(DatabaseConstants.tableAssignments);
  }

  @override
  Stream<String> get onTableChanged => _tableChanges.stream;

  @override
  Future<AssignmentModel?> getAssignmentByIncidentId(String incidentId) async =>
      currentAssignment;

  @override
  Future<void> saveAssignment(AssignmentModel assignment) async {
    currentAssignment = assignment;
    _tableChanges.add(DatabaseConstants.tableAssignments);
  }

  @override
  Future<List<AssignmentModel>> getAllAssignments() async =>
      currentAssignment != null ? [currentAssignment!] : const [];

  @override
  Future<Map<String, int>> getActiveIncidentCountsByResponder() async =>
      const {};

  Future<void> close() async => _tableChanges.close();

  @override
  Future<int> deleteIncident(String id) async => 0;

  @override
  Future<List<ActivityEventModel>> getActivityTimeline(String incidentId) async =>
      const [];

  @override
  Future<List<IncidentModel>> getAllIncidents({
    String? assignedResponderId,
    String? query,
    String? severity,
    String? sortBy,
    String? status,
  }) async =>
      const [];

  @override
  Future<List<SyncOperationModel>> getAllSyncOperations() async => const [];

  @override
  Future<List<IncidentModel>> getCriticalIncidents() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getDetailedResourceSummaryForIncident(
          String incidentId) async =>
      const [];

  @override
  Future<int> getFailedSyncCount() async => 0;

  @override
  Future<IncidentModel?> getIncidentById(String id) async => null;

  @override
  Future<List<IncidentModel>> getIncidentsAssignedTo(String responderId) async =>
      const [];

  @override
  Future<List<IncidentModel>> getOpenIncidents() async => const [];

  @override
  Future<int> getPendingSyncCount() async => 0;

  @override
  Future<List<SyncOperationModel>> getPendingSyncOperations() async => const [];

  @override
  Future<List<ResourceLogModel>> getResourceLogsForIncident(
          String incidentId) async =>
      const [];

  @override
  Future<Map<String, double>> getResourceSummaryForIncident(
          String incidentId) async =>
      const {};

  @override
  Future<void> clearSyncedOperations() async {}

  @override
  Future<void> removeSyncOperation(String id) async {}

  @override
  Future<void> enqueueSyncOperation(SyncOperationModel operation) async {}

  @override
  Future<void> saveActivityEvent(ActivityEventModel event) async {}

  @override
  Future<void> saveIncident(IncidentModel incident) async {}

  Future<void> saveIncidents(List<IncidentModel> incidents) async {}

  @override
  Future<void> saveResourceLog(ResourceLogModel log) async {}

  @override
  Future<void> updateSyncOperationState(String id, String state,
      {String? errorMessage, int? retryCount}) async {}
}

class _TestIncidentRepo implements IncidentRepository {
  List<UserEntity> responders = const [];
  Map<String, int> activeCounts = const {};
  UserEntity? lastAssignedResponder;
  final List<IncidentEntity> items = [];

  @override
  Stream<void> get onIncidentsChanged => const Stream.empty();

  @override
  Future<IncidentEntity> assignResponder({
    required String incidentId,
    required UserEntity responder,
    required UserEntity actor,
  }) async {
    lastAssignedResponder = responder;
    final idx = items.indexWhere((e) => e.id == incidentId);
    final updated = items[idx].copyWith(status: IncidentStatus.assigned);
    items[idx] = updated;
    return updated;
  }

  @override
  Future<List<UserEntity>> getResponders({bool forceRefresh = false}) async =>
      responders;

  @override
  Future<Map<String, int>> getResponderActiveCounts() async => activeCounts;

  @override
  Future<IncidentEntity> createIncident(IncidentEntity incident) async =>
      incident;

  @override
  Future<void> deleteIncident({
    required String incidentId,
    required UserEntity actor,
  }) async {}

  @override
  Future<List<ActivityEventEntity>> getActivityTimeline(
          String incidentId) async =>
      const [];

  @override
  Future<IncidentEntity?> getIncidentById(String id) async =>
      items.cast<IncidentEntity?>().firstWhere((e) => e?.id == id, orElse: () => null);

  @override
  Future<List<IncidentEntity>> getIncidents({
    IncidentStatus? statusFilter,
    IncidentSeverity? severityFilter,
    String? searchQuery,
  }) async =>
      items;

  @override
  Future<IncidentEntity> updateIncident({
    required IncidentEntity updatedIncident,
    required UserEntity actor,
  }) async =>
      updatedIncident;

  @override
  Future<IncidentEntity> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus targetStatus,
    required UserEntity actor,
  }) async =>
      items.first.copyWith(status: targetStatus);
}

class _TestResourceRepo implements ResourceRepository {
  @override
  Stream<void> get onResourcesChanged => const Stream.empty();

  @override
  Future<List<ResourceLogEntity>> getResourceLogs(String incidentId) async =>
      const [];

  @override
  Future<List<ResourceSummaryItem>> getResourceSummary(
          String incidentId) async =>
      const [];

  @override
  Future<ResourceLogEntity> logResource({
    required String incidentId,
    required String resourceType,
    required double quantity,
    required String unit,
    String? notes,
    required String loggedBy,
  }) async =>
      throw UnimplementedError();
}

class _FakeLocationService implements LocationService {
  @override
  Future<({double latitude, double longitude})?> getCurrentLocation() async =>
      null;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async =>
      null;

  @override
  Future<bool> checkPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<LocationPermissionStatus> checkPermissionStatus() async =>
      LocationPermissionStatus.denied;

  @override
  Future<LocationPermissionStatus> requestPermissionStatus() async =>
      LocationPermissionStatus.denied;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> shouldShowLocationRationale() async => false;
}

class _FakeMediaService implements MediaService {
  @override
  Future<MediaPermissionStatus> checkCameraPermission() async =>
      MediaPermissionStatus.denied;

  @override
  Future<MediaPermissionStatus> checkGalleryPermission() async =>
      MediaPermissionStatus.denied;

  @override
  Future<String?> pickImageFromCamera() async => null;

  @override
  Future<String?> pickImageFromGallery() async => null;

  @override
  Future<List<String>> pickMultipleImagesFromGallery({int maxImages = 5}) async =>
      const [];

  @override
  Future<MediaPermissionStatus> requestCameraPermission() async =>
      MediaPermissionStatus.denied;

  @override
  Future<MediaPermissionStatus> requestGalleryPermission() async =>
      MediaPermissionStatus.denied;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> shouldShowCameraRationale() async => false;

  @override
  Future<bool> shouldShowGalleryRationale() async => false;
}

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

void main() {
  final now = DateTime.utc(2026, 11, 13, 10, 0);

  const coordinator = UserEntity(
    id: 'coord-1',
    email: 'coord@pulsegrid.com',
    displayName: 'Sarah Chen',
    role: UserRole.coordinator,
  );

  const responder1 = UserEntity(
    id: 'resp-1',
    email: 'marcus@pulsegrid.com',
    displayName: 'Marcus Vance',
    role: UserRole.responder,
  );

  const responder2 = UserEntity(
    id: 'resp-2',
    email: 'ali@pulsegrid.com',
    displayName: 'Ali Khan',
    role: UserRole.responder,
  );

  late _TestLocalDataSource localDb;
  late _TestIncidentRepo repo;
  late IncidentBloc bloc;

  setUp(() async {
    await sl.reset();
    localDb = _TestLocalDataSource();
    sl.registerSingleton<LocalDataSource>(localDb);
    repo = _TestIncidentRepo()
      ..responders = [responder1, responder2]
      ..activeCounts = {'resp-1': 2, 'resp-2': 0}
      ..items.add(
        IncidentEntity(
          id: 'inc-1',
          title: 'Bridge Crack',
          category: 'Infrastructure',
          severity: IncidentSeverity.high,
          description: 'Structural crack observed.',
          status: IncidentStatus.newIncident,
          createdBy: responder1.displayName,
          createdAt: now,
          updatedAt: now,
        ),
      );
    bloc = IncidentBloc(incidentRepository: repo);
  });

  tearDown(() async {
    await bloc.close();
    await localDb.close();
    await sl.reset();
  });

  testWidgets('ResponderPickerBottomSheet searches, shows active badges, and assigns responder',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ResponderPickerBottomSheet.show(
                  context,
                  incidentId: 'inc-1',
                  currentUser: coordinator,
                  repository: repo,
                ),
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    expect(find.text('Assign Responder'), findsWidgets);
    expect(find.text('Marcus Vance'), findsOneWidget);
    expect(find.text('2 active'), findsOneWidget);
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.text('0 active'), findsOneWidget);

    // Search filters to Ali Khan
    await tester.enterText(find.byType(TextFormField), 'ali');
    await tester.pumpAndSettle();
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.text('Marcus Vance'), findsNothing);

    // Select Ali Khan and confirm
    await tester.tap(find.text('Ali Khan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.lastAssignedResponder?.id, 'resp-2');
  });

  testWidgets('IncidentDetailsScreen displays Assigned to row and downgrades Responder 1 live on reassignment',
      (tester) async {
    localDb.currentAssignment = AssignmentModel(
      id: 'assign-1',
      incidentId: 'inc-1',
      responderId: 'resp-1',
      assignedBy: 'coord-1',
      assignedAt: now,
    );
    repo.items[0] = repo.items[0].copyWith(status: IncidentStatus.assigned);
    final resCubit = ResourceCubit(resourceRepository: _TestResourceRepo());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: IncidentDetailsScreen(
            incident: repo.items[0],
            currentUser: responder1,
            resourceCubit: resCubit,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assigned to Marcus Vance'), findsOneWidget);
    // Responder cannot see Coordinator-only Change button
    expect(find.text('Change'), findsNothing);
    // Responder 1 currently has action & log buttons
    expect(find.text('Log Resource'), findsOneWidget);
    expect(find.text('Advance Status'), findsOneWidget);

    // Live reassignment to Responder 2
    localDb.emitAssignmentChange(
      AssignmentModel(
        id: 'assign-2',
        incidentId: 'inc-1',
        responderId: 'resp-2',
        assignedBy: 'coord-1',
        assignedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assigned to Ali Khan'), findsOneWidget);
    // Responder 1 loses edit/act/log controls immediately
    expect(find.text('Log Resource'), findsNothing);
    expect(find.text('Advance Status'), findsNothing);
    await resCubit.close();
  });

  testWidgets('CreateIncidentScreen in Edit Mode pops 1 step on Incident Reassigned dialog',
      (tester) async {
    localDb.currentAssignment = AssignmentModel(
      id: 'assign-1',
      incidentId: 'inc-1',
      responderId: 'resp-1',
      assignedBy: 'coord-1',
      assignedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: bloc,
                      child: CreateIncidentScreen(
                        currentUser: responder1,
                        existingIncident: repo.items[0],
                        locationService: _FakeLocationService(),
                        mediaService: _FakeMediaService(),
                        networkInfo: _FakeNetworkInfo(),
                      ),
                    ),
                  ),
                ),
                child: const Text('Go Edit'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Incident'), findsOneWidget);

    // Reassign to Responder 2 while Responder 1 is editing
    localDb.emitAssignmentChange(
      AssignmentModel(
        id: 'assign-2',
        incidentId: 'inc-1',
        responderId: 'resp-2',
        assignedBy: 'coord-1',
        assignedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incident Reassigned'), findsOneWidget);
    await tester.tap(find.text('Go Back'));
    await tester.pumpAndSettle();

    // Popped 1 step back to previous route
    expect(find.text('Go Edit'), findsOneWidget);
  });

  testWidgets('LogResourceBottomSheet swaps to reassignment notice with Close button when reassigned',
      (tester) async {
    final resCubit = ResourceCubit(resourceRepository: _TestResourceRepo());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: resCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => LogResourceBottomSheet.show(
                  context,
                  incidentId: 'inc-1',
                  currentUser: responder1,
                ),
                child: const Text('Open Log Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Log Sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Log Emergency Resource'), findsOneWidget);

    // Reassign to Responder 2 while sheet is open
    localDb.emitAssignmentChange(
      AssignmentModel(
        id: 'assign-2',
        incidentId: 'inc-1',
        responderId: 'resp-2',
        assignedBy: 'coord-1',
        assignedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incident Reassigned'), findsOneWidget);
    expect(find.text('Log Emergency Resource'), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Incident Reassigned'), findsNothing);
    await resCubit.close();
  });
}
