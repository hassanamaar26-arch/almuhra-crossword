import 'package:flutter/material.dart';

import '../core/share_text.dart';
import '../state/daily_session.dart';
import 'play_screen.dart';

/// Today's puzzle. The session must already hold a puzzle.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key, required this.session});

  final DailySession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final controller = session.controller!;
        return PlayScreen(
          key: ValueKey(controller.puzzle.id),
          controller: controller,
          title: 'لغز اليوم',
          elapsed: session.elapsed,
          shareText: () => buildShareText(
            puzzle: controller.puzzle,
            cells: controller.state.cells,
            date: session.date,
            elapsed: session.elapsed.value,
            helpersUsed: controller.state.helpersUsed,
          ),
        );
      },
    );
  }
}
