import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalize, toLetters, ALPHABET, isValidAnswer } from '../src/normalize.ts';

test('hamza seats on alef become plain alef', () => {
  assert.equal(normalize('أإآٱ'), 'اااا');
});

test('hamza on waw / ya becomes waw / ya', () => {
  assert.equal(normalize('مؤمن'), 'مومن');
  assert.equal(normalize('رئيس'), 'رييس');
});

test('ta marbuta becomes ha; standalone hamza and alef maqsura are kept', () => {
  assert.equal(normalize('سماء'), 'سماء');
  assert.equal(normalize('دجلة'), 'دجله');
  assert.equal(normalize('مصطفى'), 'مصطفى');
});

test('tashkeel, tatweel and spaces are removed', () => {
  assert.equal(normalize('عَمّـــان'), 'عمان');
  assert.equal(normalize('قُرْآن'), 'قران');
  assert.equal(normalize(' بغداد '), 'بغداد');
});

test('toLetters splits into single code points', () => {
  assert.deepEqual(toLetters('نيل'), ['ن', 'ي', 'ل']);
});

test('alphabet has 30 keys and every letter is one code point', () => {
  assert.equal(ALPHABET.length, 30);
  assert.equal(new Set(ALPHABET).size, 30);
  for (const l of ALPHABET) assert.equal([...l].length, 1);
});

test('isValidAnswer rejects latin, digits, too short/long, internal spaces', () => {
  assert.equal(isValidAnswer('بغداد'), true);
  assert.equal(isValidAnswer('H2O'), false);
  assert.equal(isValidAnswer('ب'), false);
  assert.equal(isValidAnswer('ابن سينا'), false);
  assert.equal(isValidAnswer('ابجدهوزحطي'), true); // 10 letters = max
  assert.equal(isValidAnswer('ابجدهوزحطيك'), false); // 11 letters
  assert.equal(isValidAnswer(''), false);
});
