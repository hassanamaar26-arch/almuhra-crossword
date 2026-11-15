import 'dart:convert';

import 'package:almuhra_crossword/models/puzzle.dart';
import 'package:almuhra_crossword/sample_puzzle.dart';
import 'package:almuhra_crossword/state/crossword_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Puzzle full() =>
    Puzzle.fromJson(jsonDecode(samplePuzzleJson) as Map<String, dynamic>);

Puzzle client() {
  final j = jsonDecode(samplePuzzleJson) as Map<String, dynamic>;
  j['grid'] = [
    for (final row in j['grid'] as List)
      (row as String).runes.map((r) => r == 0x23 ? '#' : '.').join(),
  ];
  for (final e in j['entries'] as List) {
    (e as Map)
      ..remove('answer')
      ..remove('display');
  }
  return Puzzle.fromJson(j);
}

void solveAll(CrosswordController c) {
  for (final e in c.puzzle.entries) {
    for (final p in e.cells) {
      c.selectCell(p);
      c.input(c.puzzle.solution![p]!);
    }
  }
}

void main() {
  late CrosswordController c;
  setUp(() => c = CrosswordController(full()));

  test('starts on the first across word', () {
    expect(c.state.cursor, const Pos(1, 4));
    expect(c.state.dir, Direction.across);
    expect(c.currentEntry!.number, 3);
    expect(c.state.cells.length, 23);
  });

  group('selectCell', () {
    test('tapping the active cell toggles direction', () {
      c.selectCell(const Pos(1, 4));
      expect(c.state.dir, Direction.down);
      expect(c.currentEntry!.number, 1);
      c.selectCell(const Pos(1, 4));
      expect(c.state.dir, Direction.across);
    });
    test('cell with only a down word switches to down', () {
      c.selectCell(const Pos(0, 6));
      expect(c.state.dir, Direction.down);
      expect(c.currentEntry!.number, 2);
    });
    test('no toggle when the cell has a single word', () {
      c.selectCell(const Pos(0, 6));
      c.selectCell(const Pos(0, 6));
      expect(c.state.dir, Direction.down);
    });
    test('black cells are ignored', () {
      c.selectCell(const Pos(0, 0));
      expect(c.state.cursor, const Pos(1, 4));
    });
  });

  group('input', () {
    test('writes and advances in reading order (col + 1)', () {
      c.input('و');
      expect(c.state.cells[const Pos(1, 4)]!.letter, 'و');
      expect(c.state.cells[const Pos(1, 4)]!.status, CellStatus.filled);
      expect(c.state.cursor, const Pos(1, 5));
    });
    test('finishing a word jumps to the next incomplete word', () {
      c..input('و')..input('ر')..input('د');
      expect(c.state.cursor, const Pos(3, 1));
      expect(c.currentEntry!.number, 5);
    });
    test('skips cells already filled by a crossing word', () {
      c.selectCell(const Pos(1, 5));
      c.input('ر');
      c.selectCell(const Pos(1, 4));
      c.input('و');
      expect(c.state.cursor, const Pos(1, 6));
    });
    test('input is normalized', () {
      c.selectCell(const Pos(3, 1));
      c.input('أ');
      expect(c.state.cells[const Pos(3, 1)]!.letter, 'ا');
      c.input('ة');
      expect(c.state.cells[const Pos(3, 2)]!.letter, 'ه');
    });
    test('non-Arabic input is ignored', () {
      c..input('a')..input('5')..input(' ')..input('');
      expect(c.state.cells[const Pos(1, 4)]!.isEmpty, isTrue);
      expect(c.state.cursor, const Pos(1, 4));
    });
  });

  group('backspace', () {
    test('clears the current letter first', () {
      c.input('و');
      c.selectCell(const Pos(1, 4));
      c.backspace();
      expect(c.state.cells[const Pos(1, 4)]!.isEmpty, isTrue);
      expect(c.state.cursor, const Pos(1, 4));
    });
    test('on an empty cell steps back and clears', () {
      c.input('و');
      c.backspace();
      expect(c.state.cursor, const Pos(1, 4));
      expect(c.state.cells[const Pos(1, 4)]!.isEmpty, isTrue);
    });
    test('at the first cell does nothing', () {
      c.backspace();
      expect(c.state.cursor, const Pos(1, 4));
    });
  });

  group('arrows (RTL)', () {
    test('left moves forward: col + 1', () {
      c.move(Move.left);
      expect(c.state.cursor, const Pos(1, 5));
    });
    test('right moves back: col − 1', () {
      c.move(Move.left);
      c.move(Move.right);
      expect(c.state.cursor, const Pos(1, 4));
    });
    test('stays put when only black cells remain', () {
      c.move(Move.right);
      expect(c.state.cursor, const Pos(1, 4));
    });
    test('up / down change row and prefer the down word', () {
      c.move(Move.up);
      expect(c.state.cursor, const Pos(0, 4));
      expect(c.state.dir, Direction.down);
      c.move(Move.down);
      expect(c.state.cursor, const Pos(1, 4));
    });
    test('jumps over black cells', () {
      c.selectCell(const Pos(6, 2));
      c.move(Move.left);
      expect(c.state.cursor, const Pos(6, 4));
    });
  });

  group('helpers', () {
    test('checkWord marks wrong and correct, counts one helper', () {
      c.input('ز');
      c.input('ر');
      expect(c.checkWord(), isTrue);
      expect(c.state.cells[const Pos(1, 4)]!.status, CellStatus.wrong);
      expect(c.state.cells[const Pos(1, 5)]!.status, CellStatus.correct);
      expect(c.state.cells[const Pos(1, 6)]!.status, CellStatus.empty);
      expect(c.state.helpersUsed, 1);
    });
    test('correct cells are locked against input and backspace', () {
      c.input('و');
      c.selectCell(const Pos(1, 4));
      c.checkLetter();
      c.input('ز');
      c.selectCell(const Pos(1, 4));
      c.backspace();
      expect(c.state.cells[const Pos(1, 4)]!.letter, 'و');
      expect(c.state.cells[const Pos(1, 4)]!.status, CellStatus.correct);
    });
    test('a wrong cell can be retyped', () {
      c.input('ز');
      c.selectCell(const Pos(1, 4));
      c.checkLetter();
      c.input('و');
      expect(c.state.cells[const Pos(1, 4)]!.letter, 'و');
      expect(c.state.cells[const Pos(1, 4)]!.status, CellStatus.filled);
    });
    test('revealLetter fills, locks and counts', () {
      expect(c.revealLetter(), isTrue);
      final cell = c.state.cells[const Pos(1, 4)]!;
      expect(cell.letter, 'و');
      expect(cell.status, CellStatus.revealed);
      expect(c.state.helpersUsed, 1);
      expect(c.revealLetter(), isFalse);
      expect(c.state.helpersUsed, 1);
    });
    test('checking an empty word does not count a helper', () {
      expect(c.checkWord(), isFalse);
      expect(c.state.helpersUsed, 0);
    });
  });

  group('solved', () {
    test('true only when every cell matches', () {
      solveAll(c);
      expect(c.state.solved, isTrue);
    });
    test('one wrong letter keeps it unsolved', () {
      solveAll(c);
      final c2 = CrosswordController(full());
      solveAll(c2);
      expect(c2.state.solved, isTrue);
      final c3 = CrosswordController(full());
      for (final e in c3.puzzle.entries) {
        for (final p in e.cells) {
          c3.selectCell(p);
          c3.input(p == const Pos(6, 0) ? 'ض' : c3.puzzle.solution![p]!);
        }
      }
      expect(c3.state.solved, isFalse);
    });
    test('no edits after solving', () {
      solveAll(c);
      c.selectCell(const Pos(1, 4));
      c.input('ز');
      c.backspace();
      expect(c.state.cells[const Pos(1, 4)]!.letter, 'و');
    });
  });

  group('client puzzle (no answers)', () {
    test('typing works; helpers and solved are unavailable', () {
      final d = CrosswordController(client());
      d.input('و');
      expect(d.state.cells[const Pos(1, 4)]!.letter, 'و');
      expect(d.checkWord(), isFalse);
      expect(d.checkLetter(), isFalse);
      expect(d.revealLetter(), isFalse);
      expect(d.state.solved, isFalse);
      expect(d.state.helpersUsed, 0);
    });
  });

  group('entries', () {
    test('selectEntry goes to the first empty cell, or the start when complete', () {
      final arbil = c.puzzle.entries.firstWhere((e) => e.number == 5);
      c.selectCell(const Pos(3, 1));
      c.input('ا');
      c.selectEntry(c.puzzle.entries.first);
      c.selectEntry(arbil);
      expect(c.state.cursor, const Pos(3, 2));
      expect(c.state.dir, Direction.across);
      final ward = c.puzzle.entries.first;
      c.selectEntry(ward);
      c..input('و')..input('ر')..input('د');
      expect(c.isComplete(ward), isTrue);
      expect(c.isComplete(arbil), isFalse);
      c.selectEntry(ward);
      expect(c.state.cursor, const Pos(1, 4));
    });
    test('stepEntry cycles forward and backward', () {
      c.stepEntry();
      expect(c.currentEntry!.number, 5);
      c.stepEntry(forward: false);
      c.stepEntry(forward: false);
      expect(c.currentEntry!.number, 6);
      expect(c.state.dir, Direction.down);
    });
    test('toggleDirection flips when both words exist', () {
      c.toggleDirection();
      expect(c.state.dir, Direction.down);
    });
  });

  test('listeners are notified on change', () {
    var n = 0;
    c.addListener(() => n++);
    c.input('و');
    c.move(Move.left);
    expect(n, 2);
  });
}
