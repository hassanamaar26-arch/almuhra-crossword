import 'dart:convert';
import 'dart:io';

import 'package:almuhra_crossword/core/generator/conflicts.dart';
import 'package:almuhra_crossword/core/generator/generator.dart';
import 'package:almuhra_crossword/core/generator/seed_rng.dart';
import 'package:almuhra_crossword/core/generator/word_bank.dart';
import 'package:almuhra_crossword/models/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final bank = loadTestBank();
  final fixtures = jsonDecode(
    File('test/fixtures/generator_fixtures.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group('matches the TypeScript core (shared fixtures)', () {
    for (final f in fixtures['rng'] as List) {
      test('rng sequence for seed "${f['seed']}"', () {
        final rng = SeedRng(f['seed'] as String);
        expect([for (var i = 0; i < 6; i++) rng.next()], f['values']);
      });
    }
    for (final f in fixtures['cases'] as List) {
      test('puzzle ${f['size']}×${f['size']} seed "${f['seed']}"', () {
        final g = generatePuzzle(
          bank,
          size: f['size'] as int,
          seed: f['seed'] as String,
          exclude: (f['exclude'] as List).cast<int>().toSet(),
        );
        expect(g.json, f['json']);
      });
    }
  });

  test('bank file loads with unique ids', () {
    expect(bank.length, greaterThanOrEqualTo(500));
    expect(bank.map((e) => e.id).toSet().length, bank.length);
  });

  test('same seed → same puzzle; bank order does not matter', () {
    final a = generatePuzzle(bank, size: 9, seed: 's1');
    final b = generatePuzzle(bank.reversed.toList(), size: 9, seed: 's1');
    expect(a.json, b.json);
    expect(a.wordIds, b.wordIds);
  });

  test('different seeds give different puzzles', () {
    final seen = <String>{};
    for (var i = 0; i < 40; i++) {
      seen.add(jsonEncode(generatePuzzle(bank, size: 7, seed: 'd$i').json['grid']));
    }
    expect(seen.length, greaterThanOrEqualTo(36));
  });

  for (final size in supportedSizes) {
    test('property: 150 seeds at $size×$size are valid, full puzzles', () {
      const minWords = {7: 5, 9: 7, 11: 9};
      for (var i = 0; i < 150; i++) {
        final g = generatePuzzle(bank, size: size, seed: 'p-$size-$i');
        // fromJson re-checks bounds, black cells, numbers and every crossing.
        final p = Puzzle.fromJson(g.json);
        expect(p.size, size);
        expect(p.hasSolution, isTrue);
        expect(p.entries.length, greaterThanOrEqualTo(minWords[size]!));
        expect(g.wordIds.toSet().length, g.wordIds.length);
        // No clue names another answer of the same puzzle.
        for (final a in p.entries) {
          for (final b in p.entries) {
            if (!identical(a, b)) {
              expect(clueLeaksAnswer(a.clue, b.answer!), isFalse,
                  reason: 'seed $i: «${a.clue}» names «${b.answer}»');
            }
          }
        }
        // Every white cell belongs to a word, and no stray runs exist:
        // the cells covered by entries are exactly the white cells.
        expect({for (final e in p.entries) ...e.cells}, p.whiteCells.toSet());
        expect(_runs(p), {
          for (final e in p.entries) '${e.dir.name}:${e.row}:${e.col}:${e.length}',
        });
      }
    });
  }

  test('excluded words never appear', () {
    final exclude = {for (final e in bank.take(45)) e.id};
    for (var i = 0; i < 40; i++) {
      final g = generatePuzzle(bank, size: 9, seed: 'x$i', exclude: exclude);
      expect(g.wordIds.toSet().intersection(exclude), isEmpty);
    }
  });

  test('wordIds match the placed answers', () {
    final g = generatePuzzle(bank, size: 7, seed: '7b');
    final byId = {for (final e in bank) e.id: e};
    final displays = {for (final e in g.json['entries'] as List) (e as Map)['display']};
    expect({for (final id in g.wordIds) byId[id]!.display}, displays);
  });

  test('invalid input fails loudly', () {
    expect(() => generatePuzzle(const [], size: 9, seed: 'x'),
        throwsA(isA<GeneratorError>()));
    expect(() => generatePuzzle(bank, size: 8, seed: 'x'),
        throwsA(isA<GeneratorError>()));
    expect(
      () => generatePuzzle(bank, size: 7, seed: 'x', exclude: {for (final e in bank) e.id}),
      throwsA(isA<GeneratorError>()),
    );
    const bad = BankEntry(
        id: 1, answer: 'H2O', display: 'H2O', clue: 'x', category: 'x', difficulty: 1);
    expect(() => generatePuzzle(const [bad], size: 7, seed: 'x'),
        throwsA(isA<GeneratorError>()));
  });

  test('performance: 11×11 averages under 100 ms', () {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 30; i++) {
      generatePuzzle(bank, size: 11, seed: 'perf$i');
    }
    final avg = sw.elapsedMilliseconds / 30;
    // ignore: avoid_print
    print('avg 11×11: ${avg.toStringAsFixed(2)} ms');
    expect(avg, lessThan(100));
  });

  testWidgets('background (isolate) generation returns the same puzzle',
      (tester) async {
    final direct = generatePuzzle(bank, size: 7, seed: 'iso', exclude: {1, 2});
    final bg = await tester.runAsync(
      () => generateInBackground(bank, 7, 'iso', {1, 2}),
    );
    expect(bg!.json, direct.json);
    expect(bg.wordIds, direct.wordIds);
  });

  testWidgets('bundled asset loads the word bank', (tester) async {
    final loaded = await tester.runAsync(loadWordBank);
    expect(loaded!.length, bank.length);
    expect(loaded.first.answer, bank.first.answer);
  });
}

/// All maximal runs (length ≥ 2) of white cells, both directions.
Set<String> _runs(Puzzle p) {
  final out = <String>{};
  for (final dir in Direction.values) {
    for (var a = 0; a < p.size; a++) {
      var start = -1;
      for (var b = 0; b <= p.size; b++) {
        final pos = dir == Direction.across ? Pos(a, b) : Pos(b, a);
        final white = b < p.size && p.isWhite(pos);
        if (white && start < 0) start = b;
        if (!white && start >= 0) {
          if (b - start >= 2) {
            out.add(dir == Direction.across
                ? 'across:$a:$start:${b - start}'
                : 'down:$start:$a:${b - start}');
          }
          start = -1;
        }
      }
    }
  }
  return out;
}
