import 'dart:convert';

// Deterministic 32-bit PRNG (mulberry32) seeded by FNV-1a of the UTF-8 seed.
// Must produce the exact sequence of core-ts/src/rng.ts — see the fixtures.
// All math stays below 2^53 so it is also correct when compiled to JS.

const int _mask = 0xFFFFFFFF;

/// 32-bit multiply (like JS Math.imul, but unsigned).
int _imul(int a, int b) {
  final ah = (a >> 16) & 0xFFFF;
  final al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF;
  final bl = b & 0xFFFF;
  final mid = (ah * bl + al * bh) & 0xFFFF;
  return (al * bl + mid * 0x10000) & _mask;
}

class SeedRng {
  SeedRng(String seed) {
    var h = 0x811c9dc5;
    for (final b in utf8.encode(seed)) {
      h = (h ^ b) & _mask;
      h = _imul(h, 0x01000193);
    }
    _s = h;
  }

  late int _s;

  /// Next unsigned 32-bit integer.
  int next() {
    _s = (_s + 0x6d2b79f5) & _mask;
    var t = _s;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & _mask)) & _mask;
    return (t ^ (t >> 14)) & _mask;
  }

  /// Integer in [0, n).
  int nextInt(int n) => next() % n;

  void shuffle<T>(List<T> a) {
    for (var i = a.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = a[i];
      a[i] = a[j];
      a[j] = tmp;
    }
  }
}
