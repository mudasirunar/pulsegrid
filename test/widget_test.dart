import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/theme/theme_cubit.dart';
import 'package:pulsegrid/main.dart';

void main() {
  testWidgets('App smoke test renders Pulse Grid home screen and toggles theme',
      (WidgetTester tester) async {
    final themeCubit = ThemeCubit();

    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: themeCubit,
        child: const PulseGridApp(),
      ),
    );

    // Verify title and card text render
    expect(find.text('Pulse Grid'), findsOneWidget);
    expect(find.text('Offline-First Emergency Coordination'), findsOneWidget);

    // Verify theme toggle button exists and can be tapped
    final toggleButton = find.byType(IconButton);
    expect(toggleButton, findsOneWidget);

    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Verify state transitioned
    expect(themeCubit.state, isNot(ThemeMode.system));
  });
}
