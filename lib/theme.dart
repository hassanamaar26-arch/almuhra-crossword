import 'package:flutter/material.dart';

const String appFontFamily = 'Cairo';

/// Every color of the game, with a dark and a light set.
///
/// Dark: slate night with an amber glow and emerald accents.
/// Light: crisp paper with royal blue accents.
@immutable
class CrosswordPalette {
  const CrosswordPalette({
    required this.background,
    required this.board,
    required this.boardShadow,
    required this.block,
    required this.cell,
    required this.cellShadow,
    required this.active,
    required this.activeLetter,
    required this.activeBorder,
    required this.word,
    required this.correct,
    required this.wrong,
    required this.revealed,
    required this.letter,
    required this.letterCorrect,
    required this.letterWrong,
    required this.letterRevealed,
    required this.number,
    required this.key,
    required this.keyShadow,
    required this.keyControl,
    required this.keyControlShadow,
    required this.card,
    required this.cardBorder,
    required this.accent,
    required this.onAccent,
    required this.muted,
  });

  static const dark = CrosswordPalette(
    background: Color(0xFF0F172A),
    board: Color(0xFF1E293B),
    boardShadow: Color(0x66000000),
    block: Color(0xFF090D16),
    cell: Color(0xFF334155),
    cellShadow: Color(0xFF0B1220),
    active: Color(0xFFF59E0B),
    activeLetter: Color(0xFF0F172A),
    activeBorder: Color(0xFFFFFFFF),
    word: Color(0xFF1E3A5F),
    correct: Color(0xFF14532D),
    wrong: Color(0xFF7F1D1D),
    revealed: Color(0xFF312E81),
    letter: Color(0xFFF1F5F9),
    letterCorrect: Color(0xFF86EFAC),
    letterWrong: Color(0xFFFCA5A5),
    letterRevealed: Color(0xFFC7D2FE),
    number: Color(0xFF94A3B8),
    key: Color(0xFF334155),
    keyShadow: Color(0xFF060A12),
    keyControl: Color(0xFF475569),
    keyControlShadow: Color(0xFF060A12),
    card: Color(0xFF1E293B),
    cardBorder: Color(0xFF334155),
    accent: Color(0xFF34D399),
    onAccent: Color(0xFF052E1B),
    muted: Color(0xFF94A3B8),
  );

  static const light = CrosswordPalette(
    background: Color(0xFFF8FAFC),
    board: Color(0xFFE2E8F0),
    boardShadow: Color(0x330F172A),
    block: Color(0xFF1E293B),
    cell: Color(0xFFFFFFFF),
    cellShadow: Color(0xFFCBD5E1),
    active: Color(0xFFF59E0B),
    activeLetter: Color(0xFF0F172A),
    activeBorder: Color(0xFFFFFFFF),
    word: Color(0xFFDBEAFE),
    correct: Color(0xFFDCFCE7),
    wrong: Color(0xFFFEE2E2),
    revealed: Color(0xFFE0E7FF),
    letter: Color(0xFF0F172A),
    letterCorrect: Color(0xFF166534),
    letterWrong: Color(0xFFB91C1C),
    letterRevealed: Color(0xFF3730A3),
    number: Color(0xFF64748B),
    key: Color(0xFFFFFFFF),
    keyShadow: Color(0xFFCBD5E1),
    keyControl: Color(0xFFCBD5E1),
    keyControlShadow: Color(0xFF94A3B8),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE2E8F0),
    accent: Color(0xFF2563EB),
    onAccent: Color(0xFFFFFFFF),
    muted: Color(0xFF64748B),
  );

  static CrosswordPalette of(Brightness b) =>
      b == Brightness.dark ? dark : light;

  /// Screen, board container and its soft shadow.
  final Color background, board, boardShadow;

  /// Black tiles; writable tiles and the solid edge under them.
  final Color block, cell, cellShadow;

  /// Selected cell (with its letter and border) and the rest of its word.
  final Color active, activeLetter, activeBorder, word;

  /// Checked / revealed cells.
  final Color correct, wrong, revealed;
  final Color letter, letterCorrect, letterWrong, letterRevealed, number;

  /// Keyboard: letter keys, control keys, and the solid edge under each.
  final Color key, keyShadow, keyControl, keyControlShadow;

  /// Cards, sheets, badges and buttons.
  final Color card, cardBorder, accent, onAccent, muted;
}

ThemeData buildAppTheme(Brightness brightness) {
  final pal = CrosswordPalette.of(brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: pal.accent,
    brightness: brightness,
  ).copyWith(
    primary: pal.accent,
    onPrimary: pal.onAccent,
    surface: pal.background,
    onSurface: pal.letter,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  const label = TextStyle(
    fontFamily: appFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    scaffoldBackgroundColor: pal.background,
    appBarTheme: AppBarTheme(
      backgroundColor: pal.background,
      foregroundColor: pal.letter,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: pal.letter,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: pal.card),
    popupMenuTheme: PopupMenuThemeData(color: pal.card),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: pal.accent,
        foregroundColor: pal.onAccent,
        minimumSize: const Size(0, 46),
        shape: rounded,
        textStyle: label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: pal.letter,
        minimumSize: const Size(0, 46),
        side: BorderSide(color: pal.cardBorder, width: 1.5),
        shape: rounded,
        textStyle: label,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: pal.muted,
        minimumSize: const Size(0, 44),
        shape: rounded,
        textStyle: label,
      ),
    ),
  );
}

/// Small round surface for app-bar and card icons.
class RoundIcon extends StatelessWidget {
  const RoundIcon(this.icon, {super.key, this.size = 38});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pal = CrosswordPalette.of(Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: pal.board, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.52, color: pal.letter),
    );
  }
}
