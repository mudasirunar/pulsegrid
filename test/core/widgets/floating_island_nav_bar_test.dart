import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/widgets/floating_island_nav_bar.dart';

void main() {
  Widget buildSubject({
    int currentIndex = 0,
    required ValueChanged<int> onTabSelected,
    VoidCallback? onTabReselected,
    VoidCallback? onActionPressed,
    bool showActionButton = true,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FloatingIslandNavBar(
            currentIndex: currentIndex,
            onTabSelected: onTabSelected,
            onTabReselected: onTabReselected,
            onActionPressed: onActionPressed,
            showActionButton: showActionButton,
          ),
        ),
      ),
    );
  }

  testWidgets('tapping Home and Profile switches tabs', (tester) async {
    int selected = 0;
    await tester.pumpWidget(
      buildSubject(
        currentIndex: selected,
        onTabSelected: (i) => selected = i,
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(selected, 1);

    await tester.pumpWidget(
      buildSubject(
        currentIndex: selected,
        onTabSelected: (i) => selected = i,
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(selected, 0);
  });

  testWidgets('dragging pill horizontally switches tab on release',
      (tester) async {
    int selected = 0;
    await tester.pumpWidget(
      buildSubject(
        currentIndex: selected,
        onTabSelected: (i) => selected = i,
      ),
    );

    final homeCenter = tester.getCenter(find.text('Home'));
    final profileCenter = tester.getCenter(find.text('Profile'));
    await tester.dragFrom(
      homeCenter,
      Offset(profileCenter.dx - homeCenter.dx, 0),
    );
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

  testWidgets('tapping CTA circle invokes onActionPressed', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      buildSubject(
        onTabSelected: (_) {},
        onActionPressed: () => tapped = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('hides CTA circle when showActionButton is false',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(
        onTabSelected: (_) {},
        showActionButton: false,
      ),
    );

    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('retapping active tab invokes onTabReselected', (tester) async {
    bool reselected = false;
    await tester.pumpWidget(
      buildSubject(
        currentIndex: 0,
        onTabSelected: (_) {},
        onTabReselected: () => reselected = true,
      ),
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(reselected, isTrue);
  });
}

