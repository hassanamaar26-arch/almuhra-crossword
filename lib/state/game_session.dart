import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/puzzle.dart';
import '../storage/game_storage.dart';
import 'crossword_controller.dart';
import 'game_clock.dart';

class SolvedInfo {
  const SolvedInfo({
    required this.size,
    required this.elapsed,
    required this.helpersUsed,
  });
  final int size;
  final Duration elapsed;
  final int helpersUsed;
}

/// One game in progress: its controller, play clock and auto-save.
///
/// The clock runs only while the play screen is open ([enter] / [leave]),
/// the app is in the foreground ([resume] / [pause]) and the puzzle is not
/// solved yet.
abstract class GameSession extends ChangeNotifier {
  GameSession({
    required this.storage,
    DateTime Function()? now,
    this.autoTick = true,
    this.onSolved,
  }) : now = now ?? DateTime.now;

  static const int saveVersion = 1;

  final GameStorage storage;
  final DateTime Function() now;

  /// False in unit tests: call [tick] by hand instead of a real timer.
  final bool autoTick;

  /// Called once, at the moment the puzzle becomes solved.
  final void Function(SolvedInfo info)? onSolved;

  late final GameClock _clock = GameClock(now);

  /// Play time, refreshed every second while the clock runs.
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  CrosswordController? _controller;
  Timer? _ticker;
  int _ticks = 0;
  bool _visible = false;
  bool _appActive = true;
  bool _solvedReported = false;
  bool _disposed = false;
  Future<void> _pendingSave = Future.value();

  /// Set when a save failed; the game keeps running.
  Object? lastSaveError;

  CrosswordController? get controller => _controller;
  bool get isClockRunning => _clock.isRunning;
  bool get isDisposed => _disposed;
  bool get isSolved => _controller?.state.solved ?? false;

  /// True when the player has typed at least one letter.
  bool get hasProgress =>
      _controller?.state.cells.values.any((c) => !c.isEmpty) ?? false;

  /// Completes when every save requested so far has been written.
  Future<void> get pendingSave => _pendingSave;

  /// The play screen opened.
  void enter() {
    _visible = true;
    if (autoTick) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
    _syncClock();
  }

  /// The play screen closed.
  void leave() {
    _visible = false;
    _syncClock();
    save();
  }

  /// App went to the background: stop the clock and save.
  void pause() {
    _appActive = false;
    _syncClock();
    save();
  }

  /// App is in the foreground again.
  void resume() {
    _appActive = true;
    _syncClock();
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
      'elapsedMs': _clock.elapsed.inMilliseconds,
      ...extraJson(),
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

  // ---------------------------------------------------------- for subclasses

  /// Extra fields a subclass keeps in the save file.
  @protected
  Map<String, dynamic> extraJson();

  /// Make [next] the current game, with the clock at [startAt].
  @protected
  void attach(CrosswordController next, {Duration startAt = Duration.zero}) {
    _controller?.removeListener(_onPlay);
    _controller = next..addListener(_onPlay);
    _solvedReported = next.state.solved;
    _clock.reset(startAt);
    _syncClock();
  }

  /// Rebuild the game from a save. [readExtra] checks and applies the
  /// subclass fields; returning false rejects the save.
  @protected
  bool tryRestore(
    String raw, {
    required bool Function(Map<String, dynamic> save) readExtra,
  }) {
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
      if (!readExtra(j)) return false;
      attach(next, startAt: Duration(milliseconds: ms));
      return true;
    } catch (_) {
      // Damaged or outdated save: the caller starts fresh instead of crashing.
      return false;
    }
  }

  // -------------------------------------------------------------- internals

  void _syncClock() {
    final c = _controller;
    if (_visible && _appActive && c != null && !c.state.solved) {
      _clock.start();
    } else {
      _clock.pause();
    }
    elapsed.value = _clock.elapsed;
  }

  void _onPlay() {
    final c = _controller!;
    if (c.state.solved && !_solvedReported) {
      _solvedReported = true;
      _syncClock();
      onSolved?.call(SolvedInfo(
        size: c.puzzle.size,
        elapsed: _clock.elapsed,
        helpersUsed: c.state.helpersUsed,
      ));
    }
    save();
  }
}
