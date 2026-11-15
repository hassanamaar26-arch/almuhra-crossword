import '../arabic/normalize.dart';
import 'word_bank.dart';

// Cross-clue conflicts: two words must not share a puzzle when the clue of one
// names the answer of the other (bare, with «ال», or with an attached particle).
// Must stay identical to core-ts/src/conflicts.ts.

const List<String> cluePrefixes = [
  'وال', 'بال', 'كال', 'فال', 'لل', 'ال', 'و', 'ب', 'ل', 'ك', 'ف',
];
final RegExp _notArabic = RegExp(r'[^ء-ٰٟ]+');

/// Answers this long also count when they appear inside a longer clue word.
const int substringMin = 5;

List<String> _clueTokens(String clue) => [
      for (final raw in clue.split(_notArabic))
        if (normalizeArabic(raw).isNotEmpty) normalizeArabic(raw),
    ];

/// Reference rule: true when [clue] gives [answer] away.
bool clueLeaksAnswer(String clue, String answer) {
  final a = normalizeArabic(answer);
  for (final token in _clueTokens(clue)) {
    if (token == a) return true;
    if (a.length >= substringMin && token.contains(a)) return true;
    for (final p in cluePrefixes) {
      if (token.startsWith(p) && token.substring(p.length) == a) return true;
    }
  }
  return false;
}

/// Symmetric map: word id → ids that may not share a puzzle with it.
Map<int, Set<int>> buildConflicts(List<BankEntry> bank) {
  final byAnswer = <String, List<int>>{};
  for (final e in bank) {
    (byAnswer[normalizeArabic(e.answer)] ??= []).add(e.id);
  }
  final out = <int, Set<int>>{};
  for (final e in bank) {
    for (final token in _clueTokens(e.clue)) {
      final found = <String>{token};
      for (final p in cluePrefixes) {
        if (token.startsWith(p)) found.add(token.substring(p.length));
      }
      for (var len = substringMin; len <= token.length; len++) {
        for (var i = 0; i + len <= token.length; i++) {
          found.add(token.substring(i, i + len));
        }
      }
      for (final s in found) {
        for (final id in byAnswer[s] ?? const <int>[]) {
          if (id == e.id) continue;
          (out[e.id] ??= {}).add(id);
          (out[id] ??= {}).add(e.id);
        }
      }
    }
  }
  return out;
}
