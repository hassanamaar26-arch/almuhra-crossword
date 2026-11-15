import 'package:flutter/foundation.dart';

import '../../models/puzzle.dart' show Direction, Pos;
import '../arabic/normalize.dart';
import 'seed_rng.dart';
import 'word_bank.dart';

// Free-form crossword generator. Port of core-ts/src/generator.ts: for the
// same (bank, size, seed, exclude) both must return the same puzzle. The
// shared file test/fixtures/generator_fixtures.json enforces that.

const List<int> supportedSizes = [7, 9, 11];

const Map<int, int> _targetWords = {7: 8, 9: 12, 11: 16};
// ceil(size × 0.55): minimum length of the first (seed) word.
const Map<int, int> _minFirstLength = {7: 4, 9: 5, 11: 7};
const int _maxPasses = 4;
const int _attempts = 40;

class GeneratorError implements Exception {
  const GeneratorError(this.message);
  final String message;

  @override
  String toString() => 'GeneratorError: $message';
}

class GeneratedPuzzle {
  const GeneratedPuzzle({required this.json, required this.wordIds});

  /// Puzzle JSON v1, full form (feed to `Puzzle.fromJson`).
  final Map<String, dynamic> json;

  /// Bank ids of the placed words (to avoid repeats in the next puzzles).
  final List<int> wordIds;
}

/// Best of [_attempts] deterministic sub-seeds: most words, then most cells.
GeneratedPuzzle generatePuzzle(
  List<BankEntry> bank, {
  required int size,
  required String seed,
  Set<int> exclude = const {},
}) {
  final target = _targetWords[size];
  if (target == null) throw GeneratorError('unsupported size $size');
  if (bank.isEmpty) throw const GeneratorError('empty bank');
  for (final e in bank) {
    if (!isValidAnswer(e.answer)) {
      throw GeneratorError('invalid answer id=${e.id}: ${e.answer}');
    }
  }
  final sorted = [
    for (final e in bank)
      if (!exclude.contains(e.id)) e,
  ]..sort((a, b) => a.id.compareTo(b.id));
  final candidates = [
    for (final e in sorted) _Cand(e),
  ].where((c) => c.letters.length <= size).toList();
  if (candidates.isEmpty) throw const GeneratorError('no usable words');

  _Board? best;
  var bestScore = -1;
  for (var k = 0; k < _attempts; k++) {
    final board = _attempt(List.of(candidates), size, target, '$seed#$k');
    final score = board.placed.length * 1000 + board.filled;
    if (score > bestScore) {
      best = board;
      bestScore = score;
    }
    if (board.placed.length >= target) break;
  }
  return _toResult(best!, seed);
}

typedef PuzzleGenerator = Future<GeneratedPuzzle> Function(
  List<BankEntry> bank,
  int size,
  String seed,
  Set<int> exclude,
);

/// Runs [generatePuzzle] off the UI thread (a background isolate on phones).
Future<GeneratedPuzzle> generateInBackground(
  List<BankEntry> bank,
  int size,
  String seed,
  Set<int> exclude,
) async {
  final out = await compute(_generateMessage, <String, dynamic>{
    'bank': [for (final e in bank) e.toJson()],
    'size': size,
    'seed': seed,
    'exclude': exclude.toList(),
  });
  return GeneratedPuzzle(
    json: (out['json'] as Map).cast<String, dynamic>(),
    wordIds: (out['ids'] as List).cast<int>(),
  );
}

Map<String, dynamic> _generateMessage(Map<String, dynamic> m) {
  final g = generatePuzzle(
    [
      for (final e in m['bank'] as List)
        BankEntry.fromJson((e as Map).cast<String, dynamic>()),
    ],
    size: m['size'] as int,
    seed: m['seed'] as String,
    exclude: (m['exclude'] as List).cast<int>().toSet(),
  );
  return {'json': g.json, 'ids': g.wordIds};
}

// ------------------------------------------------------------------ internals

class _Cand {
  _Cand(this.entry) : letters = toLetters(normalizeArabic(entry.answer));
  final BankEntry entry;
  final List<String> letters;
  late final String answer = letters.join();
}

class _Placed {
  _Placed(this.cand, this.row, this.col, this.dir);
  final _Cand cand;
  final int row;
  final int col;
  final Direction dir;
  int number = 0;
}

class _Board {
  _Board(this.size)
      : grid = List.generate(size, (_) => List<String?>.filled(size, null)),
        _usedAcross = List.generate(size, (_) => List<bool>.filled(size, false)),
        _usedDown = List.generate(size, (_) => List<bool>.filled(size, false));

  final int size;
  final List<List<String?>> grid;
  final List<List<bool>> _usedAcross;
  final List<List<bool>> _usedDown;
  final Map<String, List<Pos>> byLetter = {};
  final List<_Placed> placed = [];
  final Set<String> usedAnswers = {};
  int filled = 0;

  bool _empty(int r, int c) =>
      r < 0 || r >= size || c < 0 || c >= size || grid[r][c] == null;

  /// Number of crossings, or -1 when the placement is illegal.
  int check(List<String> letters, int r0, int c0, Direction dir) {
    final dr = dir == Direction.across ? 0 : 1;
    final dc = dir == Direction.across ? 1 : 0;
    final len = letters.length;
    final rEnd = r0 + dr * (len - 1);
    final cEnd = c0 + dc * (len - 1);
    if (r0 < 0 || c0 < 0 || rEnd >= size || cEnd >= size) return -1;
    if (!_empty(r0 - dr, c0 - dc) || !_empty(rEnd + dr, cEnd + dc)) return -1;
    final used = dir == Direction.across ? _usedAcross : _usedDown;
    var crossings = 0;
    for (var k = 0; k < len; k++) {
      final r = r0 + dr * k;
      final c = c0 + dc * k;
      final cur = grid[r][c];
      if (cur != null) {
        if (cur != letters[k]) return -1;
        if (used[r][c]) return -1;
        crossings++;
      } else if (!_empty(r + dc, c + dr) || !_empty(r - dc, c - dr)) {
        return -1; // would touch a parallel neighbour → stray 2-letter word
      }
    }
    return crossings;
  }

  void put(_Cand cand, int r0, int c0, Direction dir) {
    final dr = dir == Direction.across ? 0 : 1;
    final dc = dir == Direction.across ? 1 : 0;
    final used = dir == Direction.across ? _usedAcross : _usedDown;
    for (var k = 0; k < cand.letters.length; k++) {
      final r = r0 + dr * k;
      final c = c0 + dc * k;
      if (grid[r][c] == null) {
        final ch = cand.letters[k];
        grid[r][c] = ch;
        filled++;
        (byLetter[ch] ??= []).add(Pos(r, c));
      }
      used[r][c] = true;
    }
    usedAnswers.add(cand.answer);
    placed.add(_Placed(cand, r0, c0, dir));
  }
}

_Board _attempt(List<_Cand> pool, int size, int target, String subSeed) {
  SeedRng(subSeed).shuffle(pool);
  final board = _Board(size);

  // Seed word: first long-enough word in shuffled order, else the longest.
  final minFirst = _minFirstLength[size]!;
  _Cand? first;
  for (final c in pool) {
    if (c.letters.length >= minFirst) {
      first = c;
      break;
    }
  }
  first ??= pool.reduce((a, b) => b.letters.length > a.letters.length ? b : a);
  board.put(
    first,
    size ~/ 2,
    (size - first.letters.length) ~/ 2,
    Direction.across,
  );

  for (var pass = 0; pass < _maxPasses && board.placed.length < target; pass++) {
    var progress = false;
    for (final cand in pool) {
      if (board.placed.length >= target) break;
      if (board.usedAnswers.contains(cand.answer)) continue;
      var best = 0;
      var bestRow = 0;
      var bestCol = 0;
      var bestDir = Direction.across;
      for (var k = 0; k < cand.letters.length; k++) {
        final spots = board.byLetter[cand.letters[k]];
        if (spots == null) continue;
        for (final p in spots) {
          for (final dir in Direction.values) {
            final r0 = dir == Direction.down ? p.row - k : p.row;
            final c0 = dir == Direction.across ? p.col - k : p.col;
            final x = board.check(cand.letters, r0, c0, dir);
            if (x > best) {
              best = x;
              bestRow = r0;
              bestCol = c0;
              bestDir = dir;
            }
          }
        }
      }
      if (best > 0) {
        board.put(cand, bestRow, bestCol, bestDir);
        progress = true;
      }
    }
    if (!progress) break;
  }
  return board;
}

GeneratedPuzzle _toResult(_Board board, String seed) {
  final size = board.size;
  // Number word starts in reading order.
  final starts = {for (final w in board.placed) w.row * size + w.col}.toList()
    ..sort();
  for (final w in board.placed) {
    w.number = starts.indexOf(w.row * size + w.col) + 1;
  }
  final acrossFirst = List.of(board.placed)
    ..sort((a, b) => a.dir == b.dir
        ? a.number.compareTo(b.number)
        : a.dir.index.compareTo(b.dir.index));

  return GeneratedPuzzle(
    json: {
      'version': 1,
      'id': 'practice-$size-$seed',
      'size': size,
      'direction': 'rtl',
      'grid': [
        for (final row in board.grid) row.map((ch) => ch ?? '#').join(),
      ],
      'numbers': [
        for (final key in starts) [key ~/ size, key % size, starts.indexOf(key) + 1],
      ],
      'entries': [
        for (final w in acrossFirst)
          {
            'number': w.number,
            'dir': w.dir.name,
            'row': w.row,
            'col': w.col,
            'length': w.cand.letters.length,
            'clue': w.cand.entry.clue,
            'answer': w.cand.answer,
            'display': w.cand.entry.display,
          },
      ],
    },
    wordIds: [for (final w in board.placed) w.cand.entry.id],
  );
}
