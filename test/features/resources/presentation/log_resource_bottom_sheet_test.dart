import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_log_entity.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_summary_item.dart';
import 'package:pulsegrid/features/resources/domain/repositories/resource_repository.dart';
import 'package:pulsegrid/features/resources/presentation/cubit/resource_cubit.dart';
import 'package:pulsegrid/features/resources/presentation/widgets/log_resource_bottom_sheet.dart';

class _FakeResourceRepo implements ResourceRepository {
  ResourceLogEntity? lastLogged;

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
    lastLogged = ResourceLogEntity(
      id: 'res-new',
      incidentId: incidentId,
      resourceType: resourceType,
      quantity: quantity,
      unit: unit,
      notes: notes,
      loggedBy: loggedBy,
      createdAt: DateTime.now(),
    );
    return lastLogged!;
  }

  @override
  Future<List<ResourceLogEntity>> getResourceLogs(String incidentId) async =>
      lastLogged != null ? [lastLogged!] : [];

  @override
  Future<List<ResourceSummaryItem>> getResourceSummary(String incidentId) async =>
      lastLogged != null
          ? [
              ResourceSummaryItem(
                resourceType: lastLogged!.resourceType,
                totalQuantity: lastLogged!.quantity,
                unit: lastLogged!.unit,
              )
            ]
          : [];
}

void main() {
  late _FakeResourceRepo fakeRepo;
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
    fakeRepo = _FakeResourceRepo();
    cubit = ResourceCubit(resourceRepository: fakeRepo);
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildTestWidget({required UserEntity user, VoidCallback? onLogged}) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: LogResourceBottomSheet(
            incidentId: 'inc-100',
            currentUser: user,
            onResourceLogged: onLogged,
          ),
        ),
      ),
    );
  }

  testWidgets('renders empty and suppresses form when user is a Viewer', (tester) async {
    await tester.pumpWidget(buildTestWidget(user: viewer));
    await tester.pumpAndSettle();

    expect(find.text('Log Resource'), findsNothing);
    expect(find.text('Log Emergency Resource'), findsNothing);
  });

  testWidgets('validates quantity: shows error when empty or <= 0', (tester) async {
    await tester.pumpWidget(buildTestWidget(user: responder));
    await tester.pumpAndSettle();

    expect(find.text('Log Emergency Resource'), findsOneWidget);

    // 1. Submit with empty quantity
    await tester.tap(find.text('Log Resource'));
    await tester.pumpAndSettle();

    expect(find.text('Enter quantity'), findsOneWidget);
    expect(fakeRepo.lastLogged, isNull);

    // 2. Submit with 0
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.text('Log Resource'));
    await tester.pumpAndSettle();

    expect(find.text('Must be > 0'), findsOneWidget);
    expect(fakeRepo.lastLogged, isNull);

    // 3. Submit with negative value
    await tester.enterText(find.byType(TextFormField).first, '-10');
    await tester.tap(find.text('Log Resource'));
    await tester.pumpAndSettle();

    expect(find.text('Must be > 0'), findsOneWidget);
    expect(fakeRepo.lastLogged, isNull);
  });

  testWidgets('submitting valid inputs logs resource and triggers callback', (tester) async {
    bool callbackCalled = false;

    await tester.pumpWidget(buildTestWidget(
      user: responder,
      onLogged: () => callbackCalled = true,
    ));
    await tester.pumpAndSettle();

    // Enter quantity
    await tester.enterText(find.byType(TextFormField).first, '35.5');

    // Enter notes (second TextFormField)
    await tester.enterText(find.byType(TextFormField).last, 'Delivered to Shelter 2');

    // Tap submit
    await tester.tap(find.text('Log Resource'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastLogged, isNotNull);
    expect(fakeRepo.lastLogged!.quantity, 35.5);
    expect(fakeRepo.lastLogged!.notes, 'Delivered to Shelter 2');
    expect(fakeRepo.lastLogged!.incidentId, 'inc-100');
    expect(callbackCalled, isTrue);
  });

  testWidgets('selecting Other displays animated custom resource field and logs custom name', (tester) async {
    await tester.pumpWidget(buildTestWidget(user: responder));
    await tester.pumpAndSettle();

    // Verify custom resource field is not visible initially
    expect(find.byKey(const ValueKey('custom_resource_name_field')), findsNothing);

    // Open category dropdown and select Other
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    // Verify animated slide-in field appeared
    expect(find.byKey(const ValueKey('custom_resource_name_field')), findsOneWidget);
    expect(find.text('SPECIFY RESOURCE NAME'), findsOneWidget);

    // Try submit without custom name
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. 50'), '20');
    await tester.tap(find.text('Log Resource'));
    await tester.pumpAndSettle();

    expect(find.text('Please specify resource name'), findsOneWidget);

    // Enter custom name
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Generators, Sandbags, Stretchers'),
      'Diesel Generators',
    );
    await tester.tap(find.text('Log Resource'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastLogged, isNotNull);
    expect(fakeRepo.lastLogged!.resourceType, 'Diesel Generators');
    expect(fakeRepo.lastLogged!.quantity, 20.0);
  });

  testWidgets('typing on textfields immediately clears their respective error states', (tester) async {
    await tester.pumpWidget(buildTestWidget(user: responder));
    await tester.pumpAndSettle();

    // Trigger quantity error
    await tester.tap(find.text('Log Resource'));
    await tester.pumpAndSettle();
    expect(find.text('Enter quantity'), findsOneWidget);

    // Typing in quantity field clears quantity error immediately
    await tester.enterText(find.byType(TextFormField).first, '1');
    await tester.pumpAndSettle();
    expect(find.text('Enter quantity'), findsNothing);

    // Select Other to trigger custom resource error
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    // Trigger custom resource error
    await tester.tap(find.text('Log Resource'));
    await tester.pumpAndSettle();
    expect(find.text('Please specify resource name'), findsOneWidget);

    // Typing in custom resource field clears custom resource error immediately
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Generators, Sandbags, Stretchers'),
      'G',
    );
    await tester.pumpAndSettle();
    expect(find.text('Please specify resource name'), findsNothing);
  });
}

