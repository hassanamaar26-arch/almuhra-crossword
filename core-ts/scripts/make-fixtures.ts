import { writeFileSync } from 'node:fs';
import { buildFixtures, FIXTURE_PATH } from './fixtures.ts';
writeFileSync(FIXTURE_PATH, JSON.stringify(buildFixtures(), null, 1) + '\n');
console.log('fixtures written');
