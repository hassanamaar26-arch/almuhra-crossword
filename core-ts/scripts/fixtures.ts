// Builds the shared fixtures that pin the TS and Dart generators together.
import { readFileSync } from 'node:fs';
import { generate, type Entry } from '../src/generator.ts';
import { toFullJson } from '../src/puzzle_json.ts';
import { Rng } from '../src/rng.ts';

export const FIXTURE_PATH = new URL('../../test/fixtures/generator_fixtures.json', import.meta.url);

const CASES: { size: number; seed: string; exclude: number[] }[] = [
  { size: 7, seed: '7b', exclude: [] },
  { size: 7, seed: '2026-11-15', exclude: [] },
  { size: 7, seed: 'لغز-١', exclude: [] },
  { size: 7, seed: 'ex', exclude: [1, 2, 3, 19, 20, 38, 49, 50, 95, 96] },
  { size: 9, seed: '2026-11-15', exclude: [] },
  { size: 9, seed: 'a', exclude: [] },
  { size: 9, seed: 'المهرة', exclude: [] },
  { size: 9, seed: 'ex9', exclude: Array.from({ length: 40 }, (_, i) => i + 1) },
  { size: 11, seed: '2026-11-15', exclude: [] },
  { size: 11, seed: 'big', exclude: [] },
  { size: 11, seed: '', exclude: [] },
  { size: 11, seed: '1763164800000-12345', exclude: [5, 6, 7] },
];

export function buildFixtures() {
  const bank: Entry[] = JSON.parse(
    readFileSync(new URL('../../words/bank_v1.json', import.meta.url), 'utf8'),
  );
  return {
    rng: ['', 'a', '7b#0', 'لغز-١', '2026-11-15#3'].map((seed) => {
      const r = new Rng(seed);
      return { seed, values: Array.from({ length: 6 }, () => r.next()) };
    }),
    cases: CASES.map((c) => ({
      ...c,
      json: toFullJson(
        generate(bank, { size: c.size, seed: c.seed, exclude: new Set(c.exclude) }),
        `practice-${c.size}-${c.seed}`,
      ),
    })),
  };
}
