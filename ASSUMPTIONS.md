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
