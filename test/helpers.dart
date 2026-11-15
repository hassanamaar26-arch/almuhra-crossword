import 'dart:io';

import 'package:almuhra_crossword/core/generator/generator.dart';
import 'package:almuhra_crossword/core/generator/word_bank.dart';
import 'package:almuhra_crossword/state/crossword_controller.dart';

List<BankEntry> loadTestBank() =>
    parseWordBank(File('words/bank_v1.json').readAsStringSync());

/// Same generator, without a background isolate.
Future<GeneratedPuzzle> syncGenerator(
  List<BankEntry> bank,
  int size,
  String seed,
  Set<int> exclude,
) async =>
    generatePuzzle(bank, size: size, seed: seed, exclude: exclude);

/// Types the right letter into every cell.
void solveAll(CrosswordController c) {
  for (final e in c.puzzle.entries) {
    for (final p in e.cells) {
      c.selectCell(p);
      c.input(c.puzzle.solution![p]!);
    }
  }
}
