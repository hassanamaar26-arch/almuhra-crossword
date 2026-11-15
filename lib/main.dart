import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/puzzle.dart';
import 'sample_puzzle.dart';
import 'state/crossword_controller.dart';
import 'widgets/crossword_grid.dart';

void main() => runApp(const CrosswordApp());

class CrosswordApp extends StatelessWidget {
  const CrosswordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الكلمات المتقاطعة (المُهرة)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFB8811A)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFB8811A),
        brightness: Brightness.dark,
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const DemoScreen(),
    );
  }
}

/// Temporary screen to try the grid with a hardware keyboard.
/// The Arabic on-screen keyboard and clue list come in the next milestone.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  late final CrosswordController _controller = CrosswordController(
    Puzzle.fromJson(jsonDecode(samplePuzzleJson) as Map<String, dynamic>),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _controller.move(Move.left);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _controller.move(Move.right);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _controller.move(Move.up);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _controller.move(Move.down);
    } else if (key == LogicalKeyboardKey.backspace) {
      _controller.backspace();
    } else if (key == LogicalKeyboardKey.tab) {
      _controller.stepEntry();
    } else if (event.character != null) {
      _controller.input(event.character!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الكلمات المتقاطعة (المُهرة)')),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  CrosswordGrid(controller: _controller),
                  const SizedBox(height: 12),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      final e = _controller.currentEntry;
                      final solved = _controller.state.solved;
                      return Text(
                        solved
                            ? 'أحسنت، اكتمل اللغز'
                            : e == null
                                ? ''
                                : '${e.number}. ${e.clue}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _controller.checkLetter,
                        child: const Text('تحقق من الحرف'),
                      ),
                      OutlinedButton(
                        onPressed: _controller.checkWord,
                        child: const Text('تحقق من الكلمة'),
                      ),
                      OutlinedButton(
                        onPressed: _controller.revealLetter,
                        child: const Text('اكشف حرفاً'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
