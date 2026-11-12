import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.light);
  static final ThemeController instance = ThemeController._();
  static const _key = 'theme_mode';

  bool get isDark => value == ThemeMode.dark;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(_key) == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (_) {}
  }

  Future<void> setDark(bool isDark) async {
    value = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, isDark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> toggle() => setDark(!isDark);
}
