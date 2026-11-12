import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/incidents/presentation/widgets/incident_lifecycle_stepper.dart';

void main() {
  testWidgets('IncidentLifecycleStepper renders all steps without layout exceptions', (tester) async {
    for (final status in IncidentStatus.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('LIFECYCLE STATE'),
                  const SizedBox(height: 12),
                  IncidentLifecycleStepper(currentStatus: status),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Assigned'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);
    }
  });

  testWidgets('When incident is closed, all 5 steps show green checkmarks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: IncidentLifecycleStepper(currentStatus: IncidentStatus.closed),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // All 5 circles have checkmark icons
    expect(find.byIcon(Icons.check), findsNWidgets(5));
    // No number text remains
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsNothing);
    expect(find.text('4'), findsNothing);
    expect(find.text('5'), findsNothing);
  });
}
