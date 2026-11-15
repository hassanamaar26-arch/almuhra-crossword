import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { generate, type Entry } from '../src/generator.ts';
import { bankProblems, clueLeaksAnswer, BANK_MIN_LEN, BANK_MAX_LEN } from '../src/bank_check.ts';
import { normalize, ALPHABET } from '../src/normalize.ts';

const BANK: Entry[] = JSON.parse(
  readFileSync(new URL('../../words/bank_v1.json', import.meta.url), 'utf8'),
);
const e = (over: Partial<Entry>): Entry => ({
  id: 1, answer: 'بغداد', display: 'بغداد', clue: 'عاصمة العراق', category: 'جغرافيا', difficulty: 1, ...over,
});

test('the checker catches each kind of mistake', () => {
  assert.deepEqual(bankProblems([e({})]), []);
  const bad = (entries: Entry[], needle: string) =>
    assert.ok(bankProblems(entries).some((p) => p.includes(needle)), needle);
  bad([e({}), e({})], 'duplicate id');
  bad([e({}), e({ id: 2, answer: 'بَغْدَاد' })], 'same answer');
  bad([e({ answer: 'أنقرة', display: 'أنقرة' }), e({ id: 2, answer: 'انقره', display: 'انقره' })], 'same answer');
  bad([e({ answer: 'ما', display: 'ما' })], 'length 2');
  bad([e({ answer: 'اينشتاين', display: 'اينشتاين' })], 'length 8');
  bad([e({ answer: 'ابن سينا', display: 'ابن سينا' })], 'space');
  bad([e({ answer: 'H2O', display: 'H2O' })], 'not on the keyboard');
  bad([e({ display: 'دمشق' })], 'display');
  bad([e({ clue: 'مدينة بغداد' })], 'reveals');
  bad([e({ clue: '' })], 'clue length');
  bad([e({ answer: 'شوقي', display: 'أحمد شوقي', clue: 'أمير الشعراء' })], 'compound name');
  assert.deepEqual(bankProblems([e({ answer: 'شوقي', display: 'أحمد شوقي', clue: 'أحمد ___، أمير الشعراء' })]), []);
  bad([e({ category: 'x' })], 'category');
  bad([e({ difficulty: 4 })], 'difficulty');
});

test('clue leak detection: whole word, with prefixes, inside longer words', () => {
  assert.equal(clueLeaksAnswer('نهر النيل العظيم', 'نيل'), true);
  assert.equal(clueLeaksAnswer('يصب في النيل', 'نيل'), true);
  assert.equal(clueLeaksAnswer('نسبة للنيل وبالنيل', 'نيل'), true);
  assert.equal(clueLeaksAnswer('تُنسب إليه الخوارزميات', 'خوارزمي'), true);
  assert.equal(clueLeaksAnswer('عاصمة أَنْقَرَة', 'أنقرة'), true);
  assert.equal(clueLeaksAnswer('أطول أنهار أفريقيا', 'نيل'), false);
  assert.equal(clueLeaksAnswer('شجرة النخيل', 'نيل'), false); // short answers: whole words only
});

test('bank_v1.json passes every rule', () => {
  const problems = bankProblems(BANK);
  assert.deepEqual(problems, [], problems.join('\n'));
});

test('bank size and shape suit the generator', () => {
  assert.ok(BANK.length >= 500, `only ${BANK.length} words`);
  const byLen = new Map<number, number>();
  const byLetter = new Map<string, number>();
  for (const w of BANK) {
    const letters = [...normalize(w.answer)];
    byLen.set(letters.length, (byLen.get(letters.length) ?? 0) + 1);
    for (const l of new Set(letters)) byLetter.set(l, (byLetter.get(l) ?? 0) + 1);
  }
  for (let n = BANK_MIN_LEN; n <= BANK_MAX_LEN; n++) {
    assert.ok((byLen.get(n) ?? 0) >= 30, `only ${byLen.get(n) ?? 0} words of length ${n}`);
  }
  const short = [3, 4, 5].reduce((s, n) => s + (byLen.get(n) ?? 0), 0);
  assert.ok(short / BANK.length >= 0.6, 'words of 3–5 letters must be the backbone');
  for (const l of ALPHABET) {
    assert.ok((byLetter.get(l) ?? 0) >= 8, `letter ${l} appears in only ${byLetter.get(l) ?? 0} words`);
  }
});

const TARGET: Record<number, number> = { 7: 8, 9: 12, 11: 16 };
for (const size of [7, 9, 11]) {
  test(`stress: 50 puzzles in a row at ${size}×${size}, never repeating the last 5 puzzles' words`, () => {
    const limit = Math.floor(BANK.length * 0.4);
    let recent: number[][] = []; // newest first, like PracticeSession
    const everUsed = new Set<number>();
    for (let i = 0; i < 50; i++) {
      const exclude = new Set<number>();
      for (const ids of recent) {
        if (exclude.size + ids.length > limit) break;
        for (const id of ids) exclude.add(id);
      }
      const p = generate(BANK, { size, seed: `stress-${size}-${i}`, exclude });
      assert.equal(p.words.length, TARGET[size], `puzzle ${i} placed ${p.words.length} words`);
      const ids = p.words.map((w) => w.id);
      for (const id of ids) {
        assert.ok(!exclude.has(id), `puzzle ${i} repeated word ${id}`);
        everUsed.add(id);
      }
      recent = [ids, ...recent].slice(0, 5);
      assert.equal(new Set(recent.flat()).size, recent.flat().length, 'last 5 puzzles share no word');
    }
    console.log(`  size ${size}: ${everUsed.size} different words used in 50 puzzles`);
  });
}
