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

  /// Picks one item from a score-ranked list, mirroring the prototype's
  /// `weightedPickFromTop`. [scored] must be sorted by score descending.
  ///
  /// The prototype's selection is deliberately stochastic so repeated builds
  /// vary while still favoring high-scoring candidates:
  ///   * Empty → null; single → that item.
  ///   * Small pool (≤5): square-root-compress the shifted score
  ///     (`pow(score - minScore + 1, 0.5)`) and add `[0, 0.5)` jitter, so the
  ///     top candidate can't dominate a tiny pool.
  ///   * Larger pool (>5): sqrt-compress positive scores toward the max, take
  ///     the top [topK] (=7), convert to weights `(score - minScore) + 1`
  ///     floored at 1, then scale each by `0.7 + rand*0.6` ([0.7, 1.3]).
  ///
  /// Ported verbatim from script.js `weightedPickFromTop` (lines 7958-8050) so
  /// selection statistics match the web prototype.
  T? weightedPickFromTop<T>(
    List<({T item, double score})> scored, {
    int topK = 7,
  }) {
    if (scored.isEmpty) return null;
    if (scored.length == 1) return scored.first.item;

    // Small-pool flattening: 2–5 candidates.
    if (scored.length <= 5) {
      final smMin = scored.last.score;
      final weights = <double>[];
      for (final s in scored) {
        weights.add(pow(s.score - smMin + 1, 0.5).toDouble() +
            _random.nextDouble() * 0.5);
      }
      return _rollWeighted(scored, weights);
    }

    // Larger pool: sqrt-compress positive scores toward the max, then TOP_K.
    final maxScore = scored.first.score;
    final compressed = <({T item, double score})>[];
    for (final s in scored) {
      var score = s.score;
      if (maxScore > 0 && score > 0) {
        score = maxScore * pow(score / maxScore, 0.5).toDouble();
      }
      compressed.add((item: s.item, score: score));
    }

    final k = topK < compressed.length ? topK : compressed.length;
    final top = compressed.sublist(0, k);
    final minScore = top.last.score;
    final weights = <double>[
      for (final t in top)
        (((t.score - minScore) + 1).clamp(1, double.infinity) as double) *
            (0.7 + _random.nextDouble() * 0.6),
    ];
    return _rollWeighted(top, weights);
  }

  /// Weighted roulette over a scored list using the given parallel [weights].
  T _rollWeighted<T>(
    List<({T item, double score})> scored,
    List<double> weights,
  ) {
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    var roll = _random.nextDouble() * total;
    for (var i = 0; i < scored.length; i++) {
      roll -= weights[i];
      if (roll < 0) return scored[i].item;
    }
    return scored.last.item; // floating-point guard
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
