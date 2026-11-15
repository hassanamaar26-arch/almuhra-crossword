import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/crossword_controller.dart';
import 'crossword_grid.dart';

/// Current clue, shown right above the keyboard.
/// Side buttons step through the words; tapping the text toggles direction.
class ClueBar extends StatelessWidget {
  const ClueBar({super.key, required this.controller, this.palette});

  static const double height = 64;

  final CrosswordController controller;
  final CrosswordPalette? palette;

  @override
  Widget build(BuildContext context) {
    final pal = palette ?? CrosswordPalette.of(Theme.of(context).brightness);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final entry = controller.currentEntry;
        final solved = controller.state.solved;
        final label = solved || entry == null
            ? ''
            : '${entry.number} · ${entry.dir == Direction.across ? 'أفقي' : 'عمودي'}';
        final clue = solved ? 'أحسنت، اكتمل اللغز' : (entry?.clue ?? '');
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: Material(
              color: pal.word,
              child: SizedBox(
                height: height,
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('clue-prev'),
                      tooltip: 'السابق',
                      color: pal.letter,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => controller.stepEntry(forward: false),
                    ),
                    Expanded(
                      child: InkWell(
                        key: const ValueKey('clue-text'),
                        onTap: controller.toggleDirection,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (label.isNotEmpty)
                              Text(
                                label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: pal.number,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                clue,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: pal.letter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('clue-next'),
                      tooltip: 'التالي',
                      color: pal.letter,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => controller.stepEntry(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
