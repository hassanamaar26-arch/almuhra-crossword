import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/crossword_controller.dart';
import '../theme.dart';

export '../theme.dart' show CrosswordPalette;

/// The crossword board. Always laid out RTL: logical column 0 is drawn on
/// the right, so across words read right → left.
class CrosswordGrid extends StatelessWidget {
  const CrosswordGrid({super.key, required this.controller, this.palette});

  /// Space between the board edge and the outer tiles.
  static const double boardPadding = 8;

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
              padding: const EdgeInsets.all(boardPadding),
              decoration: BoxDecoration(
                color: pal.board,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: pal.boardShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
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
    if (!controller.puzzle.isWhite(p)) return _BlockTile(color: pal.block);
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

const double _tileGap = 1.5;
const double _tileRadius = 6;

/// A black square: a sunken tile, not an empty hole.
class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(_tileGap),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_tileRadius),
      ),
    );
  }
}

class _WhiteCell extends StatefulWidget {
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

  @override
  State<_WhiteCell> createState() => _WhiteCellState();
}

class _WhiteCellState extends State<_WhiteCell>
    with SingleTickerProviderStateMixin {
  // A short "pop" when a new letter lands in the cell.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.18)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.18, end: 1.0)
          .chain(CurveTween(curve: Curves.easeIn)),
      weight: 60,
    ),
  ]).animate(_pulse);

  @override
  void didUpdateWidget(_WhiteCell old) {
    super.didUpdateWidget(old);
    final letter = widget.cell.letter;
    if (letter.isNotEmpty && letter != old.cell.letter) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  CrosswordPalette get _pal => widget.palette;

  Color get _background {
    if (widget.active) return _pal.active;
    switch (widget.cell.status) {
      case CellStatus.correct:
        return _pal.correct;
      case CellStatus.wrong:
        return _pal.wrong;
      case CellStatus.revealed:
        return _pal.revealed;
      case CellStatus.empty:
      case CellStatus.filled:
        return widget.inWord ? _pal.word : _pal.cell;
    }
  }

  Color get _letterColor {
    if (widget.active) return _pal.activeLetter;
    switch (widget.cell.status) {
      case CellStatus.correct:
        return _pal.letterCorrect;
      case CellStatus.wrong:
        return _pal.letterWrong;
      case CellStatus.revealed:
        return _pal.letterRevealed;
      case CellStatus.empty:
      case CellStatus.filled:
        return _pal.letter;
    }
  }

  String get _semantics {
    final cell = widget.cell;
    final status = switch (cell.status) {
      CellStatus.empty => 'فارغ',
      CellStatus.filled => cell.letter,
      CellStatus.correct => '${cell.letter}، صحيح',
      CellStatus.wrong => '${cell.letter}، خطأ',
      CellStatus.revealed => '${cell.letter}، مكشوف',
    };
    return widget.number == null ? status : 'مربع ${widget.number}، $status';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.active,
      label: _semantics,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, box) {
            final side = math.min(box.maxWidth, box.maxHeight);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.all(_tileGap),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(_tileRadius),
                border: Border.all(
                  color: widget.active
                      ? _pal.activeBorder
                      : const Color(0x00000000),
                  width: 1.5,
                ),
                // Solid lower edge: the tile looks raised from the board.
                boxShadow: [
                  BoxShadow(color: _pal.cellShadow, offset: const Offset(0, 2)),
                ],
              ),
              child: Stack(
                children: [
                  if (widget.number != null)
                    PositionedDirectional(
                      top: 0,
                      start: 2,
                      child: Text(
                        '${widget.number}',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: math.max(side * 0.24, 8),
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: widget.active
                              ? _pal.activeLetter
                              : _pal.number,
                        ),
                      ),
                    ),
                  Center(
                    child: ScaleTransition(
                      scale: _scale,
                      child: Text(
                        widget.cell.letter,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: side * 0.54,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: _letterColor,
                        ),
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
