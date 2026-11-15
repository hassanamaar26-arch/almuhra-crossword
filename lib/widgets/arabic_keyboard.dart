import 'package:flutter/material.dart';

import '../state/crossword_controller.dart';
import 'crossword_grid.dart';

/// The 30 letters of [arabicAlphabet] in three rows, in reading order
/// (the first letter of each row is drawn on the right).
const List<List<String>> arabicKeyboardRows = [
  ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج'],
  ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك'],
  ['ظ', 'ط', 'ذ', 'د', 'ز', 'ر', 'و', 'ى', 'ء'],
];

/// Built-in Arabic keyboard. The system keyboard is never opened.
class ArabicKeyboard extends StatelessWidget {
  const ArabicKeyboard({super.key, required this.controller, this.palette});

  static const double keyHeight = 44;

  final CrosswordController controller;
  final CrosswordPalette? palette;

  @override
  Widget build(BuildContext context) {
    final pal = palette ?? CrosswordPalette.of(Theme.of(context).brightness);

    Widget letter(String l) => _Key(
          key: ValueKey('key-$l'),
          color: pal.key,
          onTap: () => controller.input(l),
          child: Text(
            l,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: pal.letter,
            ),
          ),
        );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 4, 3, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [for (final l in arabicKeyboardRows[0]) letter(l)]),
            Row(
              children: [
                const Spacer(),
                for (final l in arabicKeyboardRows[1]) letter(l),
                const Spacer(),
              ],
            ),
            Row(
              children: [
                _Key(
                  key: const ValueKey('key-toggle'),
                  color: pal.keyControl,
                  semanticLabel: 'تبديل الاتجاه',
                  onTap: controller.toggleDirection,
                  child: Icon(Icons.sync_alt, size: 20, color: pal.letter),
                ),
                for (final l in arabicKeyboardRows[2]) letter(l),
                _Key(
                  key: const ValueKey('key-backspace'),
                  color: pal.keyControl,
                  semanticLabel: 'حذف',
                  onTap: controller.backspace,
                  child: Icon(Icons.backspace_outlined, size: 20, color: pal.letter),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.color,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });

  final Color color;
  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Semantics(
          label: semanticLabel,
          button: true,
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: ArabicKeyboard.keyHeight,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
