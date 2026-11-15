import '../models/puzzle.dart';
import 'dates.dart';
import 'format.dart';

const String shareBlock = '⬛';
const String shareSolved = '🟩';
const String shareRevealed = '🟨';

/// Result of a daily puzzle as plain text: no letters, only the grid shape.
/// 🟩 = solved by the player, 🟨 = revealed with a helper.
String buildShareText({
  required Puzzle puzzle,
  required Map<Pos, CellState> cells,
  required String date,
  required Duration elapsed,
  required int helpersUsed,
}) {
  final lines = <String>[
    'الكلمات المتقاطعة (المُهرة)',
    'لغز اليوم #${dailyNumber(date)} · $date',
    'الوقت ${formatDuration(elapsed)} · المساعدات $helpersUsed',
  ];
  for (var r = 0; r < puzzle.size; r++) {
    final row = StringBuffer();
    for (var c = 0; c < puzzle.size; c++) {
      final cell = cells[Pos(r, c)];
      if (cell == null) {
        row.write(shareBlock);
      } else {
        row.write(
          cell.status == CellStatus.revealed ? shareRevealed : shareSolved,
        );
      }
    }
    lines.add(row.toString());
  }
  return lines.join('\n');
}
