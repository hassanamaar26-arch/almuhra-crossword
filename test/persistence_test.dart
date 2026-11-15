import 'dart:convert';

import 'package:almuhra_crossword/core/format.dart';
import 'package:almuhra_crossword/models/puzzle.dart';
import 'package:almuhra_crossword/sample_puzzle.dart';
import 'package:almuhra_crossword/state/crossword_controller.dart';
import 'package:almuhra_crossword/state/game_clock.dart';
import 'package:almuhra_crossword/state/practice_session.dart';
import 'package:almuhra_crossword/storage/game_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Map<String, dynamic> sampleJson() =>
    jsonDecode(samplePuzzleJson) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bank = loadTestBank();
  var t = DateTime.utc(2026, 11, 15, 1);
  DateTime now() => t;
  void advance(Duration d) => t = t.add(d);

  PracticeSession newSession(GameStorage storage) => PracticeSession(
        bank: bank,
        storage: storage,
        generator: syncGenerator,
        now: now,
        autoTick: false,
      );

  setUp(() => t = DateTime.utc(2026, 11, 15, 1));

  test('formatDuration', () {
    expect(formatDuration(Duration.zero), '00:00');
    expect(formatDuration(const Duration(seconds: 125)), '02:05');
    expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    expect(formatDuration(const Duration(hours: 1, seconds: 5)), '1:00:05');
    expect(formatDuration(const Duration(seconds: -3)), '00:00');
  });

  group('GameClock', () {
    test('counts only while running', () {
      final clock = GameClock(now);
      expect(clock.elapsed, Duration.zero);
      advance(const Duration(seconds: 10));
      expect(clock.elapsed, Duration.zero);
      clock.start();
      advance(const Duration(seconds: 7));
      expect(clock.elapsed, const Duration(seconds: 7));
      clock.pause();
      advance(const Duration(seconds: 100));
      expect(clock.elapsed, const Duration(seconds: 7));
      clock.start();
      clock.start(); // idempotent
      advance(const Duration(seconds: 3));
      expect(clock.elapsed, const Duration(seconds: 10));
      expect(clock.isRunning, isTrue);
    });
    test('reset stops and sets the elapsed time', () {
      final clock = GameClock(now)..start();
      advance(const Duration(seconds: 5));
      clock.reset(const Duration(seconds: 90));
      expect(clock.isRunning, isFalse);
      expect(clock.elapsed, const Duration(seconds: 90));
    });
  });

  group('serialization', () {
    test('Puzzle.toJson round-trips the full form', () {
      final p = Puzzle.fromJson(sampleJson());
      final again = Puzzle.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(again.toJson(), p.toJson());
      expect(again.solution, p.solution);
      expect(again.numbers, p.numbers);
      expect(again.entries.map((e) => e.display), p.entries.map((e) => e.display));
      expect(p.toJson()['grid'], sampleJson()['grid']);
    });

    test('Puzzle.toJson of the client form has no letters', () {
      final j = sampleJson();
      j['grid'] = [
        for (final row in j['grid'] as List)
          (row as String).runes.map((r) => r == 0x23 ? '#' : '.').join(),
      ];
      for (final e in j['entries'] as List) {
        (e as Map)
          ..remove('answer')
          ..remove('display');
      }
      final out = Puzzle.fromJson(j).toJson();
      expect(out['grid'], j['grid']);
      expect((out['entries'] as List).every((e) => !(e as Map).containsKey('answer')), isTrue);
    });

    test('controller state round-trips: cells, statuses, cursor, dir, helpers', () {
      final c = CrosswordController(Puzzle.fromJson(sampleJson()));
      c..input('ز')..input('ر');
      c.checkWord(); // (1,4) wrong, (1,5) correct
      c.selectCell(const Pos(0, 6));
      c.revealLetter();
      c.selectCell(const Pos(3, 5));
      c.input('ل');
      c.selectCell(const Pos(2, 2));

      final saved = jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>;
      final r = CrosswordController(Puzzle.fromJson(sampleJson()), saved: saved);

      expect(r.state.cells, c.state.cells);
      expect(r.state.cells[const Pos(1, 4)]!.status, CellStatus.wrong);
      expect(r.state.cells[const Pos(1, 5)]!.status, CellStatus.correct);
      expect(r.state.cells[const Pos(0, 6)]!.status, CellStatus.revealed);
      expect(r.state.cursor, c.state.cursor);
      expect(r.state.dir, c.state.dir);
      expect(r.state.helpersUsed, 2);
      expect(r.state.solved, isFalse);
      // Locked cells stay locked after restore.
      r.selectCell(const Pos(1, 5));
      r.input('ز');
      expect(r.state.cells[const Pos(1, 5)]!.letter, 'ر');
    });

    test('a solved game restores as solved', () {
      final c = CrosswordController(Puzzle.fromJson(sampleJson()));
      solveAll(c);
      final r = CrosswordController(
        Puzzle.fromJson(sampleJson()),
        saved: jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>,
      );
      expect(r.state.solved, isTrue);
    });

    test('damaged saves are rejected', () {
      Map<String, dynamic> base() => {
            'cells': <dynamic>[],
            'cursor': [1, 4],
            'dir': 'across',
            'helpers': 0,
          };
      CrosswordController restore(Map<String, dynamic> s) =>
          CrosswordController(Puzzle.fromJson(sampleJson()), saved: s);

      expect(restore(base()).state.cursor, const Pos(1, 4));
      expect(() => restore(base()..['cursor'] = [0, 0]), throwsFormatException);
      expect(() => restore(base()..['helpers'] = -1), throwsFormatException);
      expect(() => restore(base()..['dir'] = 'sideways'), throwsArgumentError);
      expect(
        () => restore(base()..['cells'] = [[0, 0, 'ب', 'filled']]),
        throwsFormatException,
      );
      expect(
        () => restore(base()..['cells'] = [[1, 4, 'x', 'filled']]),
        throwsFormatException,
      );
      expect(
        () => restore(base()..['cells'] = [[1, 4, 'و', 'empty']]),
        throwsFormatException,
      );
    });
  });

  group('PracticeSession', () {
    test('first launch generates a 7×7 puzzle, starts the clock and saves', () async {
      final storage = MemoryGameStorage();
      final s = newSession(storage);
      expect(s.controller, isNull);
      await s.start();
      await s.pendingSave;
      expect(s.controller!.puzzle.size, 7);
      expect(s.isClockRunning, isTrue);
      expect(storage.data, isNotNull);
      s.dispose();
    });

    test('every step is saved', () async {
      final storage = MemoryGameStorage();
      final s = newSession(storage);
      await s.start();
      await s.pendingSave;
      final before = storage.writes;
      s.controller!.input('ب');
      s.controller!.move(Move.left);
      s.controller!.backspace();
      await s.pendingSave;
      expect(storage.writes, before + 3);
      expect(s.lastSaveError, isNull);
      s.dispose();
    });

    test('close and reopen: same puzzle, letters, cursor, helpers and second', () async {
      final storage = MemoryGameStorage();
      final a = newSession(storage);
      await a.start();
      final c = a.controller!;
      final start = c.state.cursor;
      c.input('ب');
      c.revealLetter();
      c.stepEntry();
      advance(const Duration(seconds: 83));
      a.pause(); // app goes to background
      await a.pendingSave;
      final puzzleJson = c.puzzle.toJson();
      final cells = c.state.cells;
      final cursor = c.state.cursor;
      final dir = c.state.dir;
      a.dispose();

      advance(const Duration(hours: 9)); // phone was off all night
      final b = newSession(storage);
      await b.start();
      final r = b.controller!;
      expect(r.puzzle.toJson(), puzzleJson);
      expect(r.state.cells, cells);
      expect(r.state.cells[start]!.letter, 'ب');
      expect(r.state.cursor, cursor);
      expect(r.state.dir, dir);
      expect(r.state.helpersUsed, 1);
      expect(b.elapsed.value, const Duration(seconds: 83));
      expect(b.size, a.size);
      expect(b.seed, a.seed);
      // The clock continues from the same second.
      advance(const Duration(seconds: 2));
      b.tick();
      expect(b.elapsed.value, const Duration(seconds: 85));
      b.dispose();
    });

    test('periodic save keeps the time even without a clean exit', () async {
      final storage = MemoryGameStorage();
      final a = newSession(storage);
      await a.start();
      for (var i = 0; i < 5; i++) {
        advance(const Duration(seconds: 1));
        a.tick();
      }
      await a.pendingSave; // app is killed here: no pause(), no dispose()
      final b = newSession(storage);
      await b.start();
      expect(b.elapsed.value, const Duration(seconds: 5));
      b.dispose();
    });

    test('the clock stops when the puzzle is solved', () async {
      final s = newSession(MemoryGameStorage());
      await s.start();
      advance(const Duration(seconds: 42));
      solveAll(s.controller!);
      expect(s.controller!.state.solved, isTrue);
      expect(s.isClockRunning, isFalse);
      expect(s.elapsed.value, const Duration(seconds: 42));
      advance(const Duration(minutes: 10));
      s.tick();
      s.resume(); // coming back to a solved puzzle must not restart it
      advance(const Duration(minutes: 10));
      s.tick();
      expect(s.elapsed.value, const Duration(seconds: 42));
      s.dispose();
    });

    test('a solved game reopens solved with the clock stopped', () async {
      final storage = MemoryGameStorage();
      final a = newSession(storage);
      await a.start();
      advance(const Duration(seconds: 30));
      solveAll(a.controller!);
      await a.pendingSave;
      a.dispose();
      final b = newSession(storage);
      await b.start();
      expect(b.controller!.state.solved, isTrue);
      expect(b.isClockRunning, isFalse);
      expect(b.elapsed.value, const Duration(seconds: 30));
      b.dispose();
    });

    test('pause stops the clock, resume continues it', () async {
      final s = newSession(MemoryGameStorage());
      await s.start();
      advance(const Duration(seconds: 10));
      s.pause();
      advance(const Duration(seconds: 500));
      s.tick();
      expect(s.elapsed.value, const Duration(seconds: 10));
      s.resume();
      advance(const Duration(seconds: 4));
      s.tick();
      expect(s.elapsed.value, const Duration(seconds: 14));
      s.dispose();
    });

    test('newPuzzle: new grid, clock at zero, previous words not repeated', () async {
      final storage = MemoryGameStorage();
      final s = newSession(storage);
      await s.start();
      final first = s.controller!;
      final firstDisplays = {for (final e in first.puzzle.entries) e.display};
      advance(const Duration(seconds: 50));
      var notified = 0;
      s.addListener(() => notified++);

      await s.newPuzzle(size: 9);
      final second = s.controller!;
      expect(notified, 1);
      expect(second, isNot(same(first)));
      expect(second.puzzle.size, 9);
      expect(s.size, 9);
      expect(s.elapsed.value, Duration.zero);
      expect(s.isClockRunning, isTrue);
      expect(
        {for (final e in second.puzzle.entries) e.display}.intersection(firstDisplays),
        isEmpty,
      );
      // The old controller no longer triggers saves.
      await s.pendingSave;
      final writes = storage.writes;
      first.input('ب');
      await s.pendingSave;
      expect(storage.writes, writes);
      s.dispose();
    });

    test('a fixed seed always gives the same puzzle', () async {
      final a = newSession(MemoryGameStorage());
      final b = newSession(MemoryGameStorage());
      await a.newPuzzle(size: 7, seed: 'fixed');
      await b.newPuzzle(size: 7, seed: 'fixed');
      expect(a.controller!.puzzle.toJson(), b.controller!.puzzle.toJson());
      expect(a.controller!.puzzle.id, 'practice-7-fixed');
      a.dispose();
      b.dispose();
    });

    test('random seeds differ between puzzles', () async {
      final s = newSession(MemoryGameStorage());
      await s.start();
      final one = s.seed;
      await s.newPuzzle();
      expect(s.seed, isNot(one));
      s.dispose();
    });

    test('a damaged save starts a fresh puzzle instead of crashing', () async {
      for (final bad in ['not json', '{}', '{"v":99}', '{"v":1,"puzzle":{}}']) {
        final s = newSession(MemoryGameStorage(bad));
        await s.start();
        expect(s.controller, isNotNull, reason: bad);
        expect(s.elapsed.value, Duration.zero);
        s.dispose();
      }
    });

    test('a failing storage does not stop the game', () async {
      final s = newSession(_BrokenStorage());
      await s.start();
      s.controller!.input('ب');
      await s.pendingSave;
      expect(s.lastSaveError, isNotNull);
      expect(s.controller!.state.cells[s.controller!.puzzle.entries.first.start]!.letter, 'ب');
      s.dispose();
    });
  });

  test('SharedPrefsGameStorage reads back what it wrote', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SharedPrefsGameStorage();
    expect(await storage.read(), isNull);
    await storage.write('{"v":1}');
    expect(await storage.read(), '{"v":1}');
    await storage.clear();
    expect(await storage.read(), isNull);
  });
}

class _BrokenStorage implements GameStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String data) async => throw StateError('disk full');
  @override
  Future<void> clear() async {}
}
