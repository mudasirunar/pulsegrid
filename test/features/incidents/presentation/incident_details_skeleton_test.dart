import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/incidents/presentation/widgets/incident_details_skeleton.dart';

void main() {
  testWidgets('IncidentDetailsSkeleton renders all skeleton shimmer sections without overflow', (tester) async {
    // 1. Dark Mode
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: IncidentDetailsSkeleton(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(IncidentDetailsSkeleton), findsOneWidget);
    expect(find.byType(IncidentShimmerBox), findsWidgets);

    // 2. Light Mode
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: Scaffold(
          body: IncidentDetailsSkeleton(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(IncidentDetailsSkeleton), findsOneWidget);
  });
}
