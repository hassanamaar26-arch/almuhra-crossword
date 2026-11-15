import 'package:flutter/material.dart';

import '../state/practice_session.dart';
import 'play_screen.dart';

/// Practice mode: shows the session's current puzzle.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key, required this.session});

  final PracticeSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final controller = session.controller;
        if (controller == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final size = controller.puzzle.size;
        return PlayScreen(
          key: ValueKey(controller.puzzle.id),
          controller: controller,
          title: 'تدريب $size×$size',
          elapsed: session.elapsed,
          onNewPuzzle: (size) => session.newPuzzle(size: size),
        );
      },
    );
  }
}
