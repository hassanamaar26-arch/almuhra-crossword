// Arabic normalization — must stay identical to core-ts/src/normalize.ts.

/// Letters of the on-screen keyboard (30): 28 letters + hamza + alef maqsura.
const List<String> arabicAlphabet = [
  'ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص',
  'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي',
  'ء', 'ى',
];

const int minAnswerLength = 2;
const int maxAnswerLength = 10;

const Map<String, String> _map = {
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
  'ؤ': 'و', 'ئ': 'ي', 'ة': 'ه',
};

// Tashkeel U+064B..U+065F, superscript alef U+0670, tatweel U+0640, whitespace.
final RegExp _strip = RegExp(r'[ً-ٰٟـ\s]');

/// Grid form of a word: unified hamza seats, ة → ه, no tashkeel/tatweel/spaces.
String normalizeArabic(String input) {
  final out = StringBuffer();
  for (final rune in input.replaceAll(_strip, '').runes) {
    final ch = String.fromCharCode(rune);
    out.write(_map[ch] ?? ch);
  }
  return out.toString();
}

/// Splits a normalized word into single letters.
List<String> toLetters(String normalized) =>
    normalized.runes.map(String.fromCharCode).toList(growable: false);

bool isValidAnswer(String raw) {
  if (RegExp(r'\S\s+\S').hasMatch(raw.trim())) return false;
  final letters = toLetters(normalizeArabic(raw));
  if (letters.length < minAnswerLength || letters.length > maxAnswerLength) {
    return false;
  }
  return letters.every(arabicAlphabet.contains);
}
