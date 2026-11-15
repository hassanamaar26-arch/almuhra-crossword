// Puzzle JSON v1. Full form = practice mode + server. Client form = daily puzzle
// sent to the app: letters masked as ".", no answer/display — only length.
import type { Puzzle, Dir } from './generator.ts';

export interface JsonEntry {
  number: number; dir: Dir; row: number; col: number; length: number;
  clue: string; answer?: string; display?: string;
}
export interface PuzzleJson {
  version: 1; id: string; size: number; direction: 'rtl';
  grid: string[]; numbers: [number, number, number][]; entries: JsonEntry[];
}

function build(p: Puzzle, id: string, withAnswers: boolean): PuzzleJson {
  const seen = new Set<number>();
  const numbers: [number, number, number][] = [];
  for (const w of p.words) {
    if (!seen.has(w.number)) { seen.add(w.number); numbers.push([w.row, w.col, w.number]); }
  }
  const order = [...p.words].sort((a, b) =>
    a.dir === b.dir ? a.number - b.number : a.dir === 'across' ? -1 : 1);
  return {
    version: 1, id, size: p.size, direction: 'rtl',
    grid: p.grid.map((row) => row.map((ch) => (ch === null ? '#' : withAnswers ? ch : '.')).join('')),
    numbers,
    entries: order.map((w) => ({
      number: w.number, dir: w.dir, row: w.row, col: w.col,
      length: [...w.answer].length, clue: w.clue,
      ...(withAnswers ? { answer: w.answer, display: w.display } : {}),
    })),
  };
}

export const toFullJson = (p: Puzzle, id: string) => build(p, id, true);
export const toClientJson = (p: Puzzle, id: string) => build(p, id, false);
