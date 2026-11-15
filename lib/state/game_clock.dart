/// Stopwatch on an injectable time source, so play time can be saved,
/// restored and tested.
class GameClock {
  GameClock(this._now);

  final DateTime Function() _now;
  Duration _accumulated = Duration.zero;
  DateTime? _since;

  bool get isRunning => _since != null;

  Duration get elapsed => _since == null
      ? _accumulated
      : _accumulated + _now().difference(_since!);

  void start() => _since ??= _now();

  void pause() {
    if (_since == null) return;
    _accumulated = elapsed;
    _since = null;
  }

  /// Stops the clock and sets the elapsed time (zero for a new puzzle).
  void reset([Duration elapsed = Duration.zero]) {
    _accumulated = elapsed;
    _since = null;
  }
}
