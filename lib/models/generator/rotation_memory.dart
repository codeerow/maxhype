import '../exercise.dart';

/// Cross-session rotation memory, ported from the web prototype's
/// `maxhype-rotation-memory` localStorage store.
///
/// Shape: `split → bucket → [exercise names]`, newest last, at most
/// [maxPerBucket] per bucket. The generator reads this to steer away from
/// recently-trained exercises; it is written only when a workout is COMPLETED
/// (never during generation), so generation stays a pure, seedable function of
/// its inputs — the memory is passed in as plain data.
///
/// Faithful to script.js: getRotationBucket (11293), applyRotationMemoryPenalty
/// (11337, -50 exact / -20 bucket-pressure, clamp -50, pool>=2 gate),
/// updateRotationMemoryForWorkout (11376, dedup-then-append, trim to 4).
class RotationMemory {
  /// split → bucket → recent exercise names (oldest first, newest last).
  final Map<String, Map<String, List<String>>> _bySplit;

  const RotationMemory(this._bySplit);

  /// An empty memory — the default for generation with no history (tests, or a
  /// fresh install). Produces zero rotation penalty everywhere.
  const RotationMemory.empty() : _bySplit = const {};

  /// Max exercises retained per bucket (script.js:11401 `while > 4 shift`).
  static const int maxPerBucket = 4;

  /// Penalty for an exact recent match (script.js:11368).
  static const double exactMatchPenalty = -50;

  /// Additional penalty when the bucket already holds >=2 recent items
  /// (script.js:11371).
  static const double bucketPressurePenalty = -20;

  /// Floor the combined penalty is clamped to (script.js:11375).
  static const double penaltyFloor = -50;

  /// The recent names stored for [split]/[bucket] (empty if none).
  List<String> recentFor(String split, String bucket) =>
      _bySplit[split]?[bucket] ?? const [];

  /// The rotation penalty for [candidate] in [split], given the surviving pool
  /// size [poolSize]. Returns 0 (no pressure) when the pool has fewer than two
  /// candidates — a single-option slot must never be constrained
  /// (script.js:11339). Penalty is clamped to [penaltyFloor].
  double penaltyFor(Exercise candidate, String split, int poolSize) {
    if (poolSize < 2) return 0;
    final bucket = bucketOf(split, candidate);
    final recent = recentFor(split, bucket);
    final needle = _normalize(candidate.name);

    var penalty = 0.0;
    final matched = recent.any((n) => _normalize(n) == needle);
    if (matched) penalty += exactMatchPenalty;
    if (recent.length >= 2) penalty += bucketPressurePenalty;

    return penalty < penaltyFloor ? penaltyFloor : penalty;
  }

  /// Returns a new memory with [exercises] (a completed [split] workout)
  /// recorded: each exercise is deduped from its bucket then appended, and the
  /// bucket trimmed to [maxPerBucket]. Pure — the caller persists the result.
  RotationMemory recordCompletion(String split, List<Exercise> exercises) {
    if (exercises.isEmpty) return this;
    // Deep-copy the current store so this stays immutable.
    final next = <String, Map<String, List<String>>>{
      for (final s in _bySplit.entries)
        s.key: {for (final b in s.value.entries) b.key: List.of(b.value)},
    };
    final splitMap = next.putIfAbsent(split, () => {});
    for (final ex in exercises) {
      // Only exercises carrying generator metadata bucket meaningfully; others
      // (e.g. a manually-added exercise with no category) fall to the split's
      // fallback bucket, matching the prototype's "*_other".
      final bucket = bucketOf(split, ex);
      final arr = splitMap.putIfAbsent(bucket, () => []);
      final norm = _normalize(ex.name);
      arr.removeWhere((n) => _normalize(n) == norm);
      arr.add(ex.name);
      while (arr.length > maxPerBucket) {
        arr.removeAt(0);
      }
    }
    return RotationMemory(next);
  }

  /// The rotation bucket for an exercise in [split] (script.js:11293
  /// `getRotationBucket`). Category-driven, with name/bodyPart fallbacks for
  /// curl detection. Returns a split-specific "*_other" fallback (or "other").
  String bucketOf(String split, Exercise ex) {
    final meta = ex.generatorMeta;
    final name = ex.name.toLowerCase();
    final cat = (meta?.category ?? '').toLowerCase();
    final bp = (meta?.bodyPart.label ?? '').toLowerCase();

    switch (split) {
      case 'Push Day':
        if (cat == 'chest fly') return 'chest_iso';
        if (cat == 'chest press' ||
            cat == 'incline press' ||
            cat == 'decline press') {
          return 'chest_compound';
        }
        if (cat == 'shoulder press') return 'shoulder_compound';
        if (cat == 'side delt' ||
            cat == 'front delt' ||
            name.contains('lateral raise')) {
          return 'shoulder_iso';
        }
        if (cat == 'compound press' || cat == 'triceps') return 'triceps';
        return 'push_other';
      case 'Pull Day':
        if (cat == 'pulldown') return 'lats';
        if (cat == 'row' || cat == 'upright row') return 'upper_back';
        if (cat == 'rear delt') return 'rear_delt';
        if (cat == 'biceps' ||
            (cat != 'forearms' && name.contains('curl') && bp != 'forearms')) {
          return 'biceps';
        }
        if (cat == 'shrug' || cat == 'forearms') return 'support';
        return 'pull_other';
      case 'Legs + Core':
        if (cat == 'squat' || cat == 'quad' || cat == 'lunge') return 'quads';
        if (cat == 'hinge' || cat == 'hamstring curl') return 'hamstrings';
        if (cat == 'hip thrust' ||
            cat == 'kickback' ||
            cat == 'hip abduction' ||
            cat == 'hip adduction') {
          return 'glutes';
        }
        if (cat == 'calf raise') return 'calves';
        if (cat == 'back extension' ||
            cat == 'abs' ||
            cat == 'core accessory' ||
            cat == 'crunch' ||
            cat == 'plank' ||
            cat == 'leg raise' ||
            cat == 'rotation' ||
            cat == 'dynamic core') {
          return 'core';
        }
        return 'legs_other';
      default:
        return 'other';
    }
  }

  /// Strict normalization for name comparison (script.js normalizeExerciseName):
  /// lowercase, trim, collapse internal whitespace.
  static String _normalize(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Serializes to the persisted shape `{split: {bucket: [names]}}`.
  Map<String, dynamic> toJson() => {
        for (final s in _bySplit.entries)
          s.key: {for (final b in s.value.entries) b.key: b.value},
      };

  factory RotationMemory.fromJson(Map<String, dynamic> json) {
    final out = <String, Map<String, List<String>>>{};
    json.forEach((split, buckets) {
      final bucketMap = <String, List<String>>{};
      (buckets as Map<String, dynamic>).forEach((bucket, names) {
        bucketMap[bucket] = (names as List<dynamic>).cast<String>();
      });
      out[split] = bucketMap;
    });
    return RotationMemory(out);
  }
}
