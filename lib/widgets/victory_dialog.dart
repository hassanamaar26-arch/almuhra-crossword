import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/puzzle.dart';

/// Shown once when the puzzle is solved: time, helpers, and every word
/// in its correct spelling.
class VictoryDialog extends StatelessWidget {
  const VictoryDialog({
    super.key,
    required this.puzzle,
    required this.helpersUsed,
    this.elapsed,
    this.onNewPuzzle,
  });

  final Puzzle puzzle;
  final int helpersUsed;
  final Duration? elapsed;
  final VoidCallback? onNewPuzzle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('أحسنت!'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (elapsed != null)
                Text(
                  'الوقت: ${formatDuration(elapsed!)}',
                  style: theme.textTheme.titleMedium,
                ),
              Text(
                'المساعدات: $helpersUsed',
                style: theme.textTheme.titleMedium,
              ),
              const Divider(height: 24),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in puzzle.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.display ?? e.answer ?? '',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(e.clue, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          if (onNewPuzzle != null)
            FilledButton(
              onPressed: onNewPuzzle,
              child: const Text('لغز جديد'),
            ),
        ],
      ),
    );
  }
}
