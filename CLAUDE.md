# الكلمات المتقاطعة (المُهرة)
Read SPEC.md, PLAN.md, ASSUMPTIONS.md first.
## Commands
- Core (TS, generator + normalizer): `cd core-ts && npm test`
- Flutter app: built/tested on GitHub Actions (no Flutter SDK in this workspace)
## Rules
- Generator TS and Dart ports must produce identical puzzles for same seed (fixtures).
- Word bank: words/bank_v1.json; answers without «ال» unless part of the name; Hasan reviews every batch.
- Never put daily-puzzle answers in client-readable places.
