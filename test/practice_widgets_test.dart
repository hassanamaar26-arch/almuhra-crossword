import 'dart:convert';

import 'package:almuhra_crossword/core/generator/generator.dart';
import 'package:almuhra_crossword/models/puzzle.dart';
import 'package:almuhra_crossword/sample_puzzle.dart';
import 'package:almuhra_crossword/screens/play_screen.dart';
import 'package:almuhra_crossword/state/crossword_controller.dart';
import 'package:almuhra_crossword/widgets/arabic_keyboard.dart';
import 'package:almuhra_crossword/widgets/crossword_grid.dart';
import 'package:almuhra_crossword/widgets/victory_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

CrosswordController sampleController() => CrosswordController(
      Puzzle.fromJson(jsonDecode(samplePuzzleJson) as Map<String, dynamic>),
    );

void setScreen(WidgetTester tester, [Size size = const Size(360, 640)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpPlay(
  WidgetTester tester,
  CrosswordController c, {
  ValueNotifier<Duration>? elapsed,
  void Function(int)? onNewPuzzle,
  Size size = const Size(360, 640),
  String title = 'تدريب 7×7',
}) async {
  setScreen(tester, size);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: PlayScreen(
      controller: c,
      title: title,
      elapsed: elapsed,
      onNewPuzzle: onNewPuzzle,
    ),
  ));
}

Finder inGrid(String text) => find.descendant(
      of: find.byType(CrosswordGrid),
      matching: find.text(text),
    );

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String timerText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('timer'))).data!;

void main() {
  final bank = loadTestBank();

  group('timer', () {
    testWidgets('shows mm:ss and follows the clock', (tester) async {
      final elapsed = ValueNotifier(Duration.zero);
      await pumpPlay(tester, sampleController(), elapsed: elapsed);
      expect(timerText(tester), '00:00');
      elapsed.value = const Duration(seconds: 75);
      await tester.pump();
      expect(timerText(tester), '01:15');
    });

    testWidgets('no timer without a clock', (tester) async {
      await pumpPlay(tester, sampleController());
      expect(find.byKey(const ValueKey('timer')), findsNothing);
    });
  });

  group('victory dialog', () {
    testWidgets('appears by itself with time, helpers and correct spellings',
        (tester) async {
      final c = sampleController();
      final elapsed = ValueNotifier(const Duration(seconds: 125));
      final asked = <int>[];
      await pumpPlay(tester, c, elapsed: elapsed, onNewPuzzle: asked.add);
      expect(find.byType(VictoryDialog), findsNothing);

      c.revealLetter();
      solveAll(c);
      await tester.pumpAndSettle();

      expect(find.byType(VictoryDialog), findsOneWidget);
      expect(find.text('أحسنت!'), findsOneWidget);
      expect(textOf(tester, 'victory-time'), '02:05');
      expect(textOf(tester, 'victory-helpers'), '1');
      // display spelling, not the grid form (اربيل / شوقي / صين).
      expect(find.text('أربيل'), findsOneWidget);
      expect(find.text('أحمد شوقي'), findsOneWidget);
      expect(find.text('الصين'), findsOneWidget);

      await tester.tap(find.text('لغز جديد'));
      await tester.pumpAndSettle();
      expect(find.byType(VictoryDialog), findsNothing);
      expect(asked, [7]);
    });

    testWidgets('is shown only once, and can be closed', (tester) async {
      final c = sampleController();
      await pumpPlay(tester, c, elapsed: ValueNotifier(Duration.zero));
      solveAll(c);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      expect(find.byType(VictoryDialog), findsNothing);
      c.move(Move.left);
      await tester.pumpAndSettle();
      expect(find.byType(VictoryDialog), findsNothing);
    });

    testWidgets('an already solved puzzle shows it on open', (tester) async {
      final c = sampleController();
      solveAll(c);
      await pumpPlay(tester, c);
      await tester.pumpAndSettle();
      expect(find.byType(VictoryDialog), findsOneWidget);
    });
  });

  group('new puzzle menu', () {
    testWidgets('untouched puzzle: starts right away with the chosen size',
        (tester) async {
      final asked = <int>[];
      await pumpPlay(tester, sampleController(), onNewPuzzle: asked.add);
      await tester.tap(find.byTooltip('لغز جديد'));
      await tester.pumpAndSettle();
      expect(find.text('لغز جديد 7×7 (سهل)'), findsOneWidget);
      expect(find.text('لغز جديد 11×11 (صعب)'), findsOneWidget);
      await tester.tap(find.text('لغز جديد 9×9 (متوسط)'));
      await tester.pumpAndSettle();
      expect(asked, [9]);
    });

    testWidgets('puzzle in progress: asks first; cancel keeps it', (tester) async {
      final c = sampleController();
      final asked = <int>[];
      await pumpPlay(tester, c, onNewPuzzle: asked.add);
      c.input('و');
      await tester.pump();

      await tester.tap(find.byTooltip('لغز جديد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('لغز جديد 7×7 (سهل)'));
      await tester.pumpAndSettle();
      expect(find.text('سيُحذف تقدمك في اللغز الحالي.'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(asked, isEmpty);

      await tester.tap(find.byTooltip('لغز جديد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('لغز جديد 7×7 (سهل)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ابدأ لغزاً جديداً'));
      await tester.pumpAndSettle();
      expect(asked, [7]);
    });

    testWidgets('hidden when new puzzles are not available', (tester) async {
      await pumpPlay(tester, sampleController());
      expect(find.byTooltip('لغز جديد'), findsNothing);
    });
  });

  group('layout with timer and menu', () {
    for (final gridSize in supportedSizes) {
      for (final screen in const [Size(320, 568), Size(360, 640)]) {
        testWidgets(
            '$gridSize×$gridSize fits ${screen.width.toInt()}×${screen.height.toInt()}',
            (tester) async {
          final c = CrosswordController(Puzzle.fromJson(
            generatePuzzle(bank, size: gridSize, seed: 'layout').json,
          ));
          await pumpPlay(
            tester,
            c,
            elapsed: ValueNotifier(const Duration(hours: 1, seconds: 5)),
            onNewPuzzle: (_) {},
            size: screen,
            title: 'تدريب $gridSize×$gridSize',
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(Scrollable), findsNothing);
          final grid = tester.getSize(find.byType(CrosswordGrid));
          expect(grid.width, grid.height);
          expect(grid.width, greaterThan(200));
          expect(
            tester.getRect(find.byType(ArabicKeyboard)).bottom,
            lessThanOrEqualTo(screen.height),
          );
        });
      }
    }
  });
}
