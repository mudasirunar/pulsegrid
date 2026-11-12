import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/errors/exceptions.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_log_entity.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_summary_item.dart';
import 'package:pulsegrid/features/resources/domain/repositories/resource_repository.dart';
import 'package:pulsegrid/features/resources/presentation/cubit/resource_cubit.dart';
import 'package:pulsegrid/features/resources/presentation/cubit/resource_state.dart';

class _MockResourceRepository implements ResourceRepository {
  final List<ResourceLogEntity> logs = [];
  final StreamController<void> resourceChangedController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onResourcesChanged => resourceChangedController.stream;

  @override
  Future<ResourceLogEntity> logResource({
    required String incidentId,
    required String resourceType,
    required double quantity,
    required String unit,
    String? notes,
    required String loggedBy,
  }) async {
    if (quantity <= 0) {
      throw const ValidationException('Resource quantity must be greater than zero.');
    }
    final entity = ResourceLogEntity(
      id: 'res-${logs.length + 1}',
      incidentId: incidentId,
      resourceType: resourceType,
      quantity: quantity,
      unit: unit,
      notes: notes,
      loggedBy: loggedBy,
      createdAt: DateTime.now(),
    );
    logs.insert(0, entity);
    return entity;
  }

  @override
  Future<List<ResourceLogEntity>> getResourceLogs(String incidentId) async {
    return logs.where((l) => l.incidentId == incidentId).toList();
  }

  @override
  Future<List<ResourceSummaryItem>> getResourceSummary(String incidentId) async {
    final filtered = logs.where((l) => l.incidentId == incidentId);
    final map = <String, double>{};
    final units = <String, String>{};

    for (final item in filtered) {
      map[item.resourceType] = (map[item.resourceType] ?? 0) + item.quantity;
      units[item.resourceType] = item.unit;
    }

    return map.entries
        .map((e) => ResourceSummaryItem(
              resourceType: e.key,
              totalQuantity: e.value,
              unit: units[e.key] ?? 'Units',
            ))
        .toList();
  }
}

void main() {
  late _MockResourceRepository mockRepo;
  late ResourceCubit cubit;

  setUp(() {
    mockRepo = _MockResourceRepository();
    cubit = ResourceCubit(resourceRepository: mockRepo);
  });

  tearDown(() {
    cubit.close();
  });

  group('ResourceCubit', () {
    test('initial state is ResourceInitial', () {
      expect(cubit.state, isA<ResourceInitial>());
    });

    test('loadResources emits [ResourceLoading, ResourceLoaded]', () async {
      final expectedStates = [
        isA<ResourceLoading>(),
        isA<ResourceLoaded>().having((s) => s.summary, 'summary', isEmpty),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      await cubit.loadResources('inc-100');
    });

    test('logResource succeeds and emits [ResourceLoggingInProgress, ResourceOperationSuccess]', () async {
      final expectedStates = [
        isA<ResourceLoggingInProgress>(),
        isA<ResourceOperationSuccess>()
            .having((s) => s.message, 'message', contains('Logged 50 Liters of Water'))
            .having((s) => s.summary.length, 'summary length', 1)
            .having((s) => s.summary.first.totalQuantity, 'totalQuantity', 50.0),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      final success = await cubit.logResource(
        incidentId: 'inc-100',
        resourceType: 'Water',
        quantity: 50.0,
        unit: 'Liters',
        loggedBy: 'responder-01',
      );

      expect(success, isTrue);
    });

    test('logResource emits ResourceError on validation failure', () async {
      final expectedStates = [
        isA<ResourceLoggingInProgress>(),
        isA<ResourceError>().having((s) => s.message, 'message', contains('greater than zero')),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));

      final success = await cubit.logResource(
        incidentId: 'inc-100',
        resourceType: 'Water',
        quantity: -10.0,
        unit: 'Liters',
        loggedBy: 'responder-01',
      );

      expect(success, isFalse);
    });

    test('onResourcesChanged triggers silent reload for the active incident', () async {
      await cubit.loadResources('inc-100');
      expect((cubit.state as ResourceLoaded).logs.length, 0);

      // New log added to repository by background sync
      mockRepo.logs.add(
        ResourceLogEntity(
          id: 'res-bg-1',
          incidentId: 'inc-100',
          resourceType: 'Fuel',
          quantity: 20.0,
          unit: 'Gallons',
          loggedBy: 'team-alpha',
          createdAt: DateTime.now(),
        ),
      );

      // Emit onResourcesChanged
      mockRepo.resourceChangedController.add(null);
      await pumpEventQueue();

      expect(cubit.state, isA<ResourceLoaded>());
      final loaded = cubit.state as ResourceLoaded;
      expect(loaded.logs.length, 1);
      expect(loaded.logs.first.resourceType, 'Fuel');
    });
  });
}

