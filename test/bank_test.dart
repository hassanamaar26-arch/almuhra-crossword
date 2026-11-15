import 'package:almuhra_crossword/core/arabic/normalize.dart';
import 'package:almuhra_crossword/core/generator/generator.dart';
import 'package:almuhra_crossword/core/generator/word_bank.dart';
import 'package:almuhra_crossword/models/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bank_rules.dart';
import 'helpers.dart';

BankEntry entry({
  int id = 1,
  String answer = 'بغداد',
  String? display,
  String clue = 'عاصمة العراق',
  String category = 'جغرافيا',
  int difficulty = 1,
}) =>
    BankEntry(
      id: id,
      answer: answer,
      display: display ?? answer,
      clue: clue,
      category: category,
      difficulty: difficulty,
    );

void main() {
  final bank = loadTestBank();

  test('the checker catches each kind of mistake', () {
    expect(bankProblems([entry()]), isEmpty);
    void bad(List<BankEntry> entries, String needle) => expect(
          bankProblems(entries).any((p) => p.contains(needle)),
          isTrue,
          reason: needle,
        );
    bad([entry(), entry()], 'duplicate id');
    bad([entry(), entry(id: 2, answer: 'بَغْدَاد')], 'same answer');
    bad([entry(answer: 'أنقرة'), entry(id: 2, answer: 'انقره')], 'same answer');
    bad([entry(answer: 'ما')], 'length 2');
    bad([entry(answer: 'اينشتاين')], 'length 8');
    bad([entry(answer: 'ابن سينا')], 'space');
    bad([entry(answer: 'H2O')], 'not on the keyboard');
    bad([entry(display: 'دمشق')], 'display');
    bad([entry(clue: 'مدينة بغداد')], 'reveals');
    bad([entry(clue: '')], 'clue length');
    bad([entry(answer: 'شوقي', display: 'أحمد شوقي', clue: 'أمير الشعراء')], 'compound name');
    expect(
      bankProblems([entry(answer: 'شوقي', display: 'أحمد شوقي', clue: 'أحمد ___، أمير الشعراء')]),
      isEmpty,
    );
    bad([entry(category: 'x')], 'category');
    bad([entry(difficulty: 4)], 'difficulty');
  });

  test('clue leak detection: whole word, with prefixes, inside longer words', () {
    expect(clueLeaksAnswer('نهر النيل العظيم', 'نيل'), isTrue);
    expect(clueLeaksAnswer('يصب في النيل', 'نيل'), isTrue);
    expect(clueLeaksAnswer('نسبة للنيل وبالنيل', 'نيل'), isTrue);
    expect(clueLeaksAnswer('تُنسب إليه الخوارزميات', 'خوارزمي'), isTrue);
    expect(clueLeaksAnswer('عاصمة أَنْقَرَة', 'أنقرة'), isTrue);
    expect(clueLeaksAnswer('أطول أنهار أفريقيا', 'نيل'), isFalse);
    expect(clueLeaksAnswer('شجرة النخيل', 'نيل'), isFalse);
  });

  test('bank_v1.json passes every rule', () {
    final problems = bankProblems(bank);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('bank size and shape suit the generator', () {
    expect(bank.length, greaterThanOrEqualTo(500));
    final byLength = <int, int>{};
    final byLetter = <String, int>{};
    for (final w in bank) {
      final letters = toLetters(normalizeArabic(w.answer));
      byLength[letters.length] = (byLength[letters.length] ?? 0) + 1;
      for (final l in letters.toSet()) {
        byLetter[l] = (byLetter[l] ?? 0) + 1;
      }
    }
    for (var n = bankMinLength; n <= bankMaxLength; n++) {
      expect(byLength[n] ?? 0, greaterThanOrEqualTo(30), reason: 'length $n');
    }
    final short = (byLength[3] ?? 0) + (byLength[4] ?? 0) + (byLength[5] ?? 0);
    expect(short / bank.length, greaterThanOrEqualTo(0.6));
    for (final l in arabicAlphabet) {
      expect(byLetter[l] ?? 0, greaterThanOrEqualTo(8), reason: 'letter $l');
    }
  });

  const targets = {7: 8, 9: 12, 11: 16};
  for (final size in supportedSizes) {
    test(
        'stress: 50 puzzles in a row at $size×$size, never repeating the last 5 puzzles\' words',
        () {
      final limit = (bank.length * 0.4).floor();
      var recent = <List<int>>[]; // newest first, like PracticeSession
      for (var i = 0; i < 50; i++) {
        final exclude = <int>{};
        for (final ids in recent) {
          if (exclude.length + ids.length > limit) break;
          exclude.addAll(ids);
        }
        final g = generatePuzzle(bank, size: size, seed: 'stress-$size-$i', exclude: exclude);
        final p = Puzzle.fromJson(g.json); // re-validates every crossing
        expect(p.entries.length, targets[size], reason: 'puzzle $i');
        expect(g.wordIds.toSet().intersection(exclude), isEmpty, reason: 'puzzle $i');
        recent = [g.wordIds, ...recent].take(5).toList();
        final flat = [for (final ids in recent) ...ids];
        expect(flat.toSet().length, flat.length, reason: 'last 5 puzzles share no word');
      }
    });
  }
}
