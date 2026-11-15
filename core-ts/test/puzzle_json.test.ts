import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { generate, type Entry } from '../src/generator.ts';
import { toFullJson, toClientJson } from '../src/puzzle_json.ts';

const BANK: Entry[] = JSON.parse(readFileSync(new URL('../../words/bank_v1.json', import.meta.url), 'utf8'));

test('full JSON: grid rows, numbers and lengths are consistent', () => {
  const p = generate(BANK, { size: 7, seed: '7b' });
  const j = toFullJson(p, 'practice-7b');
  assert.equal(j.grid.length, 7);
  for (const row of j.grid) assert.equal([...row].length, 7);
  for (const e of j.entries) {
    assert.equal(e.length, [...e.answer!].length);
    assert.ok(j.numbers.some(([r, c, n]) => r === e.row && c === e.col && n === e.number));
  }
});

test('client JSON: same shape, mask only, no answers anywhere (200 seeds)', () => {
  for (let i = 0; i < 200; i++) {
    const p = generate(BANK, { size: 9, seed: `mask${i}` });
    const full = toFullJson(p, 'x');
    const client = toClientJson(p, 'x');
    client.grid.forEach((row, r) => {
      assert.match(row, /^[#.]+$/);
      [...row].forEach((ch, c) => assert.equal(ch === '#', [...full.grid[r]][c] === '#'));
    });
    assert.deepEqual(client.numbers, full.numbers);
    client.entries.forEach((e, k) => {
      assert.equal('answer' in e, false);
      assert.equal('display' in e, false);
      assert.equal(e.length, full.entries[k].length);
    });
    const text = JSON.stringify({ ...client, entries: client.entries.map(({ clue, ...rest }) => rest) });
    assert.doesNotMatch(text, /[ء-ي]/, 'no Arabic letters outside clues');
  }
});
