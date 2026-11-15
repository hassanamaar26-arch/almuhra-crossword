// Cross-clue conflicts: two words must not share a puzzle when the clue of one
// names the answer of the other (bare, with «ال», or with an attached particle).
// Must stay identical to lib/core/generator/conflicts.dart.
import { normalize } from './normalize.ts';

export const CLUE_PREFIXES = ['وال', 'بال', 'كال', 'فال', 'لل', 'ال', 'و', 'ب', 'ل', 'ك', 'ف'];
const NOT_ARABIC = /[^ء-ٰٟ]+/u;
/** Answers this long also count when they appear inside a longer clue word. */
export const SUBSTRING_MIN = 5;

function clueTokens(clue: string): string[] {
  return clue.split(NOT_ARABIC).map(normalize).filter((t) => t.length > 0);
}

/** Reference rule: true when [clue] gives [answer] away. */
export function clueLeaksAnswer(clue: string, answer: string): boolean {
  const a = normalize(answer);
  for (const token of clueTokens(clue)) {
    if (token === a) return true;
    if (a.length >= SUBSTRING_MIN && token.includes(a)) return true;
    for (const p of CLUE_PREFIXES) {
      if (token.startsWith(p) && token.slice(p.length) === a) return true;
    }
  }
  return false;
}

interface Word { id: number; answer: string; clue: string }

/** Symmetric map: word id → ids that may not share a puzzle with it. */
export function buildConflicts(bank: readonly Word[]): Map<number, Set<number>> {
  const byAnswer = new Map<string, number[]>();
  for (const e of bank) {
    const a = normalize(e.answer);
    const ids = byAnswer.get(a);
    if (ids) ids.push(e.id); else byAnswer.set(a, [e.id]);
  }
  const out = new Map<number, Set<number>>();
  const link = (a: number, b: number) => {
    if (a === b) return;
    for (const [x, y] of [[a, b], [b, a]]) {
      const set = out.get(x);
      if (set) set.add(y); else out.set(x, new Set([y]));
    }
  };
  for (const e of bank) {
    for (const token of clueTokens(e.clue)) {
      const found = new Set<string>([token]);
      for (const p of CLUE_PREFIXES) if (token.startsWith(p)) found.add(token.slice(p.length));
      for (let len = SUBSTRING_MIN; len <= token.length; len++) {
        for (let i = 0; i + len <= token.length; i++) found.add(token.slice(i, i + len));
      }
      for (const s of found) for (const id of byAnswer.get(s) ?? []) link(e.id, id);
    }
  }
  return out;
}
