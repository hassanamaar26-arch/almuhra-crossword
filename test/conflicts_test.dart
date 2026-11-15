import 'package:almuhra_crossword/core/generator/conflicts.dart';
import 'package:almuhra_crossword/core/generator/word_bank.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

BankEntry w(int id, String answer, String clue) => BankEntry(
      id: id,
      answer: answer,
      display: answer,
      clue: clue,
      category: 'عام',
      difficulty: 1,
    );

List<String> pairs(Map<int, Set<int>> m) => [
      for (final e in m.entries)
        for (final b in e.value) '${e.key}-$b',
    ]..sort();

void main() {
  test('conflict map: bare word, «ال», attached particles, both directions', () {
    final m = buildConflicts([
      w(1, 'بغداد', 'عاصمة العراق'),
      w(2, 'عراق', 'بلاد الرافدين'),
      w(3, 'نيل', 'أطول أنهار أفريقيا'),
      w(4, 'مصر', 'هبة النيل'),
      w(5, 'قمح', 'يُصنع منه الخبز'),
      w(6, 'خبز', 'يُعجن بالقمح وللخبز فرن'),
      w(7, 'نخيل', 'شجر التمر'),
    ]);
    expect(pairs(m), ['1-2', '2-1', '3-4', '4-3', '5-6', '6-5']);
  });

  test('conflict map: long answers also match inside longer clue words', () {
    final m = buildConflicts([
      w(1, 'خوارزمي', 'مؤسس الجبر'),
      w(2, 'حاسوب', 'ينفّذ الخوارزميات'),
      w(3, 'نيل', 'نهر'),
      w(4, 'نخلة', 'من النخيل'),
    ]);
    expect(pairs(m), ['1-2', '2-1']);
  });

  test('conflict map equals the pairwise reference rule (first 250 words)', () {
    final part = loadTestBank().take(250).toList();
    final expected = <String>[
      for (final a in part)
        for (final b in part)
          if (a.id != b.id &&
              (clueLeaksAnswer(a.clue, b.answer) ||
                  clueLeaksAnswer(b.clue, a.answer)))
            '${a.id}-${b.id}',
    ]..sort();
    expect(pairs(buildConflicts(part)), expected);
    expect(expected, isNotEmpty);
  });
}
