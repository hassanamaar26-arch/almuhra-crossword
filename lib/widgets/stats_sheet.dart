import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/generator/generator.dart' show supportedSizes;
import '../state/stats.dart';

Future<void> showStatsSheet(
  BuildContext context,
  PlayerStats stats,
  String today,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => StatsSheet(stats: stats, today: today),
  );
}

/// The player's numbers, two tiles per row.
class StatsSheet extends StatelessWidget {
  const StatsSheet({super.key, required this.stats, required this.today});

  final PlayerStats stats;
  final String today;

  @override
  Widget build(BuildContext context) {
    String best(int size) {
      final t = stats.bestTime(size);
      return t == null ? '—' : formatDuration(t);
    }

    final tiles = <(String, String)>[
      ('الألغاز المحلولة', '${stats.totalSolved}'),
      ('ألغاز يومية', '${stats.dailySolved}'),
      ('السلسلة الحالية', '${stats.streakOn(today)}'),
      ('أفضل سلسلة', '${stats.bestStreak}'),
      ('بدون مساعدة', '${stats.noHintWins}'),
      for (final size in supportedSizes) ('أسرع $size×$size', best(size)),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إحصائياتك',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < tiles.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: _Tile(tiles[i].$1, tiles[i].$2)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: i + 1 < tiles.length
                            ? _Tile(tiles[i + 1].$1, tiles[i + 1].$2)
                            : const SizedBox(),
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
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            key: ValueKey('stat-$label'),
            textDirection: TextDirection.ltr,
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
