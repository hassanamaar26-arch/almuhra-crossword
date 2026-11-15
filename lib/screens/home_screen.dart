import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../core/generator/generator.dart' show supportedSizes;
import '../state/app_controller.dart';
import '../state/daily_session.dart';
import '../state/game_session.dart';
import '../widgets/crossword_grid.dart';
import '../widgets/stats_sheet.dart';
import 'daily_screen.dart';
import 'practice_screen.dart';

const Map<int, String> _sizeLabels = {7: 'سهل', 9: 'متوسط', 11: 'صعب'};
const Color _ink = Color(0xFF1F2A30);

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
                    _header(context),
                    const SizedBox(height: 12),
                    _BrandTiles(palette: pal),
                    const SizedBox(height: 20),
                    _dailyCard(context, pal),
                    const SizedBox(height: 24),
                    _practiceSection(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final mode = _app.settings.themeMode;
    final (icon, label) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto, 'تلقائي'),
      ThemeMode.light => (Icons.light_mode, 'فاتح'),
      ThemeMode.dark => (Icons.dark_mode, 'داكن'),
    };
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المُهرة',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text('الكلمات المتقاطعة', style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        IconButton(
          tooltip: 'الإحصائيات',
          icon: const Icon(Icons.bar_chart),
          onPressed: () =>
              showStatsSheet(context, _app.stats.stats, _app.today),
        ),
        IconButton(
          key: const ValueKey('theme-toggle'),
          tooltip: 'المظهر: $label',
          icon: Icon(icon),
          onPressed: _app.settings.cycleThemeMode,
        ),
      ],
    );
  }

  Widget _dailyCard(BuildContext context, CrosswordPalette pal) {
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.active,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'لغز اليوم',
                  style: text.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              Semantics(
                label: 'سلسلة الأيام المتتالية',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: _ink),
                    const SizedBox(width: 2),
                    Text(
                      '$streak',
                      key: const ValueKey('streak'),
                      style: text.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(formatArabicDate(daily.date), style: text.copyWith(fontSize: 15)),
          Text(
            'اللغز رقم ${dailyNumber(daily.date)} · '
            '${DailySession.gridSize}×${DailySession.gridSize}',
            style: text.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (solved)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: _ink, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'مكتمل · ${formatDuration(daily.elapsed.value)}',
                    key: const ValueKey('daily-done'),
                    style: text.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
              ),
              onPressed: _openDaily,
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }

  Widget _practiceSection(BuildContext context) {
    final theme = Theme.of(context);
    final practice = _app.practice;
    final c = practice.controller;
    final open = c != null && !practice.isSolved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('وضع التدريب', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'ألغاز بلا نهاية، بدون إنترنت. اختر حجم الشبكة:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (open) ...[
          FilledButton.tonal(
            key: const ValueKey('practice-continue'),
            onPressed: _continuePractice,
            child: Text(
              'استكمال التدريب · ${c.puzzle.size}×${c.puzzle.size} · '
              '${formatDuration(practice.elapsed.value)}',
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            for (final size in supportedSizes) ...[
              if (size != supportedSizes.first) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('practice-$size'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _newPractice(size),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$size×$size',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(_sizeLabels[size]!),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The app name written as a row of crossword cells.
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
              margin: const EdgeInsetsDirectional.only(end: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == 2 ? palette.active : palette.cell,
                border: Border.all(color: palette.block, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                letters[i],
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: palette.letter,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
