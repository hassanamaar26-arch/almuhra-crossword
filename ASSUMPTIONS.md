# ASSUMPTIONS (Hasan said "ما تراه مناسبا" — Claude decided)

1. Clue style: mostly direct newspaper style (~80%, "عاصمة فرنسا"),
   ~20% light wordplay ("مدينة النور"). Every clue has exactly one answer.
2. Score: `score = max(0, 10000 − seconds×2 − helpers×300)`; ties → earlier submit wins.
3. Display names: name + 4-digit tag (حسن#4821), tag assigned by server, unique pair.
4. Letters: hamza seats normalized (أ إ آ ٱ → ا, ؤ → و, ئ → ي) and ة → ه (Hasan's
   decision, 2026-11-15); ء and ى kept as own letters.
   Keyboard = 28 letters + ء + ى (30 keys). Tashkeel and tatweel stripped.
5. Grid style: free-form (mobile friendly, black cells around words), not
   dense newspaper grid. Words never touch side-by-side unless crossing.
6. Generator source of truth is shared: TypeScript version (server, daily puzzle)
   and Dart version (app) must give identical grids for the same seed,
   proven by shared fixture files in CI.
7. Build/test of the Flutter app runs on GitHub Actions (this workspace cannot
   download the Flutter SDK). Same flow as Hasan's earlier apps.
8. Day boundary for the daily puzzle = midnight Asia/Baghdad.
9. App state: plain ChangeNotifier controller with immutable state (no Riverpod yet —
   no extra dependency needed for the play screen).
10. Practice mode keeps ONE current game, saved as a JSON string in shared_preferences
    behind the injectable GameStorage interface (Drift/SQLite deferred until stats need it).
    Saved on every step, every 5 s while the clock runs, and when the app is paused.
11. New practice puzzles avoid the words of the last 5 puzzles, capped at 40% of the
    bank so the generator keeps enough words (bank is still small).
12. Tapping "new puzzle" on a puzzle in progress asks for confirmation first.
13. Background generation uses `compute` (isolate on phones, inline on web) instead of
    Isolate.run, which does not compile for web.
14. Word bank rules (2026-11-15): answers are 3–7 letters after normalization, unique,
    never revealed by their own clue; checked by core-ts/test/bank.test.ts and
    test/bank_test.dart. The two 8-letter answers of batch 1 (ids 65, 94) were removed.
    New category «فن» (music and arts).
15. UI (2026-11-15 redesign): colors live in lib/theme.dart (CrosswordPalette, dark slate /
    light paper); font Cairo (OFL, bundled in assets/fonts). The letter "pop" uses a
    ScaleTransition driven by an AnimationController, not a timer, so nothing stays pending.
16. "مشاركة النتيجة" copies the result text to the clipboard (no share-sheet plugin).
17. Release signing: keystore and passwords come only from repository secrets
    (KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD); nothing secret is in the
    repo. tool/android_setup.sh patches the generated android/ folder in CI. Without the
    secrets the build still works but uses the temporary debug key.
18. Web: .github/workflows/pages.yml deploys to GitHub Pages (needs Pages source =
    "GitHub Actions" once). test/web_parity_test.dart runs in Chrome in CI.
