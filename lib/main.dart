import 'package:flutter/material.dart';

import 'core/generator/generator.dart';
import 'core/generator/word_bank.dart';
import 'screens/home_screen.dart';
import 'state/app_controller.dart';
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
    this.store,
    this.generator,
    this.now,
  });

  final List<BankEntry>? bank;
  final KeyValueStore? store;
  final PuzzleGenerator? generator;
  final DateTime Function()? now;

  @override
  State<CrosswordApp> createState() => _CrosswordAppState();
}

class _CrosswordAppState extends State<CrosswordApp>
    with WidgetsBindingObserver {
  AppController? _app;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final AppController app;
    try {
      app = AppController(
        store: widget.store ?? SharedPrefsStore(),
        bank: widget.bank ?? await loadWordBank(),
        generator: widget.generator,
        now: widget.now,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e);
      return;
    }
    try {
      await app.init();
    } catch (e) {
      app.dispose();
      if (mounted) setState(() => _error = e);
      return;
    }
    if (!mounted) {
      app.dispose();
      return;
    }
    final ready = app;
    setState(() => _app = ready);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = _app;
    if (app == null) return;
    if (state == AppLifecycleState.resumed) {
      app.appResumed();
    } else {
      app.appPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _app?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app == null) return _material(ThemeMode.system, _loading());
    return ListenableBuilder(
      listenable: app.settings,
      builder: (context, _) =>
          _material(app.settings.themeMode, HomeScreen(app: app)),
    );
  }

  Widget _material(ThemeMode mode, Widget home) {
    return MaterialApp(
      title: 'الكلمات المتقاطعة (المُهرة)',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFB8811A)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFB8811A),
        brightness: Brightness.dark,
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: home,
    );
  }

  Widget _loading() {
    return Scaffold(
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
    );
  }
}
