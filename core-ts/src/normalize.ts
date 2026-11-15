// Arabic normalization rules — must stay identical to lib/core/arabic/normalize.dart
// See ASSUMPTIONS.md #4.

/** On-screen keyboard letters (30). Order = keyboard order is decided in UI. */
export const ALPHABET: readonly string[] = [
  'ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص',
  'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي',
  'ء', 'ى',
];

const ALPHABET_SET = new Set(ALPHABET);
export const MIN_LEN = 2;
export const MAX_LEN = 10;

const MAP: Record<string, string> = {
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
  'ؤ': 'و', 'ئ': 'ي', 'ة': 'ه',
};

// Tashkeel U+064B..U+065F, superscript alef U+0670, tatweel U+0640, whitespace.
const STRIP = /[ً-ٰٟـ\s]/gu;

export function normalize(input: string): string {
  let out = '';
  for (const ch of input.replace(STRIP, '')) out += MAP[ch] ?? ch;
  return out;
}

export function toLetters(normalized: string): string[] {
  return [...normalized];
}

/** Raw answer (no spaces inside) → valid if every normalized letter is on the keyboard. */
export function isValidAnswer(raw: string): boolean {
  if (/\S\s+\S/u.test(raw.trim())) return false;
  const letters = toLetters(normalize(raw));
  if (letters.length < MIN_LEN || letters.length > MAX_LEN) return false;
  return letters.every((l) => ALPHABET_SET.has(l));
}
