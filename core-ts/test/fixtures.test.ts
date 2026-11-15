import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { buildFixtures, FIXTURE_PATH } from '../scripts/fixtures.ts';

test('shared generator fixtures are up to date (run `npm run fixtures` after generator changes)', () => {
  assert.deepEqual(JSON.parse(readFileSync(FIXTURE_PATH, 'utf8')), JSON.parse(JSON.stringify(buildFixtures())));
});
