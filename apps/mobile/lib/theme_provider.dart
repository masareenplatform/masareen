import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:masaren/theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'masaren_theme';
  bool _dark = false;
  bool get dark => _dark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dark = prefs.getBool(_key) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle() async {
    _dark = !_dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, _dark);
    } catch (_) {}
  }

  Future<void> setDark(bool v) async {
    _dark = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, _dark);
    } catch (_) {}
  }

  ThemeData get theme => buildTheme(dark: _dark);
}

