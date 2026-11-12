import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/widgets/app_image_viewer.dart';

void main() {
  Widget buildViewerTestBed({
    required List<String> photoPaths,
    int initialIndex = 0,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  AppImageViewer.show(
                    context,
                    photoPaths: photoPaths,
                    initialIndex: initialIndex,
                  );
                },
                child: const Text('Open Viewer'),
              ),
            ),
          );
        },
      ),
    );
  }

  group('AppImageViewer Widget Tests', () {
    testWidgets('Renders top counter badge and top back button', (tester) async {
      await tester.pumpWidget(
        buildViewerTestBed(
          photoPaths: ['/tmp/test1.jpg', '/tmp/test2.jpg', '/tmp/test3.jpg'],
        ),
      );

      // Tap button to open viewer
      await tester.tap(find.text('Open Viewer'));
      await tester.pumpAndSettle();

      // Top counter shows "1 / 3"
      expect(find.text('1 / 3'), findsOneWidget);

      // Top back button exists
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('Initial index opens at the specified photo', (tester) async {
      await tester.pumpWidget(
        buildViewerTestBed(
          photoPaths: ['/tmp/test1.jpg', '/tmp/test2.jpg', '/tmp/test3.jpg'],
          initialIndex: 1,
        ),
      );

      await tester.tap(find.text('Open Viewer'));
      await tester.pumpAndSettle();

      // Top counter shows "2 / 3"
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('Tapping back icon in top bar closes the viewer', (tester) async {
      await tester.pumpWidget(
        buildViewerTestBed(
          photoPaths: ['/tmp/test1.jpg'],
        ),
      );

      await tester.tap(find.text('Open Viewer'));
      await tester.pumpAndSettle();

      expect(find.byType(AppImageViewer), findsOneWidget);

      // Tap top back icon
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AppImageViewer), findsNothing);
    });

    testWidgets('Swiping horizontally changes pages and updates counter', (tester) async {
      await tester.pumpWidget(
        buildViewerTestBed(
          photoPaths: ['/tmp/test1.jpg', '/tmp/test2.jpg'],
        ),
      );

      await tester.tap(find.text('Open Viewer'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);

      // Fling left to switch to next page
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 2000);
      await tester.pumpAndSettle();

      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('Swiping down dismisses the viewer', (tester) async {
      await tester.pumpWidget(
        buildViewerTestBed(
          photoPaths: ['/tmp/test1.jpg'],
        ),
      );

      await tester.tap(find.text('Open Viewer'));
      await tester.pumpAndSettle();

      expect(find.byType(AppImageViewer), findsOneWidget);

      // Fast vertical drag downward
      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Dismissed
      expect(find.byType(AppImageViewer), findsNothing);
    });

    testWidgets('Double tap triggers zoom transformation', (tester) async {
      await tester.pumpWidget(
        buildViewerTestBed(
          photoPaths: ['/tmp/test1.jpg'],
        ),
      );

      await tester.tap(find.text('Open Viewer'));
      await tester.pumpAndSettle();

      final interactiveViewer = find.byType(InteractiveViewer);
      expect(interactiveViewer, findsOneWidget);

      // Double tap center
      await tester.tap(interactiveViewer);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(interactiveViewer);
      await tester.pumpAndSettle();

      // Should still be open and interactive
      expect(find.byType(AppImageViewer), findsOneWidget);
    });
  });
}
