import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/generator/generator.dart' show supportedSizes;
import '../state/stats.dart';
import '../theme.dart';

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

/// The player's numbers, two cards per row.
class StatsSheet extends StatelessWidget {
  const StatsSheet({super.key, required this.stats, required this.today});

  final PlayerStats stats;
  final String today;

  @override
  Widget build(BuildContext context) {
    final pal = CrosswordPalette.of(Theme.of(context).brightness);
    String best(int size) {
      final t = stats.bestTime(size);
      return t == null ? '—' : formatDuration(t);
    }

    final tiles = <(String, String, IconData)>[
      ('الألغاز المحلولة', '${stats.totalSolved}', Icons.grid_on),
      ('ألغاز يومية', '${stats.dailySolved}', Icons.today),
      ('السلسلة الحالية', '${stats.streakOn(today)}', Icons.local_fire_department),
      ('أفضل سلسلة', '${stats.bestStreak}', Icons.emoji_events),
      ('بدون مساعدة', '${stats.noHintWins}', Icons.verified),
      for (final size in supportedSizes)
        ('أسرع $size×$size', best(size), Icons.timer_outlined),
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: pal.letter,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < tiles.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: _Tile(tiles[i], pal)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: i + 1 < tiles.length
                            ? _Tile(tiles[i + 1], pal)
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
  const _Tile(this.data, this.palette);
  final (String, String, IconData) data;
  final CrosswordPalette palette;

  @override
  Widget build(BuildContext context) {
    final (label, value, icon) = data;
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.3, color: palette.muted),
                ),
                Text(
                  value,
                  key: ValueKey('stat-$label'),
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
