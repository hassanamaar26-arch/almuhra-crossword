import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/puzzle.dart';
import '../theme.dart';

/// Celebration shown once when the puzzle is solved: a trophy, the time and
/// helpers as stat cards, every word in its correct spelling, and the next
/// actions as wide buttons.
class VictoryDialog extends StatefulWidget {
  const VictoryDialog({
    super.key,
    required this.puzzle,
    required this.helpersUsed,
    this.elapsed,
    this.onNewPuzzle,
    this.onShareResult,
  });

  final Puzzle puzzle;
  final int helpersUsed;
  final Duration? elapsed;
  final VoidCallback? onNewPuzzle;

  /// Copies the shareable result to the clipboard (daily puzzle only).
  final Future<void> Function()? onShareResult;

  @override
  State<VictoryDialog> createState() => _VictoryDialogState();
}

class _VictoryDialogState extends State<VictoryDialog> {
  static const Color _gold = Color(0xFFF59E0B);
  bool _copied = false;

  Future<void> _share() async {
    await widget.onShareResult!();
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final pal = CrosswordPalette.of(Theme.of(context).brightness);
    final elapsed = widget.elapsed;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: pal.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0xFFFDE68A), _gold],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x80F59E0B),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      size: 44,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'أحسنت!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: pal.letter,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (elapsed != null) ...[
                      Expanded(
                        child: _StatCard(
                          valueKey: 'victory-time',
                          icon: Icons.timer_outlined,
                          label: 'الوقت',
                          value: formatDuration(elapsed),
                          palette: pal,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _StatCard(
                        valueKey: 'victory-helpers',
                        icon: Icons.lightbulb_outline,
                        label: 'المساعدات',
                        value: '${widget.helpersUsed}',
                        palette: pal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.puzzle.entries.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, i) =>
                        _WordCard(entry: widget.puzzle.entries[i], palette: pal),
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.onNewPuzzle != null) ...[
                  FilledButton.icon(
                    onPressed: widget.onNewPuzzle,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('لغز جديد'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (widget.onShareResult != null) ...[
                  FilledButton.icon(
                    key: const ValueKey('victory-share'),
                    onPressed: _share,
                    icon: Icon(_copied ? Icons.check : Icons.share, size: 20),
                    label: Text(
                      _copied ? 'تم النسخ، الصقها لأصدقائك' : 'مشاركة النتيجة',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.valueKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.palette,
  });

  final String valueKey;
  final IconData icon;
  final String label;
  final String value;
  final CrosswordPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.board,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: palette.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, height: 1.3, color: palette.muted),
                ),
                Text(
                  value,
                  key: ValueKey(valueKey),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: palette.letter,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.entry, required this.palette});

  final Entry entry;
  final CrosswordPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.display ?? entry.answer ?? '',
            style: TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: palette.accent,
            ),
          ),
          Text(
            entry.clue,
            style: TextStyle(fontSize: 12.5, height: 1.3, color: palette.muted),
          ),
        ],
      ),
    );
  }
}
