import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../core/generator/generator.dart';
import '../core/generator/word_bank.dart';
import '../storage/game_storage.dart';
import 'daily_session.dart';
import 'practice_session.dart';
import 'settings_controller.dart';
import 'stats.dart';

/// Everything that lives as long as the app: settings, stats, the practice
/// game and the daily puzzle of the current day.
class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    required this.bank,
    PuzzleGenerator? generator,
    DateTime Function()? now,
    this.autoTick = true,
  })  : _generator = generator,
        _now = now ?? DateTime.now;

  /// Daily states older than this many days are deleted at start-up.
  static const int keepDailyDays = 7;

  final KeyValueStore store;
  final List<BankEntry> bank;
  final bool autoTick;
  final PuzzleGenerator? _generator;
  final DateTime Function() _now;

  late final SettingsController settings =
      SettingsController(SlotStorage(store, themeSlot));
  late final StatsRepository stats =
      StatsRepository(SlotStorage(store, statsSlot));
  late final PracticeSession practice = PracticeSession(
    bank: bank,
    storage: SlotStorage(store, practiceSlot),
    generator: _generator,
    now: _now,
    autoTick: autoTick,
    onSolved: (info) => stats.recordWin(
      size: info.size,
      elapsed: info.elapsed,
      helpersUsed: info.helpersUsed,
    ),
  );

  DailySession? _daily;

  /// True while a play screen is open.
  bool playing = false;

  /// Today's daily puzzle (available after [init]).
  DailySession get daily => _daily!;

  /// The device's calendar day.
  String get today => dateKey(_now());

  Future<void> init() async {
    await settings.load();
    await stats.load();
    await practice.restore();
    _daily = await _openDaily(today);
    await _pruneOldDailies();
  }

  /// Switch to the new day's puzzle once the date has changed.
  Future<void> refreshDaily() async {
    final old = _daily;
    final day = today;
    if (old == null || old.date == day) return;
    final next = await _openDaily(day);
    if (_daily != old) {
      next.dispose();
      return;
    }
    _daily = next;
    old.dispose();
    notifyListeners();
  }

  void appPaused() {
    practice.pause();
    _daily?.pause();
  }

  void appResumed() {
    practice.resume();
    _daily?.resume();
    if (!playing) refreshDaily();
  }

  @override
  void dispose() {
    practice.dispose();
    _daily?.dispose();
    stats.dispose();
    settings.dispose();
    super.dispose();
  }

  Future<DailySession> _openDaily(String date) async {
    final session = DailySession(
      bank: bank,
      date: date,
      storage: SlotStorage(store, dailySlot(date)),
      generator: _generator,
      now: _now,
      autoTick: autoTick,
      onSolved: (info) => stats.recordWin(
        size: info.size,
        elapsed: info.elapsed,
        helpersUsed: info.helpersUsed,
        dailyDate: date,
      ),
    );
    await session.restore();
    return session;
  }

  Future<void> _pruneOldDailies() async {
    final day = today;
    for (final key in await store.keys()) {
      if (!key.startsWith(dailySlotPrefix)) continue;
      final date = key.substring(dailySlotPrefix.length);
      try {
        if (daysBetween(date, day) > keepDailyDays) await store.remove(key);
      } on FormatException {
        await store.remove(key);
      }
    }
  }
}
