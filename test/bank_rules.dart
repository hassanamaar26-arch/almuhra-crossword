// Quality rules for words/bank_v1.json. Mirror of core-ts/src/bank_check.ts.
import 'package:almuhra_crossword/core/arabic/normalize.dart';
import 'package:almuhra_crossword/core/generator/conflicts.dart';
import 'package:almuhra_crossword/core/generator/word_bank.dart';

export 'package:almuhra_crossword/core/generator/conflicts.dart' show clueLeaksAnswer;

const int bankMinLength = 3;
const int bankMaxLength = 7;
const List<String> bankCategories = [
  'جغرافيا', 'تاريخ', 'علوم', 'دين', 'أدب', 'رياضة', 'فن', 'طبيعة', 'عام',
];
const String bankBlank = '___';
/// Every rule violation in the bank, as readable lines. Empty = clean.
List<String> bankProblems(List<BankEntry> bank) {
  final out = <String>[];
  final ids = <int>{};
  final answers = <String, int>{};
  for (final e in bank) {
    final tag = 'id=${e.id} «${e.answer}»';
    if (!ids.add(e.id)) out.add('$tag: duplicate id');
    if (RegExp(r'\s').hasMatch(e.answer)) out.add('$tag: answer contains a space');
    final a = normalizeArabic(e.answer);
    final letters = toLetters(a);
    if (letters.length < bankMinLength || letters.length > bankMaxLength) {
      out.add('$tag: length ${letters.length} not in $bankMinLength..$bankMaxLength');
    }
    for (final l in letters) {
      if (!arabicAlphabet.contains(l)) out.add('$tag: letter «$l» not on the keyboard');
    }
    if (answers.containsKey(a)) {
      out.add('$tag: same answer as id=${answers[a]} after normalization');
    }
    answers[a] = e.id;
    if (!normalizeArabic(e.display).contains(a)) {
      out.add('$tag: display «${e.display}» does not contain the answer');
    }
    final clue = e.clue.trim();
    if (clue.length < 3 || clue.length > 60) out.add('$tag: clue length ${clue.length}');
    if (clueLeaksAnswer(e.clue, e.answer)) out.add('$tag: clue reveals the answer');
    // Answer is one word of a longer name: the clue must show which one with a blank.
    if (RegExp(r'\s').hasMatch(e.display.trim()) && !e.clue.contains(bankBlank)) {
      out.add('$tag: compound name needs $bankBlank in the clue');
    }
    if (!bankCategories.contains(e.category)) {
      out.add('$tag: unknown category «${e.category}»');
    }
    if (e.difficulty < 1 || e.difficulty > 3) out.add('$tag: difficulty ${e.difficulty}');
  }
  return out;
}
