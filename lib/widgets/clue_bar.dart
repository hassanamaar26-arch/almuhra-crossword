import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/crossword_controller.dart';
import '../theme.dart';

/// Current clue as a floating card right above the keyboard: a badge with
/// the word number and direction, the clue, and round buttons to step
/// through the words. Tapping the clue toggles the direction.
class ClueBar extends StatelessWidget {
  const ClueBar({super.key, required this.controller, this.palette});

  /// Height of the card itself (margins excluded).
  static const double cardHeight = 96;

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
        final badge = solved || entry == null
            ? null
            : '${entry.number} ${entry.dir == Direction.across ? 'أفقي' : 'عمودي'}';
        final clue = solved ? 'أحسنت، اكتمل اللغز' : (entry?.clue ?? '');

        Widget nav(String key, String tooltip, IconData icon, bool forward) =>
            IconButton(
              key: ValueKey(key),
              tooltip: tooltip,
              padding: EdgeInsets.zero,
              icon: RoundIcon(icon, size: 36),
              onPressed: () => controller.stepEntry(forward: forward),
            );

        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Material(
                color: pal.card,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: pal.cardBorder),
                ),
                child: SizedBox(
                  height: cardHeight,
                  child: Row(
                    children: [
                      nav('clue-prev', 'السابق', Icons.chevron_right, false),
                      Expanded(
                        child: InkWell(
                          key: const ValueKey('clue-text'),
                          onTap: controller.toggleDirection,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (badge != null)
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pal.accent,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        badge,
                                        key: const ValueKey('clue-badge'),
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          fontWeight: FontWeight.w800,
                                          color: pal.onAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (badge != null) const SizedBox(height: 4),
                                Flexible(
                                  child: Text(
                                    clue,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                      color: pal.letter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      nav('clue-next', 'التالي', Icons.chevron_left, true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
