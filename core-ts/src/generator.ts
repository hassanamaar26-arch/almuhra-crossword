// Free-form crossword generator. Pure, deterministic for a given (bank, size, seed).
// Must stay byte-for-byte equivalent to lib/core/generator/*.dart (checked by fixtures).
//
// Coordinates are LOGICAL: col 0 is the first column in reading order.
// The app renders with RTL directionality, so col 0 appears on the right and
// "across" words read right → left naturally.

import { normalize, isValidAnswer } from './normalize.ts';
import { Rng } from './rng.ts';
import { buildConflicts } from './conflicts.ts';

export interface Entry {
  id: number;
  answer: string;
  display: string;
  clue: string;
  category: string;
  difficulty: number;
}

export type Dir = 'across' | 'down';

export interface Placed {
  id: number;
  answer: string; // normalized
  display: string;
  clue: string;
  row: number;
  col: number;
  dir: Dir;
  number: number;
}

export interface Puzzle {
  size: number;
  seed: string;
  words: Placed[];
  grid: (string | null)[][];
}

export interface Options {
  size: number;
  seed: string;
  exclude?: ReadonlySet<number>;
}

export class GeneratorError extends Error {}

const TARGET: Record<number, number> = { 7: 8, 9: 12, 11: 16 };
const MAX_PASSES = 4;

interface Cand { id: number; letters: string[]; e: Entry }

const ATTEMPTS = 40;

/** Best of ATTEMPTS deterministic sub-seeds: most words, then most filled cells. */
export function generate(bank: readonly Entry[], opts: Options): Puzzle {
  let best: Puzzle | null = null;
  let bestScore = -1;
  const conflicts = buildConflicts(bank);
  for (let k = 0; k < ATTEMPTS; k++) {
    const p = attempt(bank, opts, `${opts.seed}#${k}`, conflicts);
    const filled = p.grid.flat().filter((x) => x !== null).length;
    const score = p.words.length * 1000 + filled;
    if (score > bestScore) { best = p; bestScore = score; }
    if (p.words.length >= TARGET[opts.size]) break;
  }
  return best!;
}

function attempt(
  bank: readonly Entry[],
  opts: Options,
  subSeed: string,
  conflicts: ReadonlyMap<number, ReadonlySet<number>>,
): Puzzle {
  const { size, seed } = opts;
  if (!(size in TARGET)) throw new GeneratorError(`unsupported size ${size}`);
  if (bank.length === 0) throw new GeneratorError('empty bank');
  for (const e of bank) {
    if (!isValidAnswer(e.answer)) throw new GeneratorError(`invalid answer id=${e.id}: ${e.answer}`);
  }

  const rng = new Rng(subSeed);
  const pool: Cand[] = [...bank]
    .filter((e) => !opts.exclude?.has(e.id))
    .sort((a, b) => a.id - b.id)
    .map((e) => ({ id: e.id, letters: [...normalize(e.answer)], e }))
    .filter((c) => c.letters.length <= size);
  rng.shuffle(pool);
  if (pool.length === 0) throw new GeneratorError('no usable words');

  const grid: (string | null)[][] = Array.from({ length: size }, () => Array(size).fill(null));
  const usedA: boolean[][] = Array.from({ length: size }, () => Array(size).fill(false));
  const usedD: boolean[][] = Array.from({ length: size }, () => Array(size).fill(false));
  const byLetter = new Map<string, [number, number][]>();
  const placed: Omit<Placed, 'number'>[] = [];
  const usedAnswers = new Set<string>();
  // Ids whose clue names a placed answer, or whose answer a placed clue names.
  const blocked = new Set<number>();

  const empty = (r: number, c: number) =>
    r < 0 || r >= size || c < 0 || c >= size || grid[r][c] === null;

  /** Returns number of crossings, or -1 if the placement is illegal. */
  function check(L: string[], r0: number, c0: number, dir: Dir): number {
    const [dr, dc] = dir === 'across' ? [0, 1] : [1, 0];
    const len = L.length;
    const rEnd = r0 + dr * (len - 1), cEnd = c0 + dc * (len - 1);
    if (r0 < 0 || c0 < 0 || rEnd >= size || cEnd >= size) return -1;
    if (!empty(r0 - dr, c0 - dc) || !empty(rEnd + dr, cEnd + dc)) return -1;
    let crossings = 0;
    for (let k = 0; k < len; k++) {
      const r = r0 + dr * k, c = c0 + dc * k;
      const cur = grid[r][c];
      if (cur !== null) {
        if (cur !== L[k]) return -1;
        if ((dir === 'across' ? usedA : usedD)[r][c]) return -1;
        crossings++;
      } else if (!empty(r + dc, c + dr) || !empty(r - dc, c - dr)) {
        return -1; // would touch a parallel neighbour → stray 2-letter word
      }
    }
    return crossings;
  }

  function put(cand: Cand, r0: number, c0: number, dir: Dir) {
    const [dr, dc] = dir === 'across' ? [0, 1] : [1, 0];
    cand.letters.forEach((ch, k) => {
      const r = r0 + dr * k, c = c0 + dc * k;
      if (grid[r][c] === null) {
        grid[r][c] = ch;
        if (!byLetter.has(ch)) byLetter.set(ch, []);
        byLetter.get(ch)!.push([r, c]);
      }
      (dir === 'across' ? usedA : usedD)[r][c] = true;
    });
    const answer = cand.letters.join('');
    usedAnswers.add(answer);
    for (const id of conflicts.get(cand.id) ?? []) blocked.add(id);
    placed.push({ id: cand.id, answer, display: cand.e.display, clue: cand.e.clue, row: r0, col: c0, dir });
  }

  // Seed word: first long-enough word in shuffled order, else the longest.
  const minFirst = Math.ceil(size * 0.55);
  let first = pool.find((c) => c.letters.length >= minFirst);
  if (!first) first = pool.reduce((a, b) => (b.letters.length > a.letters.length ? b : a));
  put(first, Math.floor(size / 2), Math.floor((size - first.letters.length) / 2), 'across');

  const target = TARGET[size];
  for (let pass = 0; pass < MAX_PASSES && placed.length < target; pass++) {
    let progress = false;
    for (const cand of pool) {
      if (placed.length >= target) break;
      if (usedAnswers.has(cand.letters.join(''))) continue;
      if (blocked.has(cand.id)) continue;
      let best = 0, br = 0, bc = 0, bd: Dir = 'across';
      cand.letters.forEach((ch, k) => {
        for (const [r, c] of byLetter.get(ch) ?? []) {
          for (const dir of ['across', 'down'] as const) {
            const r0 = dir === 'down' ? r - k : r;
            const c0 = dir === 'across' ? c - k : c;
            const x = check(cand.letters, r0, c0, dir);
            if (x > best) { best = x; br = r0; bc = c0; bd = dir; }
          }
        }
      });
      if (best > 0) { put(cand, br, bc, bd); progress = true; }
    }
    if (!progress) break;
  }

  // Number word starts in reading order.
  const starts = [...new Set(placed.map((w) => w.row * size + w.col))].sort((a, b) => a - b);
  const words: Placed[] = placed
    .map((w) => ({ ...w, number: starts.indexOf(w.row * size + w.col) + 1 }))
    .sort((a, b) => a.number - b.number || (a.dir === 'across' ? -1 : 1));

  return { size, seed, words, grid };
}
