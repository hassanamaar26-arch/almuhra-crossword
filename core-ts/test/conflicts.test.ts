import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { generate, type Entry } from '../src/generator.ts';
import { buildConflicts, clueLeaksAnswer } from '../src/conflicts.ts';

const BANK: Entry[] = JSON.parse(
  readFileSync(new URL('../../words/bank_v1.json', import.meta.url), 'utf8'),
);
const w = (id: number, answer: string, clue: string) => ({ id, answer, clue });
const pairs = (m: Map<number, Set<number>>) =>
  [...m].flatMap(([a, set]) => [...set].map((b) => `${a}-${b}`)).sort();

test('conflict map: bare word, «ال», attached particles, both directions', () => {
  const m = buildConflicts([
    w(1, 'بغداد', 'عاصمة العراق'),
    w(2, 'عراق', 'بلاد الرافدين'),
    w(3, 'نيل', 'أطول أنهار أفريقيا'),
    w(4, 'مصر', 'هبة النيل'),
    w(5, 'قمح', 'يُصنع منه الخبز'),
    w(6, 'خبز', 'يُعجن بالقمح وللخبز فرن'), // «للخبز» is its own answer: ignored
    w(7, 'نخيل', 'شجر التمر'),
  ]);
  assert.deepEqual(pairs(m), ['1-2', '2-1', '3-4', '4-3', '5-6', '6-5']);
});

test('conflict map: long answers also match inside longer clue words', () => {
  const m = buildConflicts([
    w(1, 'خوارزمي', 'مؤسس الجبر'),
    w(2, 'حاسوب', 'ينفّذ الخوارزميات'),
    w(3, 'نيل', 'نهر'),
    w(4, 'نخلة', 'من النخيل'), // «نيل» is short: not matched inside «النخيل»
  ]);
  assert.deepEqual(pairs(m), ['1-2', '2-1']);
});

test('conflict map equals the pairwise reference rule on the whole bank', () => {
  const expected: string[] = [];
  for (const a of BANK) {
    for (const b of BANK) {
      if (a.id !== b.id && (clueLeaksAnswer(a.clue, b.answer) || clueLeaksAnswer(b.clue, a.answer))) {
        expected.push(`${a.id}-${b.id}`);
      }
    }
  }
  const got = pairs(buildConflicts(BANK));
  assert.deepEqual(got, expected.sort());
  assert.ok(got.length > 1000, `${got.length} directed pairs`);
});

for (const size of [7, 9, 11]) {
  test(`no puzzle holds a word named by another word's clue (300 seeds, ${size}×${size})`, () => {
    for (let i = 0; i < 300; i++) {
      const p = generate(BANK, { size, seed: `cc-${size}-${i}` });
      for (const a of p.words) {
        for (const b of p.words) {
          if (a.id !== b.id) {
            assert.equal(clueLeaksAnswer(a.clue, b.answer), false,
              `seed ${i}: «${a.clue}» names «${b.answer}»`);
          }
        }
      }
    }
  });
}
