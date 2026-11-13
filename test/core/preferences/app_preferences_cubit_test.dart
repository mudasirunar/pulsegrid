import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/preferences/app_preferences_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to hapticEnabled=true and compactCards=false', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cubit = AppPreferencesCubit(prefs);

    expect(cubit.state.hapticEnabled, isTrue);
    expect(cubit.state.compactCards, isFalse);
    await cubit.close();
  });

  test('persists and restores hapticEnabled and compactCards', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cubit = AppPreferencesCubit(prefs);

    await cubit.setHapticEnabled(false);
    await cubit.setCompactCards(true);

    expect(cubit.state.hapticEnabled, isFalse);
    expect(cubit.state.compactCards, isTrue);

    final restored = AppPreferencesCubit(prefs);
    expect(restored.state.hapticEnabled, isFalse);
    expect(restored.state.compactCards, isTrue);

    await cubit.close();
    await restored.close();
  });
}

