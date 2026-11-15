import 'dart:convert';

import 'package:almuhra_crossword/models/puzzle.dart';
import 'package:almuhra_crossword/sample_puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sample() =>
    jsonDecode(samplePuzzleJson) as Map<String, dynamic>;

/// Client form of the daily puzzle: masked grid, no answer/display.
Map<String, dynamic> clientForm() {
  final j = sample();
  j['grid'] = [
    for (final row in j['grid'] as List)
      (row as String).runes.map((r) => r == 0x23 ? '#' : '.').join(),
  ];
  for (final e in j['entries'] as List) {
    (e as Map)
      ..remove('answer')
      ..remove('display');
  }
  return j;
}

void main() {
  test('full form parses: size, blocks, numbers, entries, solution', () {
    final p = Puzzle.fromJson(sample());
    expect(p.size, 7);
    expect(p.entries.length, 8);
    expect(p.isWhite(const Pos(0, 4)), isTrue);
    expect(p.isWhite(const Pos(0, 0)), isFalse);
    expect(p.isWhite(const Pos(-1, 0)), isFalse);
    expect(p.numbers[const Pos(3, 1)], 5);
    expect(p.whiteCells.length, 23);
    expect(p.hasSolution, isTrue);
    expect(p.solution![const Pos(3, 1)], 'ا');
    expect(p.solution![const Pos(3, 5)], 'ل'); // crossing اربيل × لندن
  });

  test('entry cells follow logical order', () {
    final p = Puzzle.fromJson(sample());
    final arbil = p.entries.firstWhere((e) => e.number == 5);
    expect(arbil.cells.first, const Pos(3, 1));
    expect(arbil.cells.last, const Pos(3, 5));
    final shawqi = p.entries.firstWhere((e) => e.number == 1);
    expect(shawqi.cells.last, const Pos(3, 4));
  });

  test('client form parses without any solution', () {
    final p = Puzzle.fromJson(clientForm());
    expect(p.hasSolution, isFalse);
    expect(p.whiteCells.length, 23);
    expect(p.entries.every((e) => e.answer == null && e.display == null), isTrue);
    expect(p.entries.firstWhere((e) => e.number == 5).length, 5);
  });

  test('answers are normalized on load', () {
    final j = sample();
    ((j['entries'] as List)[1] as Map)['answer'] = 'أربيل';
    expect(Puzzle.fromJson(j).solution![const Pos(3, 1)], 'ا');
  });

  group('invalid JSON is rejected', () {
    test('wrong version', () {
      expect(() => Puzzle.fromJson(sample()..['version'] = 2), throwsFormatException);
    });
    test('row width', () {
      final j = sample();
      (j['grid'] as List)[0] = '###';
      expect(() => Puzzle.fromJson(j), throwsFormatException);
    });
    test('answer/length mismatch', () {
      final j = sample();
      ((j['entries'] as List)[0] as Map)['length'] = 4;
      expect(() => Puzzle.fromJson(j), throwsFormatException);
    });
    test('entry over a black cell', () {
      final j = clientForm();
      ((j['entries'] as List)[0] as Map)['length'] = 2;
      ((j['entries'] as List)[0] as Map)['col'] = 2;
      expect(() => Puzzle.fromJson(j), throwsFormatException);
    });
    test('crossing conflict', () {
      final j = sample();
      ((j['entries'] as List)[0] as Map)['answer'] = 'ورق';
      expect(() => Puzzle.fromJson(j), throwsFormatException);
    });
    test('number not on start cell', () {
      final j = sample();
      ((j['entries'] as List)[0] as Map)['number'] = 9;
      expect(() => Puzzle.fromJson(j), throwsFormatException);
    });
  });
}
