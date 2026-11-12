import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_log_entity.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_summary_item.dart';
import 'package:pulsegrid/features/resources/domain/repositories/resource_repository.dart';
import 'package:pulsegrid/features/resources/presentation/cubit/resource_cubit.dart';
import 'package:pulsegrid/features/resources/presentation/widgets/incident_resource_summary_card.dart';

class _FakeResourceRepository implements ResourceRepository {
  List<ResourceSummaryItem> stubbedSummary = [];
  List<ResourceLogEntity> stubbedLogs = [];

  @override
  Stream<void> get onResourcesChanged => const Stream.empty();

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

  @override
  Future<List<ResourceLogEntity>> getResourceLogs(String incidentId) async => stubbedLogs;

  @override
  Future<List<ResourceSummaryItem>> getResourceSummary(String incidentId) async => stubbedSummary;
}

void main() {
  late _FakeResourceRepository fakeRepo;
  late ResourceCubit cubit;

  final responder = const UserEntity(
    id: 'user-resp',
    email: 'responder@pulsegrid.dev',
    displayName: 'Marcus Vance',
    role: UserRole.responder,
  );

  final viewer = const UserEntity(
    id: 'user-viewer',
    email: 'viewer@pulsegrid.dev',
    displayName: 'Auditor Evans',
    role: UserRole.viewer,
  );

  setUp(() {
    fakeRepo = _FakeResourceRepository();
    cubit = ResourceCubit(resourceRepository: fakeRepo);
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildTestWidget({required UserEntity user}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlocProvider.value(
            value: cubit,
            child: IncidentResourceSummaryCard(
              incidentId: 'inc-100',
              currentUser: user,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders empty state with action button for Responder', (tester) async {
    fakeRepo.stubbedSummary = [];
    fakeRepo.stubbedLogs = [];
    await cubit.loadResources('inc-100');

    await tester.pumpWidget(buildTestWidget(user: responder));
    await tester.pumpAndSettle();

    expect(find.text('ALLOCATED RESOURCES'), findsOneWidget);
    expect(find.text('No resources logged yet'), findsOneWidget);
    expect(find.text('Log Resource'), findsOneWidget); // Empty state action button
  });

  testWidgets('hides log action buttons for Viewer', (tester) async {
    fakeRepo.stubbedSummary = [];
    fakeRepo.stubbedLogs = [];
    await cubit.loadResources('inc-100');

    await tester.pumpWidget(buildTestWidget(user: viewer));
    await tester.pumpAndSettle();

    expect(find.text('ALLOCATED RESOURCES'), findsOneWidget);
    expect(find.text('No resources logged yet'), findsOneWidget);
    expect(find.text('Log Resource'), findsNothing);
    expect(find.text('Supplies recorded for this incident will appear here'), findsOneWidget);
  });

  testWidgets('renders flat row for logged items with notes and timestamp', (tester) async {
    fakeRepo.stubbedLogs = [
      ResourceLogEntity(
        id: 'log-1',
        incidentId: 'inc-100',
        resourceType: 'Water',
        quantity: 120.0,
        unit: 'Liters',
        notes: 'Alpha squad delivered',
        loggedBy: 'user-resp',
        createdAt: DateTime.now(),
      ),
    ];
    await cubit.loadResources('inc-100');

    await tester.pumpWidget(buildTestWidget(user: responder));
    await tester.pumpAndSettle();

    expect(find.text('120 Liters • Water'), findsOneWidget);
    expect(find.text('Alpha squad delivered'), findsOneWidget);
    expect(find.text('Log Resource'), findsOneWidget);
    expect(find.text('View more'), findsNothing); // Under 5 items, no view more button
  });

  testWidgets('limits to 5 items initially and toggles View more and View less when > 5 items', (tester) async {
    fakeRepo.stubbedLogs = List.generate(7, (i) {
      return ResourceLogEntity(
        id: 'log-$i',
        incidentId: 'inc-100',
        resourceType: 'Item #$i',
        quantity: (i + 1) * 10.0,
        unit: 'Units',
        notes: 'Delivery #$i',
        loggedBy: 'user-resp',
        createdAt: DateTime.now().subtract(Duration(minutes: i * 5)),
      );
    });
    await cubit.loadResources('inc-100');

    await tester.pumpWidget(buildTestWidget(user: responder));
    await tester.pumpAndSettle();

    // First 5 items visible
    expect(find.text('10 Units • Item #0'), findsOneWidget);
    expect(find.text('50 Units • Item #4'), findsOneWidget);

    // 6th and 7th items not visible initially
    expect(find.text('60 Units • Item #5'), findsNothing);
    expect(find.text('70 Units • Item #6'), findsNothing);

    // View more button is present
    expect(find.text('View more'), findsOneWidget);

    // Tap View more
    await tester.tap(find.text('View more'));
    await tester.pumpAndSettle();

    // Now all 7 items are visible
    expect(find.text('60 Units • Item #5'), findsOneWidget);
    expect(find.text('70 Units • Item #6'), findsOneWidget);
    expect(find.text('View less'), findsOneWidget);
    expect(find.text('View more'), findsNothing);

    // Tap View less
    await tester.tap(find.text('View less'));
    await tester.pumpAndSettle();

    // Collapsed back to 5 items
    expect(find.text('60 Units • Item #5'), findsNothing);
    expect(find.text('View more'), findsOneWidget);
  });
}
