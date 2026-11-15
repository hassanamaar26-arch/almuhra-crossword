import 'package:shared_preferences/shared_preferences.dart';

/// Where the current game is kept between launches. One string (JSON).
abstract class GameStorage {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

/// Keeps the game in memory only (tests, or as a safe fallback).
class MemoryGameStorage implements GameStorage {
  MemoryGameStorage([this.data]);
  String? data;
  int writes = 0;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async {
    this.data = data;
    writes++;
  }

  @override
  Future<void> clear() async => data = null;
}

/// Default: on-device key/value storage.
class SharedPrefsGameStorage implements GameStorage {
  static const String key = 'practice_game_v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String data) async {
    await (await SharedPreferences.getInstance()).setString(key, data);
  }

  @override
  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}
