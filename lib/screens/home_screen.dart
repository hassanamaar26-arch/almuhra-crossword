import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../core/generator/generator.dart' show supportedSizes;
import '../state/app_controller.dart';
import '../state/daily_session.dart';
import '../state/game_session.dart';
import '../theme.dart';
import '../widgets/stats_sheet.dart';
import 'daily_screen.dart';
import 'practice_screen.dart';

const Map<int, String> _sizeLabels = {7: 'سهل', 9: 'متوسط', 11: 'صعب'};
const Color _ink = Color(0xFF0F172A);

/// First screen: today's puzzle, practice mode, stats and the theme switch.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.app});

  final AppController app;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppController get _app => widget.app;

  Future<void> _play(GameSession session, Widget screen) async {
    _app.playing = true;
    session.enter();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (!session.isDisposed) session.leave();
    _app.playing = false;
    await _app.refreshDaily();
    if (mounted) setState(() {});
  }

  Future<void> _openDaily() async {
    final session = _app.daily;
    await session.ensureStarted();
    if (!mounted || session.controller == null) return;
    await _play(session, DailyScreen(session: session));
  }

  Future<void> _continuePractice() =>
      _play(_app.practice, PracticeScreen(session: _app.practice));

  Future<void> _newPractice(int size) async {
    final practice = _app.practice;
    if (practice.hasProgress && !practice.isSolved) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('لغز جديد؟'),
          content: const Text('سيُحذف تقدمك في لغز التدريب الحالي.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('ابدأ لغزاً جديداً'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await practice.newPuzzle(size: size);
    if (!mounted) return;
    await _continuePractice();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [_app, _app.practice, _app.stats, _app.settings],
      ),
      builder: (context, _) {
        final pal = CrosswordPalette.of(Theme.of(context).brightness);
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _header(pal),
                    const SizedBox(height: 20),
                    _dailyCard(pal),
                    const SizedBox(height: 26),
                    _practiceSection(pal),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(CrosswordPalette pal) {
    final mode = _app.settings.themeMode;
    final (icon, label) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto, 'تلقائي'),
      ThemeMode.light => (Icons.light_mode, 'فاتح'),
      ThemeMode.dark => (Icons.dark_mode, 'داكن'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المُهرة',
                    style: TextStyle(
                      fontSize: 36,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: pal.letter,
                    ),
                  ),
                  Text(
                    'الكلمات المتقاطعة',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: pal.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'الإحصائيات',
              padding: EdgeInsets.zero,
              icon: const RoundIcon(Icons.bar_chart, size: 42),
              onPressed: () =>
                  showStatsSheet(context, _app.stats.stats, _app.today),
            ),
            IconButton(
              key: const ValueKey('theme-toggle'),
              tooltip: 'المظهر: $label',
              padding: EdgeInsets.zero,
              icon: RoundIcon(icon, size: 42),
              onPressed: _app.settings.cycleThemeMode,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _BrandTiles(palette: pal),
      ],
    );
  }

  Widget _dailyCard(CrosswordPalette pal) {
    final DailySession daily = _app.daily;
    final solved = daily.isSolved;
    final streak = _app.stats.stats.streakOn(_app.today);
    final label = solved
        ? 'عرض الشبكة'
        : daily.hasProgress
            ? 'استكمال اللغز'
            : 'ابدأ اللعب';
    const text = TextStyle(color: _ink);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFFFCD34D), Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59F59E0B),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const PositionedDirectional(
            end: -18,
            bottom: -22,
            child: ExcludeSemantics(
              child: Icon(Icons.grid_on, size: 132, color: Color(0x1F0F172A)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'لغز اليوم',
                        style: text.copyWith(
                          fontSize: 26,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Semantics(
                      label: 'سلسلة الأيام المتتالية',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x260F172A),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: _ink,
                              size: 22,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$streak',
                              key: const ValueKey('streak'),
                              style: text.copyWith(
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formatArabicDate(daily.date),
                  style: text.copyWith(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'اللغز رقم ${dailyNumber(daily.date)} · '
                  '${DailySession.gridSize}×${DailySession.gridSize}',
                  style: text.copyWith(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                if (solved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: _ink, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          'مكتمل · ${formatDuration(daily.elapsed.value)}',
                          key: const ValueKey('daily-done'),
                          style: text.copyWith(
                            fontSize: 17,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('daily-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                    ),
                    onPressed: _openDaily,
                    child: Text(label),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _practiceSection(CrosswordPalette pal) {
    final practice = _app.practice;
    final c = practice.controller;
    final open = c != null && !practice.isSolved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'وضع التدريب',
          style: TextStyle(
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: pal.letter,
          ),
        ),
        Text(
          'ألغاز بلا نهاية، بدون إنترنت. اختر حجم الشبكة:',
          style: TextStyle(fontSize: 14, height: 1.5, color: pal.muted),
        ),
        const SizedBox(height: 12),
        if (open) ...[
          FilledButton(
            key: const ValueKey('practice-continue'),
            onPressed: _continuePractice,
            child: Text(
              'استكمال التدريب · ${c.puzzle.size}×${c.puzzle.size} · '
              '${formatDuration(practice.elapsed.value)}',
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            for (final size in supportedSizes) ...[
              if (size != supportedSizes.first) const SizedBox(width: 10),
              Expanded(
                child: _SizeTile(
                  key: ValueKey('practice-$size'),
                  size: size,
                  label: _sizeLabels[size]!,
                  palette: pal,
                  onTap: () => _newPractice(size),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A grid-size choice, drawn as a raised tile.
class _SizeTile extends StatelessWidget {
  const _SizeTile({
    super.key,
    required this.size,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final int size;
  final String label;
  final CrosswordPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: palette.cellShadow, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: palette.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.cardBorder),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$size×$size',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: palette.letter,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: palette.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app name written as a row of raised crossword tiles.
class _BrandTiles extends StatelessWidget {
  const _BrandTiles({required this.palette});
  final CrosswordPalette palette;

  @override
  Widget build(BuildContext context) {
    const letters = ['ا', 'ل', 'م', 'ه', 'ر', 'ة'];
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < letters.length; i++)
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsetsDirectional.only(end: 5, bottom: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == 2 ? palette.active : palette.cell,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: i == 2 ? const Color(0xFFB45309) : palette.cellShadow,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                letters[i],
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: i == 2 ? palette.activeLetter : palette.letter,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
