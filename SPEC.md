# SPEC — Arabic Crossword (Android, Flutter)

App name: **الكلمات المتقاطعة (المُهرة)**

## 1. Goal
A polished Arabic general-knowledge crossword game for the public. Classic grid
(across/down) with clues, endless puzzles generated from a curated word bank,
plus a shared **Daily Puzzle** with a global leaderboard.

## 2. Users
General Arabic-speaking public, Android phones (min 360 px width), mixed
connectivity (Iraq) — the game must stay playable offline.

## 3. Pinned stack
| Layer | Choice |
|---|---|
| App | Flutter (stable), Dart, Android first (minSdk 23) |
| State | Riverpod |
| Local storage | Drift (SQLite) — progress, word bank, cached daily puzzles |
| Auth | Supabase Auth — Google Sign-In + Guest (anonymous sign-in, upgradable) |
| Online data | Supabase Postgres with Row Level Security (free tier) |
| Anti-cheat / scoring | Supabase Edge Function `submit-daily` (server verifies answers + timing) |
| Daily puzzle job | pg_cron in Supabase creates tomorrow's daily puzzle |
| Fonts | Bundled Arabic font (e.g. Cairo / Tajawal / IBM Plex Sans Arabic) |
| Tests | flutter_test, unit tests for generator, integration tests on emulator |

## 4. MVP features + acceptance criteria

### F1 — Word bank
- Bundled JSON → imported into SQLite on first launch: `word`, `clue`,
  `category`, `difficulty (1–3)`.
- Target ≥ 1,000 entries at launch, Arabic only, general culture
  (geography, history, science, Islam & Arab heritage, sports, literature).
- ✓ Every word stored in **normalized form** (see §7) and length 2–10.
- ✓ No duplicate (word, clue) pairs.

### F2 — Puzzle generator
- Builds a valid RTL grid (sizes: 7×7 easy, 9×9 medium, 11×11 hard).
- ✓ Every placed word is a real bank word; every crossing letter matches.
- ✓ No two-letter accidental words formed by adjacency.
- ✓ Deterministic from a seed (same seed → identical puzzle).
- ✓ Generates a 9×9 puzzle in < 500 ms on a mid-range phone.
- ✓ Does not repeat a word the player saw in their last 5 puzzles.

### F3 — Play screen (classic)
- Grid right-to-left; across clues read right→left, down clues top→bottom.
- Tap cell → select word; tap again → toggle direction.
- Custom Arabic on-screen keyboard (28 letters + ء + ى + delete);
  no system keyboard.
- Clue bar above keyboard; full clue list (أفقي / عمودي) in a sheet.
- Helpers: check letter, check word, reveal letter (limited per puzzle).
- ✓ Letters render isolated, centered, readable at 360 px.
- ✓ Completing the grid correctly shows a result screen (time, helpers used).
- ✓ Progress auto-saves every input; killing the app resumes exactly.

### F4 — Practice mode (offline)
- Choose difficulty → endless generated puzzles.
- ✓ Works with airplane mode on from first launch onward.

### F5 — Accounts
- First launch: play as Guest immediately (anonymous auth when online,
  local-only when offline).
- Optional Google Sign-In; guest progress is linked, not lost.
- Display name (Arabic allowed, 3–20 chars, profanity filter).
- ✓ Signing in on a second phone restores stats.

### F6 — Daily Puzzle + Leaderboard
- One puzzle per day, same for everyone, seeded by date (Asia/Baghdad day).
- Score = based on time + penalty per helper used.
- Leaderboards: Today, This week, All-time (total solved daily puzzles).
- ✓ One ranked submission per user per day (retries are unranked).
- ✓ Server recomputes the score; client-sent score is ignored.
- ✓ Daily puzzle downloadable/playable offline; result submitted when back online.

### F7 — Stats & settings
- Stats: solved count, streak, average time per difficulty.
- Settings: dark/light/system theme, sound on/off, font size, reset progress.

## 5. Out of scope (v1)
iOS release, ads/in-app purchases, multiplayer duels, user-submitted puzzles,
push notifications, other languages, English UI.

## 6. Data model
**Local (SQLite)**
- `words(id PK, word TEXT NOT NULL, display TEXT NOT NULL, clue TEXT NOT NULL,
  category TEXT NOT NULL, difficulty INT NOT NULL CHECK 1..3,
  UNIQUE(word, clue))`
- `puzzles(id PK, seed TEXT UNIQUE NOT NULL, mode TEXT NOT NULL
  CHECK in ('practice','daily'), size INT NOT NULL, layout_json TEXT NOT NULL,
  created_at INT NOT NULL)`
- `progress(puzzle_id FK UNIQUE NOT NULL, cells_json TEXT NOT NULL,
  elapsed_ms INT NOT NULL, helpers_used INT NOT NULL DEFAULT 0,
  completed_at INT NULL)`
- `pending_submissions(day TEXT UNIQUE NOT NULL, payload_json TEXT NOT NULL)`

**Supabase (Postgres)**
- `profiles(id uuid PK → auth.users, display_name text NOT NULL CHECK 3..20,
  total_daily_solved int NOT NULL DEFAULT 0, streak int NOT NULL DEFAULT 0, created_at)`
- `daily_puzzles(day date PK, layout jsonb NOT NULL)` — client JSON: grid mask (`#` black, `.` empty), numbers, entries with `length` + clue, no answers; readable by all.
- `daily_answers(day date PK → daily_puzzles, answers jsonb NOT NULL)` — **no client access** (RLS deny all).
- `daily_starts(day, user_id, started_at, PK(day,user_id))` — server time when the player opened the daily puzzle.
- `daily_scores(day, user_id, score int, time_ms int, helpers int, submitted_at,
  PK(day,user_id))` — written only by the Edge Function (service role).
- Views: `leaderboard_today`, `leaderboard_week`, `leaderboard_all_time`.
- RLS: clients read leaderboards and their own profile; only the Edge Function writes scores.

## 7. Arabic text rules (must-handle)
- Normalization for grid letters: `أ إ آ ٱ → ا`, strip tashkeel and tatweel.
- `ة → ه` in the grid; `ء` and `ى` kept as distinct letters (shown on keyboard).
- Words without the definite article «ال» unless it is part of the name.
- Grid shows isolated letter forms; clue text shows the full display word only after solving.

## 8. Edge cases
- App killed mid-puzzle → resume same cells + time.
- Clock changed on device → daily day comes from server when online.
- Double-tap "submit" / network retry → single ranked score (doc id = uid).
- Midnight rollover while playing the daily puzzle → still counts for the day it was started.
- Guest plays offline for days then signs in → local stats merge, no duplicates.
- Generator fails to fill a grid → retry with new sub-seed, max N, then smaller layout.
- Very long display names / Arabic + digits mixed → no layout break.

## 9. Commands
```
flutter pub get
flutter test
flutter run
flutter build apk --release
supabase db push
supabase functions deploy submit-daily
```

## 10. Boundaries
- **ALWAYS**: tests before code for generator & scoring; RTL check at 360 px; light + dark screenshots.
- **ASK FIRST**: new dependencies, schema changes, deleting files, any paid plan.
- **NEVER**: ship daily-puzzle answers in the app bundle or any client-readable table; trust client scores; commit the Supabase service-role key.

## 11. Definition of done (v1)
All F1–F7 acceptance criteria ✓ with evidence, generator property tests green,
release APK installs on a real phone, offline practice verified in airplane mode,
leaderboard submission verified with two accounts, privacy policy page live.

## 12. Decisions
1. Name: الكلمات المتقاطعة (المُهرة). Icon: TBD.
2. Clues: no external source — Claude drafts the bank, Hasan reviews in batches of 100.
3. Backend: Supabase free tier (no payment card). Hasan creates the project with his Google account.
