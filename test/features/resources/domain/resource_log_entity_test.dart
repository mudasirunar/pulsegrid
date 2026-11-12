import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/errors/exceptions.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_log_entity.dart';
import 'package:pulsegrid/features/resources/domain/entities/resource_summary_item.dart';

void main() {
  group('ResourceLogEntity', () {
    final now = DateTime(2026, 11, 12, 12, 0, 0);

    test('valid resource parameters pass validation without error', () {
      expect(
        () => ResourceLogEntity.validate(
          incidentId: 'inc-1',
          resourceType: 'Water',
          quantity: 25.0,
          unit: 'Liters',
          loggedBy: 'responder-1',
        ),
        returnsNormally,
      );
    });

    test('validates quantity > 0 strictly (rejects 0 and negative values)', () {
      // 0 should throw
      expect(
        () => ResourceLogEntity.validate(
          incidentId: 'inc-1',
          resourceType: 'Water',
          quantity: 0.0,
          unit: 'Liters',
          loggedBy: 'responder-1',
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('greater than zero'),
        )),
      );

      // Negative should throw
      expect(
        () => ResourceLogEntity.validate(
          incidentId: 'inc-1',
          resourceType: 'Water',
          quantity: -15.5,
          unit: 'Liters',
          loggedBy: 'responder-1',
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('greater than zero'),
        )),
      );
    });

    test('validates non-empty fields (incidentId, resourceType, unit, loggedBy)', () {
      expect(
        () => ResourceLogEntity.validate(
          incidentId: '   ',
          resourceType: 'Water',
          quantity: 10,
          unit: 'Liters',
          loggedBy: 'responder-1',
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => ResourceLogEntity.validate(
          incidentId: 'inc-1',
          resourceType: '',
          quantity: 10,
          unit: 'Liters',
          loggedBy: 'responder-1',
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => ResourceLogEntity.validate(
          incidentId: 'inc-1',
          resourceType: 'Water',
          quantity: 10,
          unit: '  ',
          loggedBy: 'responder-1',
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => ResourceLogEntity.validate(
          incidentId: 'inc-1',
          resourceType: 'Water',
          quantity: 10,
          unit: 'Liters',
          loggedBy: '   ',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('converts toModel and fromModel correctly', () {
      final entity = ResourceLogEntity(
        id: 'res-101',
        incidentId: 'inc-200',
        resourceType: 'Oxygen Tanks',
        quantity: 4.0,
        unit: 'Tanks',
        notes: 'Delivered to trauma unit',
        loggedBy: 'user-resp',
        createdAt: now,
      );

      final model = entity.toModel();
      expect(model.id, 'res-101');
      expect(model.incidentId, 'inc-200');
      expect(model.resourceType, 'Oxygen Tanks');
      expect(model.quantity, 4.0);
      expect(model.unit, 'Tanks');
      expect(model.notes, 'Delivered to trauma unit');
      expect(model.loggedBy, 'user-resp');
      expect(model.createdAt, now);

      final reconstructed = ResourceLogEntity.fromModel(model);
      expect(reconstructed, entity);
    });
  });

  group('ResourceSummaryItem', () {
    test('formats whole numbers cleanly without trailing zero', () {
      const item = ResourceSummaryItem(
        resourceType: 'Water',
        totalQuantity: 150.0,
        unit: 'Liters',
      );
      expect(item.formattedTotal, '150 Liters');
    });

    test('formats fractional numbers with one decimal place', () {
      const item = ResourceSummaryItem(
        resourceType: 'Fuel',
        totalQuantity: 12.5,
        unit: 'Liters',
      );
      expect(item.formattedTotal, '12.5 Liters');
    });
  });
}
