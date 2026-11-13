import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesState extends Equatable {
  final bool hapticEnabled;
  final bool compactCards;

  const AppPreferencesState({
    this.hapticEnabled = true,
    this.compactCards = false,
  });

  AppPreferencesState copyWith({
    bool? hapticEnabled,
    bool? compactCards,
  }) {
    return AppPreferencesState(
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      compactCards: compactCards ?? this.compactCards,
    );
  }

  @override
  List<Object?> get props => [hapticEnabled, compactCards];
}

class AppPreferencesCubit extends Cubit<AppPreferencesState> {
  static const String _hapticKey = 'pref_haptic_enabled';
  static const String _compactKey = 'pref_compact_cards';

  final SharedPreferences? _prefs;

  AppPreferencesCubit([this._prefs]) : super(_initialState(_prefs));

  static AppPreferencesState _initialState(SharedPreferences? prefs) {
    if (prefs == null) return const AppPreferencesState();
    return AppPreferencesState(
      hapticEnabled: prefs.getBool(_hapticKey) ?? true,
      compactCards: prefs.getBool(_compactKey) ?? false,
    );
  }

  Future<void> setHapticEnabled(bool enabled) async {
    emit(state.copyWith(hapticEnabled: enabled));
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(_hapticKey, enabled);
  }

  Future<void> setCompactCards(bool compact) async {
    emit(state.copyWith(compactCards: compact));
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(_compactKey, compact);
  }
}

