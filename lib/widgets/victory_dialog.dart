import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/puzzle.dart';

/// Shown once when the puzzle is solved: time, helpers, and every word
/// in its correct spelling.
class VictoryDialog extends StatefulWidget {
  const VictoryDialog({
    super.key,
    required this.puzzle,
    required this.helpersUsed,
    this.elapsed,
    this.onNewPuzzle,
    this.onCopyResult,
  });

  final Puzzle puzzle;
  final int helpersUsed;
  final Duration? elapsed;
  final VoidCallback? onNewPuzzle;

  /// Copies the shareable result (daily puzzle only).
  final Future<void> Function()? onCopyResult;

  @override
  State<VictoryDialog> createState() => _VictoryDialogState();
}

class _VictoryDialogState extends State<VictoryDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await widget.onCopyResult!();
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = widget.elapsed;
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
                  'الوقت: ${formatDuration(elapsed)}',
                  style: theme.textTheme.titleMedium,
                ),
              Text(
                'المساعدات: ${widget.helpersUsed}',
                style: theme.textTheme.titleMedium,
              ),
              const Divider(height: 24),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in widget.puzzle.entries)
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
          if (widget.onCopyResult != null)
            OutlinedButton.icon(
              onPressed: _copy,
              icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
              label: Text(_copied ? 'تم النسخ' : 'نسخ النتيجة'),
            ),
          if (widget.onNewPuzzle != null)
            FilledButton(
              onPressed: widget.onNewPuzzle,
              child: const Text('لغز جديد'),
            ),
        ],
      ),
    );
  }
}
