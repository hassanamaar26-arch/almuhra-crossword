import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../storage/game_storage.dart';

/// Player numbers. Immutable; [withWin] returns the updated copy.
@immutable
class PlayerStats {
  const PlayerStats({
    this.totalSolved = 0,
    this.dailySolved = 0,
    this.noHintWins = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastDailyDate,
    this.bestTimesMs = const {},
  });

  factory PlayerStats.fromJson(Map<String, dynamic> j) {
    int count(String key) {
      final v = j[key] as int;
      if (v < 0) throw FormatException('negative $key');
      return v;
    }

    final last = j['lastDailyDate'] as String?;
    if (last != null) parseDateKey(last);
    final times = <int, int>{};
    for (final e in (j['bestTimesMs'] as Map).entries) {
      final ms = e.value as int;
      if (ms < 0) throw const FormatException('negative time');
      times[int.parse(e.key as String)] = ms;
    }
    return PlayerStats(
      totalSolved: count('totalSolved'),
      dailySolved: count('dailySolved'),
      noHintWins: count('noHintWins'),
      currentStreak: count('currentStreak'),
      bestStreak: count('bestStreak'),
      lastDailyDate: last,
      bestTimesMs: Map.unmodifiable(times),
    );
  }

  /// Every solved puzzle, daily and practice.
  final int totalSolved;
  final int dailySolved;

  /// Solved without any check or reveal.
  final int noHintWins;

  /// Consecutive daily puzzles ending at [lastDailyDate].
  final int currentStreak;
  final int bestStreak;
  final String? lastDailyDate;

  /// Fastest no-helper solve per grid size, in milliseconds.
  final Map<int, int> bestTimesMs;

  Duration? bestTime(int size) {
    final ms = bestTimesMs[size];
    return ms == null ? null : Duration(milliseconds: ms);
  }

  /// The streak as it stands on [today]: it is alive only if the last daily
  /// solved was today's or yesterday's.
  int streakOn(String today) {
    final last = lastDailyDate;
    if (last == null) return 0;
    return last == today || last == previousDay(today) ? currentStreak : 0;
  }

  /// [dailyDate] is the date of the daily puzzle, or null for practice.
  PlayerStats withWin({
    required int size,
    required Duration elapsed,
    required int helpersUsed,
    String? dailyDate,
  }) {
    if (dailyDate != null && dailyDate == lastDailyDate) return this;

    var current = currentStreak;
    var last = lastDailyDate;
    if (dailyDate != null) {
      final gap = last == null ? null : daysBetween(last, dailyDate);
      if (gap == null || gap > 1) {
        current = 1;
        last = dailyDate;
      } else if (gap == 1) {
        current = currentStreak + 1;
        last = dailyDate;
      }
      // gap < 0: an older puzzle (device clock moved back) — streak untouched.
    }

    final times = Map.of(bestTimesMs);
    final ms = elapsed.inMilliseconds;
    if (helpersUsed == 0 && (times[size] == null || ms < times[size]!)) {
      times[size] = ms;
    }

    return PlayerStats(
      totalSolved: totalSolved + 1,
      dailySolved: dailySolved + (dailyDate == null ? 0 : 1),
      noHintWins: noHintWins + (helpersUsed == 0 ? 1 : 0),
      currentStreak: current,
      bestStreak: current > bestStreak ? current : bestStreak,
      lastDailyDate: last,
      bestTimesMs: Map.unmodifiable(times),
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'totalSolved': totalSolved,
        'dailySolved': dailySolved,
        'noHintWins': noHintWins,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastDailyDate': lastDailyDate,
        'bestTimesMs': {
          for (final e in bestTimesMs.entries) '${e.key}': e.value,
        },
      };
}

/// Loads, updates and saves [PlayerStats].
class StatsRepository extends ChangeNotifier {
  StatsRepository(this.storage);

  final GameStorage storage;
  PlayerStats _stats = const PlayerStats();
  Future<void> _pendingSave = Future.value();
  Object? lastSaveError;

  PlayerStats get stats => _stats;
  Future<void> get pendingSave => _pendingSave;

  Future<void> load() async {
    final raw = await storage.read();
    if (raw == null) return;
    try {
      _stats = PlayerStats.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      // Damaged stats: start from zero instead of crashing.
      _stats = const PlayerStats();
    }
    notifyListeners();
  }

  void recordWin({
    required int size,
    required Duration elapsed,
    required int helpersUsed,
    String? dailyDate,
  }) {
    final next = _stats.withWin(
      size: size,
      elapsed: elapsed,
      helpersUsed: helpersUsed,
      dailyDate: dailyDate,
    );
    if (identical(next, _stats)) return;
    _stats = next;
    final data = jsonEncode(next.toJson());
    _pendingSave = _pendingSave.then((_) => storage.write(data)).then(
      (_) => lastSaveError = null,
      onError: (Object e) => lastSaveError = e,
    );
    notifyListeners();
  }
}
