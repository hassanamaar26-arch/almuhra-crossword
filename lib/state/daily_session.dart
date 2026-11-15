import '../core/generator/generator.dart';
import '../core/generator/word_bank.dart';
import '../models/puzzle.dart';
import 'crossword_controller.dart';
import 'game_session.dart';

/// The puzzle of one calendar day. Everyone with the same app version gets
/// the same grid: it is generated on the device from the date alone.
class DailySession extends GameSession {
  DailySession({
    required this.bank,
    required this.date,
    required super.storage,
    PuzzleGenerator? generator,
    super.now,
    super.autoTick,
    super.onSolved,
  }) : _generate = generator ?? generateInBackground;

  static const int gridSize = 9;

  static String seedFor(String date) => 'daily-$date';
  static String puzzleIdFor(String date) => 'daily-$date';

  final List<BankEntry> bank;

  /// 'YYYY-MM-DD'.
  final String date;
  final PuzzleGenerator _generate;
  Future<void>? _starting;

  /// Load today's saved state if the player already opened the puzzle.
  Future<bool> restore() async {
    final raw = await storage.read();
    if (isDisposed || raw == null) return false;
    final ok = tryRestore(raw, readExtra: (j) => j['date'] == date);
    if (ok) notifyListeners();
    return ok;
  }

  /// Generate the day's puzzle unless it is already loaded.
  Future<void> ensureStarted() {
    if (controller != null) return Future.value();
    return _starting ??=
        _generateToday().whenComplete(() => _starting = null);
  }

  Future<void> _generateToday() async {
    // No exclusions: the grid must depend on the date only.
    final g = await _generate(bank, gridSize, seedFor(date), const {});
    if (isDisposed) return;
    final json = Map<String, dynamic>.of(g.json)..['id'] = puzzleIdFor(date);
    attach(CrosswordController(Puzzle.fromJson(json)));
    save();
    notifyListeners();
  }

  @override
  Map<String, dynamic> extraJson() => {'date': date};
}
