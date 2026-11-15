import 'package:flutter/material.dart';

import 'core/generator/generator.dart';
import 'core/generator/word_bank.dart';
import 'screens/practice_screen.dart';
import 'state/practice_session.dart';
import 'storage/game_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CrosswordApp());
}

/// The optional parameters replace the real word bank, storage, generator
/// and clock in tests.
class CrosswordApp extends StatefulWidget {
  const CrosswordApp({
    super.key,
    this.bank,
    this.storage,
    this.generator,
    this.now,
  });

  final List<BankEntry>? bank;
  final GameStorage? storage;
  final PuzzleGenerator? generator;
  final DateTime Function()? now;

  @override
  State<CrosswordApp> createState() => _CrosswordAppState();
}

class _CrosswordAppState extends State<CrosswordApp>
    with WidgetsBindingObserver {
  PracticeSession? _session;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final PracticeSession session;
    try {
      final bank = widget.bank ?? await loadWordBank();
      session = PracticeSession(
        bank: bank,
        storage: widget.storage ?? SharedPrefsGameStorage(),
        generator: widget.generator,
        now: widget.now,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e);
      return;
    }
    try {
      await session.start();
    } catch (e) {
      session.dispose();
      if (mounted) setState(() => _error = e);
      return;
    }
    if (!mounted) {
      session.dispose();
      return;
    }
    final ready = session;
    setState(() => _session = ready);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = _session;
    if (session == null) return;
    if (state == AppLifecycleState.resumed) {
      session.resume();
    } else {
      session.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
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
      home: session != null
          ? PracticeScreen(session: session)
          : Scaffold(
              body: Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'تعذّر تشغيل اللعبة.\n$_error',
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
    );
  }
}
