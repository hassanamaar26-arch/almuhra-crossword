import 'package:flutter/material.dart';

import '../storage/game_storage.dart';

/// The player's theme choice: follow the system, light, or dark.
class SettingsController extends ChangeNotifier {
  SettingsController(this.storage);

  final GameStorage storage;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final raw = await storage.read();
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await storage.write(mode.name);
  }

  /// system → light → dark → system.
  Future<void> cycleThemeMode() => setThemeMode(switch (_themeMode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      });
}
