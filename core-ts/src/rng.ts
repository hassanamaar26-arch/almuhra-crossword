// Deterministic 32-bit integer PRNG (mulberry32) seeded by FNV-1a of the UTF-8 seed.
// Integer-only so the Dart port produces the exact same sequence.

export class Rng {
  private s: number;

  constructor(seed: string) {
    let h = 0x811c9dc5;
    for (const b of new TextEncoder().encode(seed)) {
      h ^= b;
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    this.s = h;
  }

  /** Next unsigned 32-bit integer. */
  next(): number {
    this.s = (this.s + 0x6d2b79f5) >>> 0;
    let t = this.s;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t = (t ^ (t + Math.imul(t ^ (t >>> 7), t | 61))) >>> 0;
    return (t ^ (t >>> 14)) >>> 0;
  }

  /** Integer in [0, n). */
  int(n: number): number {
    return this.next() % n;
  }

  shuffle<T>(a: T[]): void {
    for (let i = a.length - 1; i > 0; i--) {
      const j = this.int(i + 1);
      [a[i], a[j]] = [a[j], a[i]];
    }
  }
}
