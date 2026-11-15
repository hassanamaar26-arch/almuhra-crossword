import 'package:shared_preferences/shared_preferences.dart';

/// On-device key/value storage. Everything the app keeps goes through it.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Future<List<String>> keys();
}

/// In memory only (tests, or as a safe fallback).
class MemoryStore implements KeyValueStore {
  final Map<String, String> data = {};
  int writes = 0;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
    writes++;
  }

  @override
  Future<void> remove(String key) async => data.remove(key);

  @override
  Future<List<String>> keys() async => data.keys.toList();
}

/// Default store.
class SharedPrefsStore implements KeyValueStore {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async {
    await (await SharedPreferences.getInstance()).setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await SharedPreferences.getInstance()).remove(key);
  }

  @override
  Future<List<String>> keys() async =>
      (await SharedPreferences.getInstance()).getKeys().toList();
}

// Keys used by the app.
const String practiceSlot = 'practice_game_v1';
const String statsSlot = 'stats_v1';
const String themeSlot = 'theme_mode';
const String dailySlotPrefix = 'daily_state_';
String dailySlot(String date) => '$dailySlotPrefix$date';

/// One saved value (a game, the stats, a setting).
abstract class GameStorage {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

/// One key of a [KeyValueStore].
class SlotStorage implements GameStorage {
  SlotStorage(this.store, this.key);
  final KeyValueStore store;
  final String key;

  @override
  Future<String?> read() => store.read(key);

  @override
  Future<void> write(String data) => store.write(key, data);

  @override
  Future<void> clear() => store.remove(key);
}

/// A single value kept in memory (tests).
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
