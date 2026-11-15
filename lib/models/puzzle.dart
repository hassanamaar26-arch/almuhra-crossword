import '../core/arabic/normalize.dart';

enum Direction {
  across,
  down;

  Direction get flipped => this == across ? down : across;
}

/// Logical grid position. Column 0 is the FIRST column in reading order,
/// i.e. the right-most column on screen (RTL).
class Pos {
  const Pos(this.row, this.col);
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is Pos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

enum CellStatus { empty, filled, correct, wrong, revealed }

/// What the player has in one white cell.
class CellState {
  const CellState(this.letter, this.status);
  const CellState.empty()
      : letter = '',
        status = CellStatus.empty;

  final String letter;
  final CellStatus status;

  bool get isEmpty => letter.isEmpty;

  /// Checked-correct and revealed cells can no longer be edited.
  bool get locked =>
      status == CellStatus.correct || status == CellStatus.revealed;

  @override
  bool operator ==(Object other) =>
      other is CellState && other.letter == letter && other.status == status;

  @override
  int get hashCode => Object.hash(letter, status);
}

class Entry {
  Entry({
    required this.number,
    required this.dir,
    required this.row,
    required this.col,
    required this.length,
    required this.clue,
    this.answer,
    this.display,
  }) : cells = List.unmodifiable([
          for (var k = 0; k < length; k++)
            dir == Direction.across ? Pos(row, col + k) : Pos(row + k, col),
        ]);

  factory Entry.fromJson(Map<String, dynamic> j) {
    final rawAnswer = j['answer'] as String?;
    final answer = rawAnswer == null ? null : normalizeArabic(rawAnswer);
    final length = j['length'] as int;
    if (length < minAnswerLength) {
      throw FormatException('entry ${j['number']}: length $length too short');
    }
    if (answer != null && toLetters(answer).length != length) {
      throw FormatException('entry ${j['number']}: answer/length mismatch');
    }
    return Entry(
      number: j['number'] as int,
      dir: switch (j['dir']) {
        'across' => Direction.across,
        'down' => Direction.down,
        _ => throw FormatException('bad dir: ${j['dir']}'),
      },
      row: j['row'] as int,
      col: j['col'] as int,
      length: length,
      clue: j['clue'] as String,
      answer: answer,
      display: j['display'] as String?,
    );
  }

  final int number;
  final Direction dir;
  final int row;
  final int col;
  final int length;
  final String clue;

  /// Normalized answer. Null in the client form of the daily puzzle.
  final String? answer;

  /// Correct spelling shown after solving. Null in the client form.
  final String? display;

  /// Cells of this word in typing order.
  final List<Pos> cells;

  Pos get start => cells.first;

  Map<String, dynamic> toJson() => {
        'number': number,
        'dir': dir.name,
        'row': row,
        'col': col,
        'length': length,
        'clue': clue,
        if (answer != null) 'answer': answer,
        if (display != null) 'display': display,
      };
}

/// One crossword (JSON v1). Immutable.
class Puzzle {
  Puzzle._({
    required this.id,
    required this.size,
    required List<List<bool>> blocks,
    required this.numbers,
    required this.entries,
    required this.solution,
  }) : _blocks = blocks;

  factory Puzzle.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw FormatException('unsupported puzzle version: ${j['version']}');
    }
    final size = j['size'] as int;
    final rows = (j['grid'] as List).cast<String>();
    if (rows.length != size) throw const FormatException('grid row count');

    final blocks = <List<bool>>[];
    final gridLetters = <Pos, String>{};
    for (var r = 0; r < size; r++) {
      final chars = toLetters(rows[r]);
      if (chars.length != size) throw FormatException('grid row $r width');
      blocks.add([for (final ch in chars) ch == '#']);
      for (var c = 0; c < size; c++) {
        if (chars[c] != '#' && chars[c] != '.') {
          gridLetters[Pos(r, c)] = normalizeArabic(chars[c]);
        }
      }
    }

    final numbers = <Pos, int>{
      for (final n in (j['numbers'] as List))
        Pos((n as List)[0] as int, n[1] as int): n[2] as int,
    };

    final entries = [
      for (final e in (j['entries'] as List))
        Entry.fromJson((e as Map).cast<String, dynamic>()),
    ];
    if (entries.isEmpty) throw const FormatException('puzzle has no entries');

    final withAnswers = entries.every((e) => e.answer != null);
    final solution = <Pos, String>{};
    for (final e in entries) {
      if (numbers[e.start] != e.number) {
        throw FormatException('entry ${e.number}: number not on its start cell');
      }
      final letters = withAnswers ? toLetters(e.answer!) : null;
      for (var k = 0; k < e.length; k++) {
        final p = e.cells[k];
        final inside = p.row >= 0 && p.row < size && p.col >= 0 && p.col < size;
        if (!inside || blocks[p.row][p.col]) {
          throw FormatException('entry ${e.number}: cell $p is not a white cell');
        }
        if (letters != null) {
          final prev = solution[p] ?? gridLetters[p];
          if (prev != null && prev != letters[k]) {
            throw FormatException('entry ${e.number}: crossing conflict at $p');
          }
          solution[p] = letters[k];
        }
      }
    }

    return Puzzle._(
      id: j['id'] as String,
      size: size,
      blocks: blocks,
      numbers: Map.unmodifiable(numbers),
      entries: List.unmodifiable(entries),
      solution: withAnswers ? Map.unmodifiable(solution) : null,
    );
  }

  final String id;
  final int size;
  final List<List<bool>> _blocks;

  /// Small number shown in the corner of a word's first cell.
  final Map<Pos, int> numbers;

  /// Across entries first, then down, each by number.
  final List<Entry> entries;

  /// Correct letter per white cell. Null when answers live on the server.
  final Map<Pos, String>? solution;

  bool get hasSolution => solution != null;

  /// JSON v1 again: full form with a solution, masked client form without.
  Map<String, dynamic> toJson() => {
        'version': 1,
        'id': id,
        'size': size,
        'direction': 'rtl',
        'grid': [
          for (var r = 0; r < size; r++)
            [
              for (var c = 0; c < size; c++)
                _blocks[r][c] ? '#' : (solution?[Pos(r, c)] ?? '.'),
            ].join(),
        ],
        'numbers': [
          for (final n in numbers.entries) [n.key.row, n.key.col, n.value],
        ],
        'entries': [for (final e in entries) e.toJson()],
      };

  bool inBounds(Pos p) =>
      p.row >= 0 && p.row < size && p.col >= 0 && p.col < size;

  bool isWhite(Pos p) => inBounds(p) && !_blocks[p.row][p.col];

  Iterable<Pos> get whiteCells sync* {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (!_blocks[r][c]) yield Pos(r, c);
      }
    }
  }
}
