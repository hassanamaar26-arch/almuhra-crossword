# PLAN — الكلمات المتقاطعة (المُهرة)

## 1. Project structure
```
almuhra_crossword/
  lib/
    core/arabic/normalize.dart        # hamza/tashkeel rules (§7 SPEC)
    core/generator/                   # pure Dart, no Flutter imports
      grid.dart  placer.dart  generator.dart  seed_rng.dart
    data/local/  (Drift db, DAOs, word-bank importer)
    data/remote/ (Supabase client, daily + leaderboard repos)
    features/
      play/        grid widget, arabic keyboard, clue bar, helpers
      practice/    difficulty picker → endless puzzles
      daily/       daily puzzle, result, pending-submit queue
      leaderboard/ today / week / all-time tabs
      account/     guest, Google link, display name
      stats_settings/
    app.dart  main.dart  theme.dart (RTL, light/dark)
  assets/words/bank_v1.json
  supabase/
    migrations/  functions/submit-daily/  seed/
  test/ (unit + property tests)   integration_test/
  CLAUDE.md  SPEC.md  ASSUMPTIONS.md
```

## 2. Data flow
- **Practice**: bank (SQLite) → generator(seed) → puzzle row → play → progress saved on every keystroke → result → local stats.
- **Daily**: open → fetch `daily_puzzles[day]` (cache locally) → server records `daily_starts` →
  play (works offline) → on finish, payload `{day, cells, helpers}` goes to
  `pending_submissions` → sync worker calls Edge Function `submit-daily` →
  function compares cells with `daily_answers`, computes time from
  `daily_starts` (server clock), upserts `daily_scores` once → leaderboard views.
- **Daily creation**: pg_cron at 23:00 Baghdad runs the same generator logic (TypeScript port, tested against the Dart version with shared seed fixtures) and fills `daily_puzzles` + `daily_answers`.

## 3. Dependencies (each justified)
| Package | Why |
|---|---|
| flutter_riverpod | state, testable providers |
| drift + sqlite3_flutter_libs | typed SQLite with migrations and constraints |
| supabase_flutter | auth + DB + function calls in one SDK |
| google_sign_in | native Google login for Supabase |
| connectivity_plus | trigger pending-submission sync when online |
| google_fonts (bundled offline) or asset font | Arabic font that works offline |
Nothing else without asking.

## 4. Milestones (each shippable + tested)
| # | Milestone | Done when |
|---|---|---|
| M1 | Arabic normalizer + generator (pure Dart) | property tests: all crossings match, no stray words, deterministic, <500 ms |
| M2 | Word bank v1 (first 300 clues) + importer | Hasan reviewed batch 1–3; import idempotent |
| M3 | Play screen: grid, keyboard, clues, RTL | screenshots 360 px light/dark; tap/direction logic tested |
| M4 | Practice mode + autosave/resume + helpers | kill app mid-puzzle → resumes exactly |
| M5 | Stats + settings + theme | stats correct after 3 test puzzles |
| M6 | Supabase: schema, RLS, auth (guest + Google) | RLS tests: client cannot read answers or write scores |
| M7 | Daily puzzle + Edge Function + pending queue | two accounts submit; double submit = one score; offline submit syncs later |
| M8 | Leaderboards | today/week/all-time ranks match DB |
| M9 | Word bank to 1,000+, polish, icon | Hasan approved all batches |
| M10 | Break-it, security, pre-launch audit | Phases 6–8 PASS |

**Offline practice playable after M4** — you can install and test from then.

## 5. Top production risks
| Risk | Prevention |
|---|---|
| Leaderboard cheating (fake times/answers) | answers only server-side; time measured by server (`daily_starts` → submit); score computed in function |
| Arabic letters break (hamza, ة/ه, ى/ي mismatch) | one normalizer used everywhere + tests for every letter form; keyboard shows only normalized letters |
| Generator produces bad or stuck grids | property tests on 10k seeds; retry with sub-seed; fallback to smaller layout |
| Lost progress (app killed, update) | save every input in SQLite transaction; migration tests v1→v2 |
| Supabase free project pauses after ~1 week of no activity | daily pg_cron job + app traffic keep it active; app still fully playable offline if backend is down |

## 6. Open decisions (need your answer)
1. **Clue style**: short newspaper style ("عاصمة فرنسا") or slightly playful ("مدينة النور")? Mix?
2. **Score formula**: proposed `score = 10000 − seconds×2 − helpers×300` (min 0). OK?
3. **Display names**: allow any Arabic name, or name + random number (e.g. حسن#4821) to avoid duplicates?
