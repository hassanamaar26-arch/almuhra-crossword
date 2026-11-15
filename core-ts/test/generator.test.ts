import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { generate, GeneratorError, type Entry, type Puzzle } from '../src/generator.ts';
import { normalize } from '../src/normalize.ts';

const BANK: Entry[] = JSON.parse(
  readFileSync(new URL('../../words/bank_v1.json', import.meta.url), 'utf8'),
);

const SIZES = [7, 9, 11] as const;
const MIN_WORDS: Record<number, number> = { 7: 5, 9: 7, 11: 9 };

/** All maximal runs (length ≥ 2) of letters in both directions. */
function runs(p: Puzzle): string[] {
  const out: string[] = [];
  const n = p.size;
  for (const dir of ['across', 'down'] as const) {
    for (let a = 0; a < n; a++) {
      let start = -1;
      for (let b = 0; b <= n; b++) {
        const r = dir === 'across' ? a : b;
        const c = dir === 'across' ? b : a;
        const filled = b < n && p.grid[r][c] !== null;
        if (filled && start < 0) start = b;
        if (!filled && start >= 0) {
          if (b - start >= 2) {
            const sr = dir === 'across' ? a : start;
            const sc = dir === 'across' ? start : a;
            out.push(`${dir}:${sr}:${sc}:${b - start}`);
          }
          start = -1;
        }
      }
    }
  }
  return out.sort();
}

function checkInvariants(p: Puzzle) {
  const n = p.size;
  // 1. every word inside bounds and its letters equal the grid
  for (const w of p.words) {
    const [dr, dc] = w.dir === 'across' ? [0, 1] : [1, 0];
    assert.equal(w.answer, normalize(w.answer), 'answer stored normalized');
    [...w.answer].forEach((ch, k) => {
      const r = w.row + dr * k, c = w.col + dc * k;
      assert.ok(r >= 0 && r < n && c >= 0 && c < n, 'in bounds');
      assert.equal(p.grid[r][c], ch, `crossing letter mismatch in ${w.answer}`);
    });
  }
  // 2. no stray words: grid runs == placed words exactly
  const placed = p.words.map((w) => `${w.dir}:${w.row}:${w.col}:${[...w.answer].length}`).sort();
  assert.deepEqual(runs(p), placed, 'grid runs must equal placed words');
  // 3. no duplicate answers
  assert.equal(new Set(p.words.map((w) => w.answer)).size, p.words.length);
  // 4. all letters connected
  const cells: [number, number][] = [];
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (p.grid[r][c]) cells.push([r, c]);
  const seen = new Set<string>([`${cells[0][0]},${cells[0][1]}`]);
  const stack = [cells[0]];
  while (stack.length) {
    const [r, c] = stack.pop()!;
    for (const [nr, nc] of [[r + 1, c], [r - 1, c], [r, c + 1], [r, c - 1]]) {
      const k = `${nr},${nc}`;
      if (nr >= 0 && nr < n && nc >= 0 && nc < n && p.grid[nr][nc] && !seen.has(k)) {
        seen.add(k); stack.push([nr, nc]);
      }
    }
  }
  assert.equal(seen.size, cells.length, 'grid must be one connected shape');
  // 5. numbering: 1..k in reading order, words sharing a start share a number
  const starts = [...new Set(p.words.map((w) => w.row * n + w.col))].sort((a, b) => a - b);
  for (const w of p.words) assert.equal(w.number, starts.indexOf(w.row * n + w.col) + 1);
}

test('same seed → identical puzzle; bank order does not matter', () => {
  const a = generate(BANK, { size: 9, seed: '2026-11-15' });
  const b = generate([...BANK].reverse(), { size: 9, seed: '2026-11-15' });
  assert.deepEqual(a, b);
});

test('different seeds give different puzzles', () => {
  const keys = new Set<string>();
  for (let i = 0; i < 50; i++) {
    const p = generate(BANK, { size: 9, seed: `s${i}` });
    keys.add(p.words.map((w) => w.answer).sort().join('|'));
  }
  assert.ok(keys.size >= 45, `only ${keys.size}/50 distinct`);
});

for (const size of SIZES) {
  test(`property: 400 seeds at ${size}×${size} keep all invariants`, () => {
    let minWords = Infinity, total = 0;
    for (let i = 0; i < 400; i++) {
      const p = generate(BANK, { size, seed: `prop-${size}-${i}` });
      checkInvariants(p);
      minWords = Math.min(minWords, p.words.length);
      total += p.words.length;
    }
    console.log(`  size ${size}: min ${minWords} words, avg ${(total / 400).toFixed(1)}`);
    assert.ok(minWords >= MIN_WORDS[size], `min words ${minWords} < ${MIN_WORDS[size]}`);
  });
}

test('excluded words never appear', () => {
  const exclude = new Set(BANK.slice(0, 60).map((e) => e.id));
  for (let i = 0; i < 100; i++) {
    const p = generate(BANK, { size: 9, seed: `ex${i}`, exclude });
    for (const w of p.words) assert.ok(!exclude.has(w.id));
  }
});

test('clue and display travel with each placed word', () => {
  const p = generate(BANK, { size: 9, seed: 'clues' });
  const byId = new Map(BANK.map((e) => [e.id, e]));
  for (const w of p.words) {
    assert.equal(w.clue, byId.get(w.id)!.clue);
    assert.equal(w.display, byId.get(w.id)!.display);
  }
});

test('invalid input fails loudly, not silently', () => {
  assert.throws(() => generate([], { size: 9, seed: 'x' }), GeneratorError);
  assert.throws(() => generate(BANK, { size: 3, seed: 'x' }), GeneratorError);
  const bad: Entry[] = [{ id: 1, answer: 'H2O', display: 'H2O', clue: 'x', category: 'x', difficulty: 1 }];
  assert.throws(() => generate(bad, { size: 9, seed: 'x' }), GeneratorError);
});

test('performance: 9×9 average under 50 ms in Node (phone budget 500 ms)', () => {
  const t0 = performance.now();
  for (let i = 0; i < 100; i++) generate(BANK, { size: 9, seed: `perf${i}` });
  const avg = (performance.now() - t0) / 100;
  console.log(`  avg 9×9: ${avg.toFixed(2)} ms`);
  assert.ok(avg < 50);
});
