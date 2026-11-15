import 'dart:math' as math;

import '../core/generator/generator.dart';
import '../core/generator/word_bank.dart';
import '../models/puzzle.dart';
import 'crossword_controller.dart';
import 'game_session.dart';

/// Offline practice mode: endless generated puzzles, one open at a time.
/// Notifies when the puzzle (controller) changes.
class PracticeSession extends GameSession {
  PracticeSession({
    required this.bank,
    required super.storage,
    PuzzleGenerator? generator,
    super.now,
    math.Random? random,
    super.autoTick,
    super.onSolved,
  })  : _generate = generator ?? generateInBackground,
        _random = random ?? math.Random();

  static const int _recentPuzzles = 5;

  final List<BankEntry> bank;
  final PuzzleGenerator _generate;
  final math.Random _random;

  int _size = supportedSizes.first;
  String _seed = '';
  List<int> _wordIds = const [];
  List<List<int>> _recent = const []; // newest first
  int _token = 0;

  int get size => _size;
  String get seed => _seed;

  /// Open the play screen on the saved game, or on a first puzzle.
  Future<void> start() async {
    enter();
    if (!await restore()) await newPuzzle();
  }

  /// Load the saved game if there is a valid one.
  Future<bool> restore() async {
    final raw = await storage.read();
    if (isDisposed || raw == null) return false;
    final ok = tryRestore(raw, readExtra: (j) {
      final size = j['size'] as int;
      final seed = j['seed'] as String;
      final wordIds = (j['wordIds'] as List).cast<int>().toList();
      final recent = [
        for (final ids in j['recent'] as List) (ids as List).cast<int>().toList(),
      ];
      _size = size;
      _seed = seed;
      _wordIds = wordIds;
      _recent = recent;
      return true;
    });
    if (ok) notifyListeners();
    return ok;
  }

  /// Drop the current puzzle and generate a new one.
  Future<void> newPuzzle({int? size, String? seed}) async {
    final token = ++_token;
    final nextSize = size ?? _size;
    final nextSeed =
        seed ?? '${now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
    final recent = [
      if (_wordIds.isNotEmpty) _wordIds,
      ..._recent,
    ].take(_recentPuzzles).toList();

    GeneratedPuzzle generated;
    try {
      generated = await _generate(bank, nextSize, nextSeed, _excluded(recent));
    } on GeneratorError {
      // Too few words left after exclusions: allow repeats rather than fail.
      generated = await _generate(bank, nextSize, nextSeed, const {});
    }
    if (isDisposed || token != _token) return;

    _recent = recent;
    _wordIds = generated.wordIds;
    _size = nextSize;
    _seed = nextSeed;
    attach(CrosswordController(Puzzle.fromJson(generated.json)));
    save();
    notifyListeners();
  }

  @override
  Map<String, dynamic> extraJson() => {
        'size': _size,
        'seed': _seed,
        'wordIds': _wordIds,
        'recent': _recent,
      };

  /// Words of the most recent puzzles, capped at 40% of the bank so the
  /// generator always keeps enough words to build a good grid.
  Set<int> _excluded(List<List<int>> recent) {
    final limit = (bank.length * 0.4).floor();
    final out = <int>{};
    for (final ids in recent) {
      if (out.length + ids.length > limit) break;
      out.addAll(ids);
    }
    return out;
  }
}
