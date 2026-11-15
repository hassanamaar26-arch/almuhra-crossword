import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/crossword_controller.dart';
import '../theme.dart';

/// The 30 letters of [arabicAlphabet] in three rows, in reading order
/// (the first letter of each row is drawn on the right).
const List<List<String>> arabicKeyboardRows = [
  ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج'],
  ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك'],
  ['ظ', 'ط', 'ذ', 'د', 'ز', 'ر', 'و', 'ى', 'ء'],
];

/// Built-in Arabic keyboard with raised keycaps. The system keyboard is
/// never opened.
class ArabicKeyboard extends StatelessWidget {
  const ArabicKeyboard({super.key, required this.controller, this.palette});

  static const double keyHeight = 46;

  final CrosswordController controller;
  final CrosswordPalette? palette;

  @override
  Widget build(BuildContext context) {
    final pal = palette ?? CrosswordPalette.of(Theme.of(context).brightness);

    Widget letter(String l) => _Key(
          key: ValueKey('key-$l'),
          color: pal.key,
          shadow: pal.keyShadow,
          onTap: () => controller.input(l),
          child: Text(
            l,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: pal.letter,
            ),
          ),
        );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
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
                  shadow: pal.keyControlShadow,
                  semanticLabel: 'تبديل الاتجاه',
                  onTap: controller.toggleDirection,
                  child: Icon(Icons.sync_alt, size: 22, color: pal.letter),
                ),
                for (final l in arabicKeyboardRows[2]) letter(l),
                _Key(
                  key: const ValueKey('key-backspace'),
                  color: pal.keyControl,
                  shadow: pal.keyControlShadow,
                  semanticLabel: 'حذف',
                  onTap: controller.backspace,
                  child: Icon(
                    Icons.backspace_outlined,
                    size: 22,
                    color: pal.letter,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One keycap: a solid lower edge that the key sinks into while pressed.
class _Key extends StatefulWidget {
  const _Key({
    super.key,
    required this.color,
    required this.shadow,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });

  final Color color;
  final Color shadow;
  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  static const double _depth = 2;
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Semantics(
        label: widget.semanticLabel,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 2 + _depth),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              height: ArabicKeyboard.keyHeight,
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, _down ? _depth : 0, 0),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: widget.shadow,
                    offset: Offset(0, _down ? 0 : _depth),
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
