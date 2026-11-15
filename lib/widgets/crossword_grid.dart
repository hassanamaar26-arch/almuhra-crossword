import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/crossword_controller.dart';

/// Colors of the grid, with a light and a dark set.
@immutable
class CrosswordPalette {
  const CrosswordPalette({
    required this.block,
    required this.cell,
    required this.active,
    required this.word,
    required this.correct,
    required this.wrong,
    required this.revealed,
    required this.letter,
    required this.letterCorrect,
    required this.letterWrong,
    required this.letterRevealed,
    required this.number,
    required this.key,
    required this.keyControl,
  });

  static const light = CrosswordPalette(
    block: Color(0xFF1F2A30),
    cell: Color(0xFFFFFFFF),
    active: Color(0xFFF2B33D),
    word: Color(0xFFFBEBC4),
    correct: Color(0xFFDDF0DF),
    wrong: Color(0xFFF9DEDC),
    revealed: Color(0xFFDCE8F2),
    letter: Color(0xFF1F2A30),
    letterCorrect: Color(0xFF1E6B33),
    letterWrong: Color(0xFFA1261D),
    letterRevealed: Color(0xFF1F5A8A),
    number: Color(0xFF5B666C),
    key: Color(0xFFE7ECEF),
    keyControl: Color(0xFFCFD8DC),
  );

  static const dark = CrosswordPalette(
    block: Color(0xFF0C1114),
    cell: Color(0xFF263238),
    active: Color(0xFFB8811A),
    word: Color(0xFF4A3F22),
    correct: Color(0xFF1F3D27),
    wrong: Color(0xFF4A2320),
    revealed: Color(0xFF1F3547),
    letter: Color(0xFFF1F3F4),
    letterCorrect: Color(0xFF8FD69F),
    letterWrong: Color(0xFFF2A39C),
    letterRevealed: Color(0xFF9CC7EC),
    number: Color(0xFFA9B4BA),
    key: Color(0xFF37464E),
    keyControl: Color(0xFF2A363C),
  );

  static CrosswordPalette of(Brightness b) =>
      b == Brightness.dark ? dark : light;

  final Color block, cell, active, word, correct, wrong, revealed;
  final Color letter, letterCorrect, letterWrong, letterRevealed, number;

  /// Keyboard: letter keys and control keys (delete, direction).
  final Color key, keyControl;
}

/// The crossword board. Always laid out RTL: logical column 0 is drawn on
/// the right, so across words read right → left.
class CrosswordGrid extends StatelessWidget {
  const CrosswordGrid({super.key, required this.controller, this.palette});

  final CrosswordController controller;
  final CrosswordPalette? palette;

  @override
  Widget build(BuildContext context) {
    final pal = palette ?? CrosswordPalette.of(Theme.of(context).brightness);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final puzzle = controller.puzzle;
        final state = controller.state;
        final wordCells = controller.currentEntry?.cells.toSet() ?? const <Pos>{};
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: pal.block,
              padding: const EdgeInsets.all(1.5),
              child: Column(
                children: [
                  for (var r = 0; r < puzzle.size; r++)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = 0; c < puzzle.size; c++)
                            Expanded(
                              child: _buildCell(Pos(r, c), state, wordCells, pal),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(
    Pos p,
    CrosswordState state,
    Set<Pos> wordCells,
    CrosswordPalette pal,
  ) {
    if (!controller.puzzle.isWhite(p)) return const SizedBox.expand();
    return _WhiteCell(
      key: ValueKey(p),
      cell: state.cells[p]!,
      number: controller.puzzle.numbers[p],
      active: p == state.cursor,
      inWord: wordCells.contains(p),
      palette: pal,
      onTap: () => controller.selectCell(p),
    );
  }
}

class _WhiteCell extends StatelessWidget {
  const _WhiteCell({
    super.key,
    required this.cell,
    required this.number,
    required this.active,
    required this.inWord,
    required this.palette,
    required this.onTap,
  });

  final CellState cell;
  final int? number;
  final bool active;
  final bool inWord;
  final CrosswordPalette palette;
  final VoidCallback onTap;

  Color get _background {
    if (active) return palette.active;
    switch (cell.status) {
      case CellStatus.correct:
        return palette.correct;
      case CellStatus.wrong:
        return palette.wrong;
      case CellStatus.revealed:
        return palette.revealed;
      case CellStatus.empty:
      case CellStatus.filled:
        return inWord ? palette.word : palette.cell;
    }
  }

  Color get _letterColor {
    if (active) return palette.letter;
    switch (cell.status) {
      case CellStatus.correct:
        return palette.letterCorrect;
      case CellStatus.wrong:
        return palette.letterWrong;
      case CellStatus.revealed:
        return palette.letterRevealed;
      case CellStatus.empty:
      case CellStatus.filled:
        return palette.letter;
    }
  }

  String get _semantics {
    final status = switch (cell.status) {
      CellStatus.empty => 'فارغ',
      CellStatus.filled => cell.letter,
      CellStatus.correct => '${cell.letter}، صحيح',
      CellStatus.wrong => '${cell.letter}، خطأ',
      CellStatus.revealed => '${cell.letter}، مكشوف',
    };
    return number == null ? status : 'مربع $number، $status';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: _semantics,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, box) {
            final side = math.min(box.maxWidth, box.maxHeight);
            return Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  if (number != null)
                    PositionedDirectional(
                      top: 1,
                      start: 3,
                      child: Text(
                        '$number',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: math.max(side * 0.24, 8),
                          height: 1,
                          color: palette.number,
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      cell.letter,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: side * 0.56,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: _letterColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
