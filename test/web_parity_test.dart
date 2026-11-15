// Runs on the VM and in a browser (`flutter test --platform chrome`):
// the generator must give the same puzzles when compiled to JavaScript.
import 'dart:convert';

import 'package:almuhra_crossword/core/generator/generator.dart';
import 'package:almuhra_crossword/core/generator/seed_rng.dart';
import 'package:almuhra_crossword/core/generator/word_bank.dart';
import 'package:flutter_test/flutter_test.dart';

import 'web_parity_data.dart';

void main() {
  final data = jsonDecode(webParityJson) as Map<String, dynamic>;
  final bank = [
    for (final e in data['bank'] as List)
      BankEntry.fromJson((e as Map).cast<String, dynamic>()),
  ];

  for (final f in data['rng'] as List) {
    test('rng sequence for seed "${f['seed']}"', () {
      final rng = SeedRng(f['seed'] as String);
      expect([for (var i = 0; i < 8; i++) rng.next()], f['values']);
    });
  }

  for (final f in data['cases'] as List) {
    test('puzzle ${f['size']}×${f['size']} seed "${f['seed']}"', () {
      final g = generatePuzzle(
        bank,
        size: f['size'] as int,
        seed: f['seed'] as String,
      );
      expect(g.json, f['json']);
    });
  }
}
