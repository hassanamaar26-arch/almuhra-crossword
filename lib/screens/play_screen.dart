import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/generator/generator.dart' show supportedSizes;
import '../state/crossword_controller.dart';
import '../widgets/arabic_keyboard.dart';
import '../widgets/clue_bar.dart';
import '../widgets/clues_sheet.dart';
import '../widgets/crossword_grid.dart';
import '../widgets/victory_dialog.dart';

enum _Help { checkLetter, checkWord, revealLetter }

const Map<int, String> _sizeLabels = {7: 'سهل', 9: 'متوسط', 11: 'صعب'};

/// Grid on top, clue bar, then the Arabic keyboard. Nothing scrolls.
///
/// [elapsed] adds a timer to the app bar; [onNewPuzzle] adds the
/// "new puzzle" menu and the button of the victory dialog; [shareText]
/// adds "copy result" to the victory dialog.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.controller,
    required this.title,
    this.elapsed,
    this.onNewPuzzle,
    this.shareText,
  });

  final CrosswordController controller;
  final String title;
  final ValueListenable<Duration>? elapsed;
  final void Function(int size)? onNewPuzzle;

  /// Builds the result text for the "copy result" button of the victory
  /// dialog (daily puzzle).
  final String Function()? shareText;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  bool _victoryShown = false;

  CrosswordController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_checkSolved);
    _checkSolved();
  }

  @override
  void didUpdateWidget(PlayScreen old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_checkSolved);
      _victoryShown = false;
      _c.addListener(_checkSolved);
      _checkSolved();
    }
  }

  @override
  void dispose() {
    _c.removeListener(_checkSolved);
    super.dispose();
  }

  void _checkSolved() {
    if (_victoryShown || !_c.state.solved) return;
    _victoryShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showVictory();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _showVictory() {
    final onNew = widget.onNewPuzzle;
    final share = widget.shareText;
    final size = _c.puzzle.size;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => VictoryDialog(
        puzzle: _c.puzzle,
        helpersUsed: _c.state.helpersUsed,
        elapsed: widget.elapsed?.value,
        onCopyResult: share == null
            ? null
            : () => Clipboard.setData(ClipboardData(text: share())),
        onNewPuzzle: onNew == null
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                onNew(size);
              },
      ),
    );
  }

  Future<void> _requestNewPuzzle(int size) async {
    final state = _c.state;
    final inProgress =
        !state.solved && state.cells.values.any((c) => !c.isEmpty);
    if (inProgress) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('لغز جديد؟'),
          content: const Text('سيُحذف تقدمك في اللغز الحالي.'),
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
    widget.onNewPuzzle?.call(size);
  }

  void _onHelp(_Help help) {
    final ok = switch (help) {
      _Help.checkLetter => _c.checkLetter(),
      _Help.checkWord => _c.checkWord(),
      _Help.revealLetter => _c.revealLetter(),
    };
    if (ok) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('لا يوجد ما يمكن التحقق منه أو كشفه هنا')),
      );
  }

  /// Hardware keyboard (web / desktop / emulator).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _c.move(Move.left);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _c.move(Move.right);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _c.move(Move.up);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _c.move(Move.down);
    } else if (key == LogicalKeyboardKey.backspace) {
      _c.backspace();
    } else if (key == LogicalKeyboardKey.tab) {
      _c.stepEntry();
    } else if (event.character != null) {
      _c.input(event.character!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.elapsed;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(widget.title),
        actions: [
          if (elapsed != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ValueListenableBuilder<Duration>(
                  valueListenable: elapsed,
                  builder: (context, value, child) => Text(
                    formatDuration(value),
                    key: const ValueKey('timer'),
                    textDirection: TextDirection.ltr,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'قائمة التلميحات',
            icon: const Icon(Icons.format_list_numbered_rtl),
            onPressed: () => showCluesSheet(context, _c),
          ),
          PopupMenuButton<_Help>(
            tooltip: 'مساعدة',
            icon: const Icon(Icons.lightbulb_outline),
            onSelected: _onHelp,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _Help.checkLetter,
                child: Text('تحقق من الحرف'),
              ),
              PopupMenuItem(
                value: _Help.checkWord,
                child: Text('تحقق من الكلمة'),
              ),
              PopupMenuItem(
                value: _Help.revealLetter,
                child: Text('اكشف حرفاً'),
              ),
            ],
          ),
          if (widget.onNewPuzzle != null)
            PopupMenuButton<int>(
              tooltip: 'لغز جديد',
              icon: const Icon(Icons.add_box_outlined),
              onSelected: _requestNewPuzzle,
              itemBuilder: (_) => [
                for (final size in supportedSizes)
                  PopupMenuItem(
                    value: size,
                    child: Text('لغز جديد $size×$size (${_sizeLabels[size]})'),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CrosswordGrid(controller: _c),
                      ),
                    ),
                  ),
                  ClueBar(controller: _c),
                  ArabicKeyboard(controller: _c),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
