import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  final Box _settingsBox;

  ThemeProvider(this._settingsBox) {
    _isDarkMode = _settingsBox.get('isDarkMode', defaultValue: false);
  }

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _settingsBox.put('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  /// Explicitly set dark mode on or off.
  void setDark(bool isDark) {
    if (_isDarkMode == isDark) return;
    _isDarkMode = isDark;
    _settingsBox.put('isDarkMode', _isDarkMode);
    notifyListeners();
  }
}
