import 'dart:convert';

import 'package:flutter/material.dart';

import 'models/puzzle.dart';
import 'sample_puzzle.dart';
import 'screens/play_screen.dart';
import 'state/crossword_controller.dart';

void main() => runApp(const CrosswordApp());

class CrosswordApp extends StatefulWidget {
  const CrosswordApp({super.key});

  @override
  State<CrosswordApp> createState() => _CrosswordAppState();
}

class _CrosswordAppState extends State<CrosswordApp> {
  // Demo puzzle until practice mode (generator + storage) lands.
  late final CrosswordController _controller = CrosswordController(
    Puzzle.fromJson(jsonDecode(samplePuzzleJson) as Map<String, dynamic>),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
      home: PlayScreen(controller: _controller, title: 'لغز تجريبي 7×7'),
    );
  }
}
