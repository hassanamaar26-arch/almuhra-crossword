import { writeFileSync } from 'node:fs';
import { buildFixtures, FIXTURE_PATH } from './fixtures.ts';
import { buildWebParityDart, WEB_PARITY_PATH } from './web-parity.ts';
writeFileSync(FIXTURE_PATH, JSON.stringify(buildFixtures(), null, 1) + '\n');
writeFileSync(WEB_PARITY_PATH, buildWebParityDart());
console.log('fixtures written');
