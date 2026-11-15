import 'dart:convert';

import 'package:almuhra_crossword/core/dates.dart';
import 'package:almuhra_crossword/main.dart';
import 'package:almuhra_crossword/models/puzzle.dart';
import 'package:almuhra_crossword/state/stats.dart';
import 'package:almuhra_crossword/storage/game_storage.dart';
import 'package:almuhra_crossword/widgets/crossword_grid.dart';
import 'package:almuhra_crossword/widgets/stats_sheet.dart';
import 'package:almuhra_crossword/widgets/victory_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final bank = loadTestBank();
  var t = DateTime(2026, 11, 15, 9);
  DateTime now() => t;
  setUp(() => t = DateTime(2026, 11, 15, 9));

  Future<void> pumpApp(
    WidgetTester tester,
    MemoryStore store, {
    Size size = const Size(360, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CrosswordApp(
      key: UniqueKey(),
      bank: bank,
      store: store,
      generator: syncGenerator,
      now: now,
    ));
    await tester.pump();
    await tester.pump();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  String buttonLabel(WidgetTester tester, String key) => tester
      .widget<Text>(find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Text),
      ).first)
      .data!;

  Finder inGrid(String text) => find.descendant(
        of: find.byType(CrosswordGrid),
        matching: find.text(text),
      );

  Puzzle savedPuzzle(MemoryStore store, String key) => Puzzle.fromJson(
        ((jsonDecode(store.data[key]!) as Map)['puzzle'] as Map)
            .cast<String, dynamic>(),
      );

  /// Fill every cell once: tap it in the grid, then tap its letter key.
  Future<void> solveOnScreen(WidgetTester tester, Puzzle puzzle) async {
    final grid = tester
        .getRect(find.byType(CrosswordGrid))
        .deflate(CrosswordGrid.boardPadding);
    final cell = grid.width / puzzle.size;
    for (final p in puzzle.whiteCells.toList()) {
      // RTL: logical column 0 is the right-most column.
      await tester.tapAt(Offset(
        grid.right - (p.col + 0.5) * cell,
        grid.top + (p.row + 0.5) * cell,
      ));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('key-${puzzle.solution![p]}')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the home screen, not on a puzzle', (tester) async {
    final store = MemoryStore();
    await pumpApp(tester, store);
    expect(tester.takeException(), isNull);
    expect(find.text('المُهرة'), findsOneWidget);
    expect(find.text('لغز اليوم'), findsOneWidget);
    expect(find.text('الأحد 15 تشرين الثاني 2026'), findsOneWidget);
    expect(find.text('وضع التدريب'), findsOneWidget);
    expect(buttonLabel(tester, 'daily-button'), 'ابدأ اللعب');
    expect(textOf(tester, 'streak'), '0');
    expect(find.byKey(const ValueKey('practice-continue')), findsNothing);
    expect(find.byType(CrosswordGrid), findsNothing);
    expect(store.data, isEmpty); // nothing is generated until asked
  });

  for (final size in const [Size(320, 568), Size(412, 915)]) {
    testWidgets('home fits ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
      await pumpApp(tester, MemoryStore(), size: size);
      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byKey(const ValueKey('practice-11')));
      expect(button.right, lessThanOrEqualTo(size.width));
      expect(button.left, greaterThanOrEqualTo(0));
    });
  }

  testWidgets('daily: start, play, go back, continue', (tester) async {
    final store = MemoryStore();
    await pumpApp(tester, store);
    await tester.tap(find.byKey(const ValueKey('daily-button')));
    await tester.pumpAndSettle();

    expect(find.byType(CrosswordGrid), findsOneWidget);
    expect(find.text('لغز اليوم'), findsOneWidget); // play screen title
    expect(find.byTooltip('لغز جديد'), findsNothing); // no skipping the daily
    final puzzle = savedPuzzle(store, dailySlot('2026-11-15'));
    expect(puzzle.size, 9);
    expect(puzzle.id, 'daily-2026-11-15');
    expect(store.data.containsKey(practiceSlot), isFalse);

    await tester.tap(find.byKey(const ValueKey('key-ض')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(CrosswordGrid), findsNothing);
    expect(buttonLabel(tester, 'daily-button'), 'استكمال اللغز');

    await tester.tap(find.byKey(const ValueKey('daily-button')));
    await tester.pumpAndSettle();
    expect(inGrid('ض'), findsOneWidget);
  });

  testWidgets('two players on the same day get the same daily puzzle',
      (tester) async {
    final a = MemoryStore();
    final b = MemoryStore();
    for (final store in [a, b]) {
      await pumpApp(tester, store);
      await tester.tap(find.byKey(const ValueKey('daily-button')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    }
    final key = dailySlot('2026-11-15');
    expect(savedPuzzle(a, key).toJson(), savedPuzzle(b, key).toJson());
  });

  testWidgets('solving the daily: copy result, completed card, streak, stats',
      (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final store = MemoryStore();
    await pumpApp(tester, store);
    await tester.tap(find.byKey(const ValueKey('daily-button')));
    await tester.pumpAndSettle();
    t = t.add(const Duration(seconds: 20));
    await solveOnScreen(tester, savedPuzzle(store, dailySlot('2026-11-15')));

    expect(find.byType(VictoryDialog), findsOneWidget);
    expect(textOf(tester, 'victory-time'), '00:20');
    expect(textOf(tester, 'victory-helpers'), '0');
    expect(find.text('لغز جديد'), findsNothing);

    await tester.tap(find.text('مشاركة النتيجة'));
    await tester.pump();
    await tester.pump();
    expect(find.text('تم النسخ، الصقها لأصدقائك'), findsOneWidget);
    expect(copied.length, 1);
    final lines = copied.single.split('\n');
    expect(lines[1], 'لغز اليوم #1 · 2026-11-15');
    expect(lines[2], 'الوقت 00:20 · المساعدات 0');
    expect(lines.length, 12);
    expect(copied.single.contains('🟩'), isTrue);
    expect(copied.single.contains('🟨'), isFalse);

    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(textOf(tester, 'daily-done'), 'مكتمل · 00:20');
    expect(buttonLabel(tester, 'daily-button'), 'عرض الشبكة');
    expect(textOf(tester, 'streak'), '1');

    await tester.tap(find.byTooltip('الإحصائيات'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsSheet), findsOneWidget);
    expect(textOf(tester, 'stat-الألغاز المحلولة'), '1');
    expect(textOf(tester, 'stat-ألغاز يومية'), '1');
    expect(textOf(tester, 'stat-السلسلة الحالية'), '1');
    expect(textOf(tester, 'stat-أفضل سلسلة'), '1');
    expect(textOf(tester, 'stat-بدون مساعدة'), '1');
    expect(textOf(tester, 'stat-أسرع 9×9'), '00:20');
    expect(textOf(tester, 'stat-أسرع 7×7'), '—');
  });

  testWidgets('a solved daily stays solved after restart; its grid can be viewed',
      (tester) async {
    final store = MemoryStore();
    await pumpApp(tester, store);
    await tester.tap(find.byKey(const ValueKey('daily-button')));
    await tester.pumpAndSettle();
    t = t.add(const Duration(seconds: 65));
    final puzzle = savedPuzzle(store, dailySlot('2026-11-15'));
    await solveOnScreen(tester, puzzle);
    await tester.pumpWidget(const SizedBox()); // app closed

    t = t.add(const Duration(hours: 3)); // same day, later
    await pumpApp(tester, store);
    expect(textOf(tester, 'daily-done'), 'مكتمل · 01:05');
    expect(textOf(tester, 'streak'), '1');

    await tester.tap(find.byKey(const ValueKey('daily-button')));
    await tester.pumpAndSettle();
    expect(find.byType(VictoryDialog), findsOneWidget);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    final firstLetter = puzzle.solution![puzzle.entries.first.start]!;
    expect(inGrid(firstLetter), findsWidgets);
    expect(
      jsonDecode(store.data[statsSlot]!)['totalSolved'],
      1,
    ); // viewing again does not count twice
  });

  testWidgets('next day: new puzzle, streak alive; after a missed day it is 0',
      (tester) async {
    final store = MemoryStore();
    store.data[statsSlot] = jsonEncode(const PlayerStats(
      totalSolved: 3,
      dailySolved: 3,
      currentStreak: 3,
      bestStreak: 3,
      lastDailyDate: '2026-11-15',
    ).toJson());

    t = DateTime(2026, 11, 16, 8);
    await pumpApp(tester, store);
    expect(find.text(formatArabicDate('2026-11-16')), findsOneWidget);
    expect(buttonLabel(tester, 'daily-button'), 'ابدأ اللعب');
    expect(textOf(tester, 'streak'), '3');
    await tester.pumpWidget(const SizedBox());

    t = DateTime(2026, 11, 18, 8);
    await pumpApp(tester, store);
    expect(textOf(tester, 'streak'), '0');
  });

  testWidgets('midnight passes while the app is open: the card moves to the new day',
      (tester) async {
    t = DateTime(2026, 11, 15, 23, 50);
    await pumpApp(tester, MemoryStore());
    expect(find.text(formatArabicDate('2026-11-15')), findsOneWidget);

    t = DateTime(2026, 11, 16, 0, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text(formatArabicDate('2026-11-16')), findsOneWidget);
  });

  testWidgets('practice: pick a size, play, go back, continue, replace',
      (tester) async {
    final store = MemoryStore();
    await pumpApp(tester, store);
    await tester.tap(find.byKey(const ValueKey('practice-9')));
    await tester.pumpAndSettle();
    expect(find.text('تدريب 9×9'), findsOneWidget);
    expect(store.data.keys.any((k) => k.startsWith(dailySlotPrefix)), isFalse);

    await tester.tap(find.byKey(const ValueKey('key-ض')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(buttonLabel(tester, 'practice-continue'),
        startsWith('استكمال التدريب · 9×9'));

    // Another size while a puzzle is in progress: asks first.
    await tester.tap(find.byKey(const ValueKey('practice-7')));
    await tester.pumpAndSettle();
    expect(find.text('سيُحذف تقدمك في لغز التدريب الحالي.'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.byType(CrosswordGrid), findsNothing);

    await tester.tap(find.byKey(const ValueKey('practice-continue')));
    await tester.pumpAndSettle();
    expect(find.text('تدريب 9×9'), findsOneWidget);
    expect(inGrid('ض'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ لغزاً جديداً'));
    await tester.pumpAndSettle();
    expect(find.text('تدريب 7×7'), findsOneWidget);
    expect(inGrid('ض'), findsNothing);
  });

  testWidgets('practice game survives closing the app', (tester) async {
    final store = MemoryStore();
    await pumpApp(tester, store);
    await tester.tap(find.byKey(const ValueKey('practice-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('key-ض')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox()); // closed from the play screen

    await pumpApp(tester, store);
    expect(buttonLabel(tester, 'practice-continue'),
        startsWith('استكمال التدريب · 7×7'));
    await tester.tap(find.byKey(const ValueKey('practice-continue')));
    await tester.pumpAndSettle();
    expect(inGrid('ض'), findsOneWidget);
  });

  testWidgets('the timer runs on the play screen only', (tester) async {
    String timer() =>
        tester.widget<Text>(find.byKey(const ValueKey('timer'))).data!;
    await pumpApp(tester, MemoryStore());
    await tester.tap(find.byKey(const ValueKey('practice-7')));
    await tester.pumpAndSettle();

    t = t.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(timer(), '00:10');

    await tester.pageBack();
    await tester.pumpAndSettle();
    t = t.add(const Duration(seconds: 100)); // waiting on the home screen
    expect(buttonLabel(tester, 'practice-continue'), endsWith('00:10'));

    await tester.tap(find.byKey(const ValueKey('practice-continue')));
    await tester.pumpAndSettle();
    expect(timer(), '00:10');
    t = t.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(timer(), '00:15');

    // App in the background stops it too.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t = t.add(const Duration(seconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(timer(), '00:15');
  });

  testWidgets('theme toggle cycles, applies and is remembered', (tester) async {
    ThemeMode mode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    final store = MemoryStore();
    await pumpApp(tester, store);
    expect(mode(), ThemeMode.system);
    expect(find.byTooltip('المظهر: تلقائي'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pump();
    await tester.pump();
    expect(mode(), ThemeMode.light);
    expect(store.data[themeSlot], 'light');
    expect(find.byTooltip('المظهر: فاتح'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pump();
    await tester.pump();
    expect(mode(), ThemeMode.dark);
    await tester.pumpAndSettle(); // the theme change is animated
    expect(Theme.of(tester.element(find.text('وضع التدريب'))).brightness,
        Brightness.dark);

    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, store);
    expect(mode(), ThemeMode.dark);
  });
}
