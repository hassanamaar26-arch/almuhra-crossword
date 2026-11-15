import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/crossword_controller.dart';
import '../widgets/arabic_keyboard.dart';
import '../widgets/clue_bar.dart';
import '../widgets/clues_sheet.dart';
import '../widgets/crossword_grid.dart';

enum _Help { checkLetter, checkWord, revealLetter }

/// Grid on top, clue bar, then the Arabic keyboard. Nothing scrolls.
class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key, required this.controller, required this.title});

  final CrosswordController controller;
  final String title;

  void _onHelp(BuildContext context, _Help help) {
    final ok = switch (help) {
      _Help.checkLetter => controller.checkLetter(),
      _Help.checkWord => controller.checkWord(),
      _Help.revealLetter => controller.revealLetter(),
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
      controller.move(Move.left);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      controller.move(Move.right);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      controller.move(Move.up);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      controller.move(Move.down);
    } else if (key == LogicalKeyboardKey.backspace) {
      controller.backspace();
    } else if (key == LogicalKeyboardKey.tab) {
      controller.stepEntry();
    } else if (event.character != null) {
      controller.input(event.character!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'قائمة التلميحات',
            icon: const Icon(Icons.format_list_numbered_rtl),
            onPressed: () => showCluesSheet(context, controller),
          ),
          PopupMenuButton<_Help>(
            tooltip: 'مساعدة',
            icon: const Icon(Icons.lightbulb_outline),
            onSelected: (h) => _onHelp(context, h),
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
                        child: CrosswordGrid(controller: controller),
                      ),
                    ),
                  ),
                  ClueBar(controller: controller),
                  ArabicKeyboard(controller: controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
