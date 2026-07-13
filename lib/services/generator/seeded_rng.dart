import 'dart:math';

/// Seedable random source for the workout generator.
///
/// The web prototype scatters 51 `Math.random()` calls through selection and
/// scoring, which makes its output non-reproducible. Routing every random
/// decision through one [SeededRng] lets production preserve variety (seed from
/// a time/counter) while tests pin a fixed seed and assert exact, reproducible
/// output. Dart's [Random] is already a deterministic PRNG for a given seed;
/// this wraps it with the few primitives the generator needs.
class SeededRng {
  final Random _random;

  SeededRng(int seed) : _random = Random(seed);

  /// Double in [0, 1).
  double nextDouble() => _random.nextDouble();

  /// Double in [min, max).
  double nextRange(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  /// Integer in [0, max).
  int nextInt(int max) => _random.nextInt(max);

  /// True with the given [probability] (clamped to [0, 1]).
  /// Mirrors the prototype's `Math.random() < p` coin flips.
  bool chance(double probability) => _random.nextDouble() < probability;

  /// Uniformly picks one element. Throws on an empty list.
  T pick<T>(List<T> items) {
    if (items.isEmpty) {
      throw ArgumentError('pick() on empty list');
    }
    return items[_random.nextInt(items.length)];
  }

  /// Picks an index proportional to [weights]. Weights must be non-negative and
  /// sum to > 0. Mirrors the prototype's weighted roulette selection.
  int weightedIndex(List<double> weights) {
    var total = 0.0;
    for (final w in weights) {
      total += w < 0 ? 0 : w;
    }
    if (total <= 0) {
      // Degenerate: fall back to uniform over the range.
      return _random.nextInt(weights.length);
    }
    var roll = _random.nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      final w = weights[i] < 0 ? 0 : weights[i];
      if (roll < w) return i;
      roll -= w;
    }
    return weights.length - 1; // floating-point guard
  }

  /// Weighted pick of an item, parallel arrays. Throws on empty.
  T weightedPick<T>(List<T> items, List<double> weights) {
    if (items.isEmpty) throw ArgumentError('weightedPick() on empty list');
    return items[weightedIndex(weights)];
  }

  /// In-place Fisher–Yates shuffle.
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }
}
