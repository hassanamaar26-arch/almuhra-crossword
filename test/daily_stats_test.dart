import 'dart:convert';

import 'package:almuhra_crossword/core/dates.dart';
import 'package:almuhra_crossword/core/generator/generator.dart';
import 'package:almuhra_crossword/core/generator/word_bank.dart';
import 'package:almuhra_crossword/core/share_text.dart';
import 'package:almuhra_crossword/models/puzzle.dart';
import 'package:almuhra_crossword/state/app_controller.dart';
import 'package:almuhra_crossword/state/crossword_controller.dart';
import 'package:almuhra_crossword/state/daily_session.dart';
import 'package:almuhra_crossword/state/game_session.dart';
import 'package:almuhra_crossword/state/settings_controller.dart';
import 'package:almuhra_crossword/state/stats.dart';
import 'package:almuhra_crossword/storage/game_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final bank = loadTestBank();
  var t = DateTime(2026, 11, 15, 10);
  DateTime now() => t;
  void advance(Duration d) => t = t.add(d);
  setUp(() => t = DateTime(2026, 11, 15, 10));

  DailySession daily(
    String date,
    GameStorage storage, {
    void Function(SolvedInfo)? onSolved,
    PuzzleGenerator? generator,
  }) =>
      DailySession(
        bank: bank,
        date: date,
        storage: storage,
        generator: generator ?? syncGenerator,
        now: now,
        autoTick: false,
        onSolved: onSolved,
      );

  group('dates', () {
    test('dateKey uses the calendar day of the given time', () {
      expect(dateKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(dateKey(DateTime(2026, 11, 15)), '2026-11-15');
    });
    test('previousDay crosses months, years and leap days', () {
      expect(previousDay('2026-11-15'), '2026-11-14');
      expect(previousDay('2026-03-01'), '2026-02-28');
      expect(previousDay('2028-03-01'), '2028-02-29');
      expect(previousDay('2027-01-01'), '2026-12-31');
    });
    test('daysBetween and dailyNumber', () {
      expect(daysBetween('2026-11-15', '2026-11-17'), 2);
      expect(daysBetween('2026-11-17', '2026-11-15'), -2);
      expect(daysBetween('2026-12-31', '2027-01-01'), 1);
      expect(dailyNumber('2026-11-15'), 1);
      expect(dailyNumber('2026-11-16'), 2);
      expect(dailyNumber('2027-11-15'), 366);
    });
    test('Arabic date', () {
      expect(formatArabicDate('2026-11-15'), 'الأحد 15 تشرين الثاني 2026');
      expect(formatArabicDate('2027-01-01'), 'الجمعة 1 كانون الثاني 2027');
    });
    test('invalid keys are rejected', () {
      expect(() => parseDateKey('2026-02-30'), throwsFormatException);
      expect(() => parseDateKey('15-11-2026'), throwsFormatException);
      expect(() => parseDateKey(''), throwsFormatException);
    });
  });

  group('daily puzzle', () {
    test('same date → the same 9×9 puzzle for every player', () async {
      final a = daily('2026-11-15', MemoryGameStorage());
      final b = daily('2026-11-15', MemoryGameStorage());
      await a.ensureStarted();
      await b.ensureStarted();
      expect(a.controller!.puzzle.toJson(), b.controller!.puzzle.toJson());
      expect(a.controller!.puzzle.size, 9);
      expect(a.controller!.puzzle.id, 'daily-2026-11-15');
      a.dispose();
      b.dispose();
    });

    test('the seed comes from the date alone', () async {
      expect(DailySession.seedFor('2026-11-15'), 'daily-2026-11-15');
      final a = daily('2026-11-15', MemoryGameStorage());
      await a.ensureStarted();
      final direct = generatePuzzle(bank, size: 9, seed: 'daily-2026-11-15');
      expect(a.controller!.puzzle.toJson()['grid'], direct.json['grid']);
      a.dispose();
    });

    test('the next day brings a different puzzle', () async {
      final grids = <String>{};
      for (final date in ['2026-11-15', '2026-11-16', '2026-11-17', '2027-11-15']) {
        final s = daily(date, MemoryGameStorage());
        await s.ensureStarted();
        grids.add(jsonEncode(s.controller!.puzzle.toJson()['grid']));
        s.dispose();
      }
      expect(grids.length, 4);
    });

    test('no word is excluded, and concurrent starts generate once', () async {
      var calls = 0;
      Set<int>? excluded;
      Future<GeneratedPuzzle> spy(
          List<BankEntry> b, int size, String seed, Set<int> ex) {
        calls++;
        excluded = ex;
        return syncGenerator(b, size, seed, ex);
      }

      final s = daily('2026-11-15', MemoryGameStorage(), generator: spy);
      await Future.wait([s.ensureStarted(), s.ensureStarted()]);
      await s.ensureStarted();
      expect(calls, 1);
      expect(excluded, isEmpty);
      s.dispose();
    });

    test('state is saved for the day and restored', () async {
      final storage = MemoryGameStorage();
      final a = daily('2026-11-15', storage);
      expect(await a.restore(), isFalse);
      await a.ensureStarted();
      a.enter();
      final start = a.controller!.state.cursor;
      a.controller!.input('ب');
      advance(const Duration(seconds: 30));
      a.leave();
      await a.pendingSave;
      a.dispose();

      final b = daily('2026-11-15', storage);
      expect(await b.restore(), isTrue);
      expect(b.controller!.state.cells[start]!.letter, 'ب');
      expect(b.elapsed.value, const Duration(seconds: 30));
      expect(b.isClockRunning, isFalse); // not on the play screen yet
      b.dispose();

      // Another day never loads this state.
      final c = daily('2026-11-16', storage);
      expect(await c.restore(), isFalse);
      expect(c.controller, isNull);
      c.dispose();
    });

    test('solved once: reported once, stays solved with its time', () async {
      final storage = MemoryGameStorage();
      final wins = <SolvedInfo>[];
      final a = daily('2026-11-15', storage, onSolved: wins.add);
      await a.ensureStarted();
      a.enter();
      advance(const Duration(seconds: 95));
      solveAll(a.controller!);
      expect(wins.length, 1);
      expect(wins.single.size, 9);
      expect(wins.single.elapsed, const Duration(seconds: 95));
      expect(wins.single.helpersUsed, 0);
      a.controller!.move(Move.left); // later changes do not report again
      expect(wins.length, 1);
      await a.pendingSave;
      a.dispose();

      final b = daily('2026-11-15', storage, onSolved: wins.add);
      expect(await b.restore(), isTrue);
      await b.ensureStarted(); // must not replace the solved grid
      b.enter();
      advance(const Duration(minutes: 5));
      b.tick();
      expect(b.isSolved, isTrue);
      expect(b.elapsed.value, const Duration(seconds: 95));
      expect(wins.length, 1);
      b.dispose();
    });

    test('the clock runs only while the play screen is open', () async {
      final s = daily('2026-11-15', MemoryGameStorage());
      await s.ensureStarted();
      advance(const Duration(seconds: 50));
      s.tick();
      expect(s.elapsed.value, Duration.zero);
      s.enter();
      advance(const Duration(seconds: 7));
      s.pause(); // app in background
      advance(const Duration(seconds: 100));
      s.resume();
      advance(const Duration(seconds: 3));
      s.leave();
      advance(const Duration(seconds: 100));
      s.tick();
      expect(s.elapsed.value, const Duration(seconds: 10));
      s.dispose();
    });
  });

  group('PlayerStats', () {
    const zero = PlayerStats();
    PlayerStats dailyWin(PlayerStats s, String date, {int helpers = 0, int seconds = 100}) =>
        s.withWin(
          size: 9,
          elapsed: Duration(seconds: seconds),
          helpersUsed: helpers,
          dailyDate: date,
        );

    test('two days in a row make a streak of 2', () {
      final s = dailyWin(dailyWin(zero, '2026-11-15'), '2026-11-16');
      expect(s.currentStreak, 2);
      expect(s.bestStreak, 2);
      expect(s.totalSolved, 2);
      expect(s.dailySolved, 2);
      expect(s.lastDailyDate, '2026-11-16');
    });

    test('missing a day restarts the streak but keeps the best', () {
      var s = dailyWin(dailyWin(zero, '2026-11-15'), '2026-11-16');
      s = dailyWin(s, '2026-11-18');
      expect(s.currentStreak, 1);
      expect(s.bestStreak, 2);
      s = dailyWin(dailyWin(dailyWin(s, '2026-11-19'), '2026-11-20'), '2026-11-21');
      expect(s.currentStreak, 4);
      expect(s.bestStreak, 4);
    });

    test('streak crosses month and year ends', () {
      var s = dailyWin(dailyWin(zero, '2026-11-30'), '2026-12-01');
      expect(s.currentStreak, 2);
      s = dailyWin(dailyWin(zero, '2026-12-31'), '2027-01-01');
      expect(s.currentStreak, 2);
    });

    test('the same daily puzzle never counts twice', () {
      final once = dailyWin(zero, '2026-11-15');
      expect(identical(dailyWin(once, '2026-11-15'), once), isTrue);
    });

    test('an older date (clock moved back) leaves the streak alone', () {
      final s = dailyWin(dailyWin(zero, '2026-11-15'), '2026-11-16');
      final back = dailyWin(s, '2026-11-10');
      expect(back.currentStreak, 2);
      expect(back.lastDailyDate, '2026-11-16');
      expect(back.totalSolved, 3);
    });

    test('streakOn: alive today and tomorrow, gone after a missed day', () {
      final s = dailyWin(dailyWin(zero, '2026-11-15'), '2026-11-16');
      expect(s.streakOn('2026-11-16'), 2);
      expect(s.streakOn('2026-11-17'), 2);
      expect(s.streakOn('2026-11-18'), 0);
      expect(zero.streakOn('2026-11-15'), 0);
    });

    test('practice wins count in the total but not in the streak', () {
      final s = dailyWin(zero, '2026-11-15').withWin(
        size: 7,
        elapsed: const Duration(seconds: 40),
        helpersUsed: 0,
      );
      expect(s.totalSolved, 2);
      expect(s.dailySolved, 1);
      expect(s.currentStreak, 1);
      expect(s.lastDailyDate, '2026-11-15');
    });

    test('no-hint wins and best time per size (helper-free solves only)', () {
      var s = zero.withWin(
          size: 7, elapsed: const Duration(seconds: 90), helpersUsed: 0);
      s = s.withWin(size: 7, elapsed: const Duration(seconds: 20), helpersUsed: 3);
      s = s.withWin(size: 7, elapsed: const Duration(seconds: 120), helpersUsed: 0);
      s = s.withWin(size: 11, elapsed: const Duration(seconds: 300), helpersUsed: 0);
      expect(s.totalSolved, 4);
      expect(s.noHintWins, 3);
      expect(s.bestTime(7), const Duration(seconds: 90));
      expect(s.bestTime(11), const Duration(seconds: 300));
      expect(s.bestTime(9), isNull);
      s = s.withWin(size: 7, elapsed: const Duration(seconds: 61), helpersUsed: 0);
      expect(s.bestTime(7), const Duration(seconds: 61));
    });

    test('JSON round trip; damaged values are rejected', () {
      var s = dailyWin(dailyWin(zero, '2026-11-15'), '2026-11-16', helpers: 1);
      s = s.withWin(size: 11, elapsed: const Duration(seconds: 5), helpersUsed: 0);
      final again = PlayerStats.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(again.toJson(), s.toJson());
      expect(again.bestTime(11), const Duration(seconds: 5));
      expect(
        () => PlayerStats.fromJson(s.toJson()..['totalSolved'] = -1),
        throwsFormatException,
      );
      expect(
        () => PlayerStats.fromJson(s.toJson()..['lastDailyDate'] = 'yesterday'),
        throwsFormatException,
      );
    });
  });

  group('StatsRepository', () {
    test('records, saves and reloads', () async {
      final storage = MemoryGameStorage();
      final repo = StatsRepository(storage);
      await repo.load();
      var notified = 0;
      repo.addListener(() => notified++);
      repo.recordWin(
        size: 9,
        elapsed: const Duration(seconds: 70),
        helpersUsed: 0,
        dailyDate: '2026-11-15',
      );
      repo.recordWin(
        size: 9,
        elapsed: const Duration(seconds: 70),
        helpersUsed: 0,
        dailyDate: '2026-11-15',
      ); // duplicate: ignored
      await repo.pendingSave;
      expect(notified, 1);
      expect(storage.writes, 1);

      final again = StatsRepository(storage);
      await again.load();
      expect(again.stats.totalSolved, 1);
      expect(again.stats.currentStreak, 1);
      expect(again.stats.bestTime(9), const Duration(seconds: 70));
    });

    test('damaged stats start from zero', () async {
      for (final bad in ['nope', '{}', '{"totalSolved":"x"}']) {
        final repo = StatsRepository(MemoryGameStorage(bad));
        await repo.load();
        expect(repo.stats.totalSolved, 0, reason: bad);
      }
    });
  });

  group('share text', () {
    test('date, number, time, helpers and an emoji grid without letters', () async {
      final s = daily('2026-11-16', MemoryGameStorage());
      await s.ensureStarted();
      final c = s.controller!;
      c.revealLetter();
      final revealed = c.state.cursor;
      solveAll(c);
      final text = buildShareText(
        puzzle: c.puzzle,
        cells: c.state.cells,
        date: '2026-11-16',
        elapsed: const Duration(seconds: 192),
        helpersUsed: c.state.helpersUsed,
      );
      final lines = text.split('\n');
      expect(lines[0], 'الكلمات المتقاطعة (المُهرة)');
      expect(lines[1], 'لغز اليوم #2 · 2026-11-16');
      expect(lines[2], 'الوقت 03:12 · المساعدات 1');
      expect(lines.length, 3 + 9);
      for (var r = 0; r < 9; r++) {
        final row = lines[3 + r].runes.map(String.fromCharCode).toList();
        expect(row.length, 9);
        for (var col = 0; col < 9; col++) {
          final p = Pos(r, col);
          final expected = !c.puzzle.isWhite(p)
              ? shareBlock
              : p == revealed
                  ? shareRevealed
                  : shareSolved;
          expect(row[col], expected, reason: '$p');
        }
      }
      // Nothing from the answers leaks into the text.
      final grid = lines.skip(3).join();
      expect(RegExp(r'[ء-ي]').hasMatch(grid), isFalse);
      s.dispose();
    });
  });

  group('SettingsController', () {
    test('defaults to system, cycles, saves and reloads', () async {
      final storage = MemoryGameStorage();
      final a = SettingsController(storage);
      await a.load();
      expect(a.themeMode, ThemeMode.system);
      await a.cycleThemeMode();
      expect(a.themeMode, ThemeMode.light);
      await a.cycleThemeMode();
      expect(a.themeMode, ThemeMode.dark);
      expect(storage.data, 'dark');

      final b = SettingsController(storage);
      await b.load();
      expect(b.themeMode, ThemeMode.dark);
      await b.cycleThemeMode();
      expect(b.themeMode, ThemeMode.system);

      final c = SettingsController(MemoryGameStorage('purple'));
      await c.load();
      expect(c.themeMode, ThemeMode.system);
    });
  });

  group('AppController', () {
    AppController app(MemoryStore store) => AppController(
          store: store,
          bank: bank,
          generator: syncGenerator,
          now: now,
          autoTick: false,
        );

    test('daily and practice are saved separately; wins feed the stats', () async {
      final store = MemoryStore();
      final a = app(store);
      await a.init();
      expect(a.today, '2026-11-15');
      expect(a.daily.date, '2026-11-15');
      expect(a.daily.controller, isNull);
      expect(a.practice.controller, isNull);

      await a.daily.ensureStarted();
      await a.practice.newPuzzle(size: 7);
      await a.daily.pendingSave;
      await a.practice.pendingSave;
      expect(store.data.keys.toSet(), {'daily_state_2026-11-15', practiceSlot});

      a.practice.enter();
      advance(const Duration(seconds: 33));
      solveAll(a.practice.controller!);
      a.practice.leave();
      a.daily.enter();
      advance(const Duration(seconds: 80));
      a.daily.controller!.revealLetter();
      solveAll(a.daily.controller!);
      a.daily.leave();
      await a.stats.pendingSave;

      final s = a.stats.stats;
      expect(s.totalSolved, 2);
      expect(s.dailySolved, 1);
      expect(s.currentStreak, 1);
      expect(s.noHintWins, 1);
      expect(s.bestTime(7), const Duration(seconds: 33));
      expect(s.bestTime(9), isNull); // daily was solved with a helper
      expect(store.data.containsKey(statsSlot), isTrue);
      await a.daily.pendingSave;
      await a.practice.pendingSave;
      a.dispose();

      // Next launch, same day: everything is still there.
      final b = app(store);
      await b.init();
      expect(b.daily.isSolved, isTrue);
      expect(b.daily.elapsed.value, const Duration(seconds: 80));
      expect(b.practice.isSolved, isTrue);
      expect(b.stats.stats.totalSolved, 2);
      b.dispose();
    });

    test('a new day opens a new daily puzzle and keeps the old state', () async {
      final store = MemoryStore();
      final a = app(store);
      await a.init();
      await a.daily.ensureStarted();
      a.daily.controller!.input('ب');
      await a.daily.pendingSave;
      final first = a.daily;

      await a.refreshDaily(); // same day: nothing changes
      expect(a.daily, same(first));

      advance(const Duration(days: 1));
      var notified = 0;
      a.addListener(() => notified++);
      await a.refreshDaily();
      expect(notified, 1);
      expect(a.daily, isNot(same(first)));
      expect(a.daily.date, '2026-11-16');
      expect(a.daily.controller, isNull);
      expect(first.isDisposed, isTrue);
      expect(store.data.containsKey('daily_state_2026-11-15'), isTrue);
      a.dispose();
    });

    test('daily states older than a week are removed at start-up', () async {
      final store = MemoryStore();
      store.data['daily_state_2026-11-01'] = '{}';
      store.data['daily_state_2026-11-08'] = '{}';
      store.data['daily_state_2026-11-14'] = '{}';
      store.data['daily_state_garbage'] = '{}';
      store.data[practiceSlot] = 'damaged';
      final a = app(store);
      await a.init();
      expect(store.data.keys.toSet(), {
        'daily_state_2026-11-08',
        'daily_state_2026-11-14',
        practiceSlot,
      });
      expect(a.practice.controller, isNull);
      a.dispose();
    });
  });
}
