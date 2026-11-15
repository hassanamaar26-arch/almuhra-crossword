import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/generator/generator.dart';
import '../core/generator/word_bank.dart';
import '../models/puzzle.dart';
import '../storage/game_storage.dart';
import 'crossword_controller.dart';
import 'game_clock.dart';

/// Offline practice mode: owns the current puzzle, its clock and the
/// auto-save. Notifies when the puzzle (controller) changes.
class PracticeSession extends ChangeNotifier {
  PracticeSession({
    required this.bank,
    required this.storage,
    PuzzleGenerator? generator,
    DateTime Function()? now,
    math.Random? random,
    this.autoTick = true,
  })  : _generate = generator ?? generateInBackground,
        _now = now ?? DateTime.now,
        _random = random ?? math.Random();

  static const int saveVersion = 1;
  static const int _recentPuzzles = 5;

  final List<BankEntry> bank;
  final GameStorage storage;

  /// False in unit tests: call [tick] by hand instead of a real timer.
  final bool autoTick;

  final PuzzleGenerator _generate;
  final DateTime Function() _now;
  final math.Random _random;
  late final GameClock _clock = GameClock(_now);

  /// Play time, refreshed every second while the clock runs.
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  CrosswordController? _controller;
  int _size = supportedSizes.first;
  String _seed = '';
  List<int> _wordIds = const [];
  List<List<int>> _recent = const []; // newest first
  Timer? _ticker;
  int _ticks = 0;
  int _token = 0;
  bool _paused = false;
  bool _disposed = false;
  Future<void> _pendingSave = Future.value();

  /// Set when a save failed; the game keeps running.
  Object? lastSaveError;

  CrosswordController? get controller => _controller;
  int get size => _size;
  String get seed => _seed;
  bool get isClockRunning => _clock.isRunning;

  /// Completes when every save requested so far has been written.
  Future<void> get pendingSave => _pendingSave;

  /// Resume the saved game, or start a first puzzle.
  Future<void> start() async {
    final raw = await storage.read();
    if (_disposed) return;
    _startTicker();
    if (raw != null && _tryRestore(raw)) {
      notifyListeners();
      return;
    }
    await newPuzzle();
  }

  /// Drop the current puzzle and generate a new one.
  Future<void> newPuzzle({int? size, String? seed}) async {
    final token = ++_token;
    final nextSize = size ?? _size;
    final nextSeed = seed ??
        '${_now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
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
    if (_disposed || token != _token) return;

    final next = CrosswordController(Puzzle.fromJson(generated.json));
    _controller?.removeListener(_onPlay);
    _controller = next..addListener(_onPlay);
    _recent = recent;
    _wordIds = generated.wordIds;
    _size = nextSize;
    _seed = nextSeed;
    _clock.reset();
    if (!_paused) _clock.start();
    elapsed.value = Duration.zero;
    save();
    notifyListeners();
  }

  /// App went to the background: stop the clock and save.
  void pause() {
    _paused = true;
    _clock.pause();
    elapsed.value = _clock.elapsed;
    save();
  }

  /// App is visible again.
  void resume() {
    _paused = false;
    final c = _controller;
    if (c != null && !c.state.solved) _clock.start();
  }

  /// One second passed (called by the internal timer).
  void tick() {
    elapsed.value = _clock.elapsed;
    if (_clock.isRunning && ++_ticks % 5 == 0) save();
  }

  /// Queue a save of the whole game. Saves are written in order.
  void save() {
    final c = _controller;
    if (c == null) return;
    final data = jsonEncode({
      'v': saveVersion,
      'size': _size,
      'seed': _seed,
      'elapsedMs': _clock.elapsed.inMilliseconds,
      'wordIds': _wordIds,
      'recent': _recent,
      'puzzle': c.puzzle.toJson(),
      'play': c.toJson(),
    });
    _pendingSave = _pendingSave.then((_) => storage.write(data)).then(
      (_) => lastSaveError = null,
      onError: (Object e) => lastSaveError = e,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _controller?.removeListener(_onPlay);
    _controller?.dispose();
    elapsed.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- internals

  void _onPlay() {
    if (_controller!.state.solved && _clock.isRunning) {
      _clock.pause();
      elapsed.value = _clock.elapsed;
    }
    save();
  }

  void _startTicker() {
    if (!autoTick) return;
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

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

  bool _tryRestore(String raw) {
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (j['v'] != saveVersion) return false;
      final puzzle =
          Puzzle.fromJson((j['puzzle'] as Map).cast<String, dynamic>());
      final next = CrosswordController(
        puzzle,
        saved: (j['play'] as Map).cast<String, dynamic>(),
      );
      final ms = j['elapsedMs'] as int;
      if (ms < 0) return false;
      final size = j['size'] as int;
      final seed = j['seed'] as String;
      final wordIds = (j['wordIds'] as List).cast<int>().toList();
      final recent = [
        for (final ids in j['recent'] as List) (ids as List).cast<int>().toList(),
      ];

      _controller = next..addListener(_onPlay);
      _size = size;
      _seed = seed;
      _wordIds = wordIds;
      _recent = recent;
      _clock.reset(Duration(milliseconds: ms));
      if (!next.state.solved && !_paused) _clock.start();
      elapsed.value = _clock.elapsed;
      return true;
    } catch (_) {
      // Damaged or outdated save: start a fresh puzzle instead of crashing.
      return false;
    }
  }
}
