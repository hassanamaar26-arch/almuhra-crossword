import 'dart:convert';

import 'package:almuhra_crossword/core/arabic/normalize.dart';
import 'package:almuhra_crossword/models/puzzle.dart';
import 'package:almuhra_crossword/sample_puzzle.dart';
import 'package:almuhra_crossword/screens/play_screen.dart';
import 'package:almuhra_crossword/state/crossword_controller.dart';
import 'package:almuhra_crossword/widgets/arabic_keyboard.dart';
import 'package:almuhra_crossword/widgets/clues_sheet.dart';
import 'package:almuhra_crossword/widgets/crossword_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CrosswordController newController() => CrosswordController(
      Puzzle.fromJson(jsonDecode(samplePuzzleJson) as Map<String, dynamic>),
    );

Future<void> pumpPlay(
  WidgetTester tester,
  CrosswordController c, {
  Size size = const Size(360, 640),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: brightness),
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: PlayScreen(controller: c, title: 'لغز'),
  ));
}

Finder inGrid(String text) => find.descendant(
      of: find.byType(CrosswordGrid),
      matching: find.text(text),
    );

void main() {
  test('keyboard rows hold exactly the 30 letters of the alphabet', () {
    final keys = arabicKeyboardRows.expand((r) => r).toList();
    expect(keys.length, 30);
    expect(keys.toSet(), arabicAlphabet.toSet());
    expect(arabicKeyboardRows.map((r) => r.length), [11, 10, 9]);
  });

  group('layout', () {
    for (final size in const [Size(360, 640), Size(320, 568), Size(412, 915)]) {
      testWidgets('fits ${size.width.toInt()}×${size.height.toInt()} without overflow or scrolling',
          (tester) async {
        await pumpPlay(tester, newController(), size: size);
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        expect(find.byType(CrosswordGrid), findsOneWidget);
        final grid = tester.getSize(find.byType(CrosswordGrid));
        expect(grid.width, grid.height);
        expect(grid.width, greaterThan(200));
        // Keyboard fully inside the screen.
        final kb = tester.getRect(find.byType(ArabicKeyboard));
        expect(kb.bottom, lessThanOrEqualTo(size.height));
        expect(kb.left, greaterThanOrEqualTo(0));
        expect(kb.right, lessThanOrEqualTo(size.width));
      });
    }

    testWidgets('dark theme builds', (tester) async {
      await pumpPlay(tester, newController(), brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL: column 0 is drawn on the right', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      c.selectCell(const Pos(6, 0));
      c.input('ص');
      c.input('ي');
      await tester.pump();
      final first = tester.getCenter(inGrid('ص'));
      final second = tester.getCenter(inGrid('ي'));
      expect(first.dx, greaterThan(second.dx));
    });

    testWidgets('first keyboard letter (ض) is on the right', (tester) async {
      await pumpPlay(tester, newController());
      final dad = tester.getCenter(find.byKey(const ValueKey('key-ض')));
      final jeem = tester.getCenter(find.byKey(const ValueKey('key-ج')));
      expect(dad.dx, greaterThan(jeem.dx));
    });

  });

  group('Arabic keyboard', () {
    testWidgets('tapping letters fills the grid and advances', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      await tester.tap(find.byKey(const ValueKey('key-و')));
      await tester.pump();
      expect(c.state.cells[const Pos(1, 4)]!.letter, 'و');
      expect(c.state.cursor, const Pos(1, 5));
      expect(inGrid('و'), findsOneWidget);
    });

    testWidgets('backspace key deletes', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      await tester.tap(find.byKey(const ValueKey('key-و')));
      await tester.tap(find.byKey(const ValueKey('key-backspace')));
      await tester.pump();
      expect(c.state.cells[const Pos(1, 4)]!.isEmpty, isTrue);
      expect(c.state.cursor, const Pos(1, 4));
      expect(inGrid('و'), findsNothing);
    });

    testWidgets('direction key toggles across / down', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      await tester.tap(find.byKey(const ValueKey('key-toggle')));
      await tester.pump();
      expect(c.state.dir, Direction.down);
      expect(find.text('1 عمودي'), findsOneWidget);
    });

    testWidgets('typing a whole word with the keyboard', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      for (final l in ['و', 'ر', 'د']) {
        await tester.tap(find.byKey(ValueKey('key-$l')));
      }
      await tester.pump();
      expect(c.isComplete(c.puzzle.entries.first), isTrue);
      expect(c.currentEntry!.number, 5);
    });
  });

  group('clue bar', () {
    testWidgets('shows number, direction and clue of the current word',
        (tester) async {
      await pumpPlay(tester, newController());
      expect(find.text('3 أفقي'), findsOneWidget);
      expect(find.text('زهر يُهدى رمزاً للمحبة'), findsOneWidget);
    });

    testWidgets('next / previous step through the words', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      await tester.tap(find.byKey(const ValueKey('clue-next')));
      await tester.pump();
      expect(find.text('5 أفقي'), findsOneWidget);
      expect(find.text('مركز إقليم كردستان العراق'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('clue-prev')));
      await tester.pump();
      expect(find.text('3 أفقي'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('clue-prev')));
      await tester.pump();
      expect(find.text('6 عمودي'), findsOneWidget);
    });

    testWidgets('tapping the clue text toggles direction', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      await tester.tap(find.byKey(const ValueKey('clue-text')));
      await tester.pump();
      expect(c.state.dir, Direction.down);
      expect(find.text('1 عمودي'), findsOneWidget);
      expect(find.text('أمير الشعراء'), findsOneWidget);
    });

    testWidgets('tapping a grid cell updates the clue', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      c.selectCell(const Pos(6, 4));
      await tester.pump();
      expect(find.text('8 أفقي'), findsOneWidget);
      expect(find.text('بلد تاج محل'), findsOneWidget);
    });
  });

  group('clues sheet', () {
    testWidgets('opens with two tabs; tapping a clue jumps and closes',
        (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      await tester.tap(find.byTooltip('قائمة التلميحات'));
      await tester.pumpAndSettle();
      expect(find.byType(CluesSheet), findsOneWidget);
      expect(find.text('أفقي'), findsOneWidget);
      expect(find.text('عمودي'), findsOneWidget);

      await tester.tap(find.text('عمودي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('عاصمة بريطانيا'));
      await tester.pumpAndSettle();

      expect(find.byType(CluesSheet), findsNothing);
      expect(c.state.cursor, const Pos(3, 5));
      expect(c.state.dir, Direction.down);
      expect(find.text('6 عمودي'), findsOneWidget);
    });

    testWidgets('completed words are marked; tapping one goes to its start',
        (tester) async {
      final c = newController();
      c..input('و')..input('ر')..input('د');
      await pumpPlay(tester, c);
      await tester.tap(find.byTooltip('قائمة التلميحات'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.text('زهر يُهدى رمزاً للمحبة'));
      await tester.pumpAndSettle();
      expect(c.state.cursor, const Pos(1, 4));
      expect(c.state.dir, Direction.across);
    });

    testWidgets('jumps to the first EMPTY cell of an unfinished word',
        (tester) async {
      final c = newController();
      c.selectCell(const Pos(3, 1));
      c.input('ا');
      c.selectCell(const Pos(1, 4));
      await pumpPlay(tester, c);
      await tester.tap(find.byTooltip('قائمة التلميحات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مركز إقليم كردستان العراق'));
      await tester.pumpAndSettle();
      expect(c.state.cursor, const Pos(3, 2));
    });
  });

  group('help menu', () {
    testWidgets('reveal letter fills the active cell', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      await tester.tap(find.byTooltip('مساعدة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اكشف حرفاً'));
      await tester.pumpAndSettle();
      expect(c.state.cells[const Pos(1, 4)]!.status, CellStatus.revealed);
      expect(inGrid('و'), findsOneWidget);
    });

    testWidgets('check word marks wrong letters', (tester) async {
      final c = newController();
      await pumpPlay(tester, c);
      await tester.tap(find.byKey(const ValueKey('key-ز')));
      await tester.pump();
      await tester.tap(find.byTooltip('مساعدة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحقق من الكلمة'));
      await tester.pumpAndSettle();
      expect(c.state.cells[const Pos(1, 4)]!.status, CellStatus.wrong);
    });

    testWidgets('nothing to check shows a message', (tester) async {
      await pumpPlay(tester, newController());
      await tester.tap(find.byTooltip('مساعدة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحقق من الحرف'));
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد ما يمكن التحقق منه أو كشفه هنا'), findsOneWidget);
    });
  });

  testWidgets('solving the puzzle shows the finished message', (tester) async {
    final c = newController();
    await pumpPlay(tester, c);
    for (final e in c.puzzle.entries) {
      for (final p in e.cells) {
        c.selectCell(p);
        c.input(c.puzzle.solution![p]!);
      }
    }
    await tester.pump();
    expect(find.text('أحسنت، اكتمل اللغز'), findsOneWidget);
  });
}
