import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/theme/app_colors.dart';
import 'package:pulsegrid/core/theme/app_theme.dart';
import 'package:pulsegrid/core/widgets/app_dialog.dart';

void main() {
  Widget buildTestableWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(body: child),
    );
  }

  group('AppDialog', () {
    testWidgets('renders icon, title, message, and action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppDialog.show<void>(
                  context: context,
                  title: 'Test Title',
                  message: 'This is a test description message.',
                  icon: Icons.security_rounded,
                  confirmText: 'Acknowledge',
                  cancelText: 'Dismiss',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('This is a test description message.'), findsOneWidget);
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);
      expect(find.text('Acknowledge'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('triggers onConfirm callback and dismisses dialog',
        (WidgetTester tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppDialog.show<void>(
                  context: context,
                  title: 'Confirm Action',
                  confirmText: 'Proceed',
                  onConfirm: () => confirmed = true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Action'), findsOneWidget);

      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
      expect(find.text('Confirm Action'), findsNothing);
    });

    testWidgets('triggers onCancel callback and dismisses dialog',
        (WidgetTester tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppDialog.show<void>(
                  context: context,
                  title: 'Cancel Action',
                  cancelText: 'Abort',
                  onCancel: () => cancelled = true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Action'), findsOneWidget);

      await tester.tap(find.text('Abort'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
      expect(find.text('Cancel Action'), findsNothing);
    });

    testWidgets('supports destructive mode styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const AppDialog(
            title: 'Delete Incident',
            message: 'Are you sure you want to delete this record?',
            icon: Icons.delete_forever_rounded,
            confirmText: 'Delete',
            isDestructive: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Delete Incident'), findsOneWidget);
      final iconFinder = find.byIcon(Icons.delete_forever_rounded);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, AppColors.severityCritical);
    });

    testWidgets('renders dark mode palette correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          themeMode: ThemeMode.dark,
          child: const AppDialog(
            title: 'Dark Mode Dialog',
            message: 'Tactical solar gold accents.',
            icon: Icons.wb_sunny_rounded,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dark Mode Dialog'), findsOneWidget);
      expect(find.text('Tactical solar gold accents.'), findsOneWidget);
    });
  });
}

