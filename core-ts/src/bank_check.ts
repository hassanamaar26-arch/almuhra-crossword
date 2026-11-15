// Quality rules for words/bank_v1.json. Mirrored in test/bank_rules.dart.
import { normalize, toLetters, ALPHABET } from './normalize.ts';
import type { Entry } from './generator.ts';
import { clueLeaksAnswer } from './conflicts.ts';

export { clueLeaksAnswer };

export const BANK_MIN_LEN = 3;
export const BANK_MAX_LEN = 7;
export const CATEGORIES = ['جغرافيا', 'تاريخ', 'علوم', 'دين', 'أدب', 'رياضة', 'فن', 'طبيعة', 'عام'];
export const BLANK = '___';
/** Every rule violation in the bank, as readable lines. Empty = clean. */
export function bankProblems(bank: readonly Entry[]): string[] {
  const out: string[] = [];
  const alphabet = new Set(ALPHABET);
  const ids = new Set<number>();
  const answers = new Map<string, number>();
  for (const e of bank) {
    const tag = `id=${e.id} «${e.answer}»`;
    if (ids.has(e.id)) out.push(`${tag}: duplicate id`);
    ids.add(e.id);
    if (/\s/u.test(e.answer)) out.push(`${tag}: answer contains a space`);
    const a = normalize(e.answer);
    const letters = toLetters(a);
    if (letters.length < BANK_MIN_LEN || letters.length > BANK_MAX_LEN) {
      out.push(`${tag}: length ${letters.length} not in ${BANK_MIN_LEN}..${BANK_MAX_LEN}`);
    }
    for (const l of letters) if (!alphabet.has(l)) out.push(`${tag}: letter «${l}» not on the keyboard`);
    if (answers.has(a)) out.push(`${tag}: same answer as id=${answers.get(a)} after normalization`);
    answers.set(a, e.id);
    if (!normalize(e.display).includes(a)) out.push(`${tag}: display «${e.display}» does not contain the answer`);
    const clue = e.clue.trim();
    if (clue.length < 3 || clue.length > 60) out.push(`${tag}: clue length ${clue.length}`);
    if (clueLeaksAnswer(e.clue, e.answer)) out.push(`${tag}: clue reveals the answer`);
    // Answer is one word of a longer name: the clue must show which one with a blank.
    if (/\s/u.test(e.display.trim()) && !e.clue.includes(BLANK)) out.push(`${tag}: compound name needs ${BLANK} in the clue`);
    if (!CATEGORIES.includes(e.category)) out.push(`${tag}: unknown category «${e.category}»`);
    if (![1, 2, 3].includes(e.difficulty)) out.push(`${tag}: difficulty ${e.difficulty}`);
  }
  return out;
}
