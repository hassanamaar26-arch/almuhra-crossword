import 'package:flutter/foundation.dart';

import '../core/arabic/normalize.dart';
import '../models/puzzle.dart';

/// Arrow keys as seen on screen. In RTL, [left] moves FORWARD in reading
/// order (col + 1) and [right] moves backward (col − 1).
enum Move { up, down, left, right }

@immutable
class CrosswordState {
  const CrosswordState({
    required this.cells,
    required this.cursor,
    required this.dir,
    required this.helpersUsed,
    required this.solved,
  });

  /// Player input for every white cell.
  final Map<Pos, CellState> cells;
  final Pos cursor;
  final Direction dir;
  final int helpersUsed;
  final bool solved;

  CrosswordState copyWith({
    Map<Pos, CellState>? cells,
    Pos? cursor,
    Direction? dir,
    int? helpersUsed,
    bool? solved,
  }) =>
      CrosswordState(
        cells: cells ?? this.cells,
        cursor: cursor ?? this.cursor,
        dir: dir ?? this.dir,
        helpersUsed: helpersUsed ?? this.helpersUsed,
        solved: solved ?? this.solved,
      );
}

/// Owns the grid state, cursor and direction, and applies every play event.
class CrosswordController extends ChangeNotifier {
  CrosswordController(this.puzzle)
      : _across = _index(puzzle, Direction.across),
        _down = _index(puzzle, Direction.down) {
    final first = puzzle.entries.first;
    _state = CrosswordState(
      cells: {for (final p in puzzle.whiteCells) p: const CellState.empty()},
      cursor: first.start,
      dir: first.dir,
      helpersUsed: 0,
      solved: false,
    );
  }

  final Puzzle puzzle;

  // Fast lookup: cell → the across / down word that contains it.
  final Map<Pos, Entry> _across;
  final Map<Pos, Entry> _down;

  late CrosswordState _state;
  CrosswordState get state => _state;

  static Map<Pos, Entry> _index(Puzzle puzzle, Direction dir) => {
        for (final e in puzzle.entries)
          if (e.dir == dir)
            for (final p in e.cells) p: e,
      };

  Entry? entryAt(Pos p, Direction dir) =>
      (dir == Direction.across ? _across : _down)[p];

  /// The word the cursor is in, in the current direction.
  Entry? get currentEntry => entryAt(_state.cursor, _state.dir);

  // ---------------------------------------------------------------- events

  /// Tap: select the cell; tapping the selected cell toggles direction.
  void selectCell(Pos p) {
    if (!puzzle.isWhite(p)) return;
    var dir = _state.dir;
    if (p == _state.cursor) {
      if (entryAt(p, dir.flipped) != null) dir = dir.flipped;
    } else if (entryAt(p, dir) == null) {
      dir = dir.flipped;
    }
    _set(_state.copyWith(cursor: p, dir: dir));
  }

  /// Type a letter (normalized first), then advance the cursor.
  void input(String raw) {
    if (_state.solved) return;
    final normalized = normalizeArabic(raw);
    if (normalized.isEmpty) return;
    final letter = String.fromCharCode(normalized.runes.first);
    if (!arabicAlphabet.contains(letter)) return;

    final cur = _state.cursor;
    var cells = _state.cells;
    if (!cells[cur]!.locked) {
      cells = Map.of(cells)..[cur] = CellState(letter, CellStatus.filled);
    }
    final next = _advance(_state.copyWith(cells: cells));
    _set(next.copyWith(solved: _isSolved(next.cells)));
  }

  /// Clear the current cell; if it is already empty (or locked), step back
  /// one cell in the word and clear that one.
  void backspace() {
    if (_state.solved) return;
    final cur = _state.cursor;
    final here = _state.cells[cur]!;
    if (!here.isEmpty && !here.locked) {
      _set(_state.copyWith(
        cells: Map.of(_state.cells)..[cur] = const CellState.empty(),
      ));
      return;
    }
    final entry = currentEntry;
    if (entry == null) return;
    final i = entry.cells.indexOf(cur);
    if (i <= 0) return;
    final prev = entry.cells[i - 1];
    final cells = _state.cells[prev]!.locked
        ? _state.cells
        : (Map.of(_state.cells)..[prev] = const CellState.empty());
    _set(_state.copyWith(cells: cells, cursor: prev));
  }

  /// Arrow key: jump to the nearest white cell in that screen direction.
  void move(Move m) {
    final (dr, dc) = switch (m) {
      Move.up => (-1, 0),
      Move.down => (1, 0),
      Move.left => (0, 1),
      Move.right => (0, -1),
    };
    var p = Pos(_state.cursor.row + dr, _state.cursor.col + dc);
    while (puzzle.inBounds(p) && !puzzle.isWhite(p)) {
      p = Pos(p.row + dr, p.col + dc);
    }
    if (!puzzle.inBounds(p)) return;
    final preferred = dr == 0 ? Direction.across : Direction.down;
    final dir = entryAt(p, preferred) != null
        ? preferred
        : (entryAt(p, _state.dir) != null ? _state.dir : preferred.flipped);
    _set(_state.copyWith(cursor: p, dir: dir));
  }

  /// Jump to the next (or previous) word in clue order.
  void stepEntry({bool forward = true}) {
    final entries = puzzle.entries;
    final cur = currentEntry;
    final i = cur == null ? 0 : entries.indexOf(cur);
    final e = entries[(i + (forward ? 1 : -1) + entries.length) % entries.length];
    _set(_state.copyWith(cursor: _firstEmpty(e, _state.cells) ?? e.start, dir: e.dir));
  }

  // --------------------------------------------------------------- helpers

  /// Returns false when the puzzle carries no answers (daily puzzle).
  bool checkLetter() => _check([_state.cursor]);

  bool checkWord() {
    final entry = currentEntry;
    return entry != null && _check(entry.cells);
  }

  bool revealLetter() {
    final solution = puzzle.solution;
    final cur = _state.cursor;
    if (solution == null || _state.solved || _state.cells[cur]!.locked) {
      return false;
    }
    final cells = Map.of(_state.cells)
      ..[cur] = CellState(solution[cur]!, CellStatus.revealed);
    _set(_state.copyWith(
      cells: cells,
      helpersUsed: _state.helpersUsed + 1,
      solved: _isSolved(cells),
    ));
    return true;
  }

  // -------------------------------------------------------------- internals

  bool _check(List<Pos> positions) {
    final solution = puzzle.solution;
    if (solution == null || _state.solved) return false;
    final cells = Map.of(_state.cells);
    var touched = false;
    for (final p in positions) {
      final c = cells[p]!;
      if (c.isEmpty || c.locked) continue;
      cells[p] = CellState(
        c.letter,
        c.letter == solution[p] ? CellStatus.correct : CellStatus.wrong,
      );
      touched = true;
    }
    if (!touched) return false;
    _set(_state.copyWith(cells: cells, helpersUsed: _state.helpersUsed + 1));
    return true;
  }

  /// After typing: next empty cell later in the word → else first empty cell
  /// of the word → else first empty cell of the next incomplete word → stay.
  CrosswordState _advance(CrosswordState s) {
    final entry = entryAt(s.cursor, s.dir);
    if (entry == null) return s;
    final i = entry.cells.indexOf(s.cursor);
    for (var k = i + 1; k < entry.length; k++) {
      if (s.cells[entry.cells[k]]!.isEmpty) {
        return s.copyWith(cursor: entry.cells[k]);
      }
    }
    final inWord = _firstEmpty(entry, s.cells);
    if (inWord != null) return s.copyWith(cursor: inWord);

    final entries = puzzle.entries;
    final at = entries.indexOf(entry);
    for (var k = 1; k < entries.length; k++) {
      final e = entries[(at + k) % entries.length];
      final p = _firstEmpty(e, s.cells);
      if (p != null) return s.copyWith(cursor: p, dir: e.dir);
    }
    return s;
  }

  Pos? _firstEmpty(Entry e, Map<Pos, CellState> cells) {
    for (final p in e.cells) {
      if (cells[p]!.isEmpty) return p;
    }
    return null;
  }

  bool _isSolved(Map<Pos, CellState> cells) {
    final solution = puzzle.solution;
    if (solution == null) return false;
    return cells.entries.every((e) => e.value.letter == solution[e.key]);
  }

  void _set(CrosswordState next) {
    _state = next;
    notifyListeners();
  }
}
