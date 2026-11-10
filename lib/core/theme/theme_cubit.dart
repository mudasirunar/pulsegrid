import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  static const String _prefKey = 'app_theme_mode';
  final SharedPreferences? _prefs;

  ThemeCubit([this._prefs]) : super(_initialThemeMode(_prefs));

  static ThemeMode _initialThemeMode(SharedPreferences? prefs) {
    if (prefs == null) return ThemeMode.system;
    final savedMode = prefs.getString(_prefKey);
    switch (savedMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(mode);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_prefKey, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_prefKey, 'dark');
        break;
      case ThemeMode.system:
        await prefs.setString(_prefKey, 'system');
        break;
    }
  }

  Future<void> toggleTheme(Brightness currentPlatformBrightness) async {
    final isCurrentlyDark = state == ThemeMode.dark ||
        (state == ThemeMode.system && currentPlatformBrightness == Brightness.dark);
    await setThemeMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}

