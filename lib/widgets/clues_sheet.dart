import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/crossword_controller.dart';
import 'crossword_grid.dart';

Future<void> showCluesSheet(
  BuildContext context,
  CrosswordController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CluesSheet(controller: controller),
  );
}

/// All clues in two tabs (across / down). Tapping one jumps to that word.
class CluesSheet extends StatelessWidget {
  const CluesSheet({super.key, required this.controller, this.palette});

  final CrosswordController controller;
  final CrosswordPalette? palette;

  @override
  Widget build(BuildContext context) {
    final pal = palette ?? CrosswordPalette.of(Theme.of(context).brightness);
    final entries = controller.puzzle.entries;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(tabs: [Tab(text: 'أفقي'), Tab(text: 'عمودي')]),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final dir in Direction.values)
                      ListView(
                        children: [
                          for (final e in entries)
                            if (e.dir == dir) _tile(context, e, pal),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Entry e, CrosswordPalette pal) {
    final done = controller.isComplete(e);
    final current = controller.currentEntry == e;
    return ListTile(
      dense: true,
      selected: current,
      selectedTileColor: pal.word,
      leading: Text(
        '${e.number}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: done ? pal.number : pal.letter,
        ),
      ),
      title: Text(
        e.clue,
        style: TextStyle(
          fontSize: 15,
          color: done ? pal.number : pal.letter,
          decoration: done ? TextDecoration.lineThrough : null,
          decorationColor: pal.number,
        ),
      ),
      trailing: done
          ? Icon(Icons.check_circle, size: 20, color: pal.letterCorrect)
          : null,
      onTap: () {
        Navigator.of(context).pop();
        controller.selectEntry(e);
      },
    );
  }
}
