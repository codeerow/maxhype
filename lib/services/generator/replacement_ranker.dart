import '../../models/exercise.dart';
import '../../models/generator/experience_level.dart';
import '../../models/generator/generator_metadata.dart';

/// Ranks replacement candidates for the "Replace Exercise" flow, mirroring the
/// web prototype's `openReplacePicker` selection 1:1 (script.js ~19248).
///
/// The prototype does NOT return a plain muscle-group list — it builds a pool
/// from the same body part, filters by replacement eligibility and experience,
/// then sorts by a multi-tier key: history frequency → movement-pattern
/// affinity → equipment continuity → stable-first → alphabetical. This engine
/// reproduces that ordering so the Flutter Replace picker offers the same
/// alternatives in the same order.
///
/// Pure and stateless: callers pass the candidate universe and (optionally) a
/// history-frequency map; nothing here touches storage or the UI.
class ReplacementRanker {
  const ReplacementRanker();

  /// Ordered replacement candidates for [original].
  ///
  /// [universe] is the full exercise library to draw from. [alreadyUsed] are
  /// the names in the current workout (excluded so a replacement can't
  /// duplicate an existing pick). [experience] gates candidates the same way
  /// generation does. [historyFrequency] maps an exercise name to how often it
  /// appears in the user's history; higher sorts first (empty ⇒ tier ignored,
  /// matching a user with no history).
  List<Exercise> rank(
    Exercise original, {
    required List<Exercise> universe,
    required Set<String> alreadyUsed,
    required ExperienceLevel experience,
    Map<String, int> historyFrequency = const {},
  }) {
    final origMeta = original.generatorMeta;
    final origBodyPart = origMeta?.bodyPart.label;

    final pool = <Exercise>[];
    for (final cand in universe) {
      final meta = cand.generatorMeta;
      if (cand.name == original.name) continue;
      if (alreadyUsed.contains(cand.name)) continue;
      // Same body part as the original (prototype pools by bodyPart, not the
      // coarse muscle group). When the original has no metadata we can't scope
      // by body part, so fall back to "everything eligible".
      if (origBodyPart != null && meta?.bodyPart.label != origBodyPart) {
        continue;
      }
      if (!_isAllowedInReplacementPool(meta)) continue;
      if (!_isAllowedForExperience(meta, experience)) continue;
      pool.add(cand);
    }

    pool.sort((a, b) {
      // 1. History frequency (most-used first).
      final fa = historyFrequency[a.name] ?? 0;
      final fb = historyFrequency[b.name] ?? 0;
      if (fb != fa) return fb - fa;
      // 2. Movement-pattern affinity to the original.
      final aff =
          _movementAffinity(original, b.generatorMeta) -
          _movementAffinity(original, a.generatorMeta);
      if (aff != 0) return aff;
      // 3. Equipment continuity with the original.
      final eq =
          _equipmentContinuity(origMeta, b.generatorMeta) -
          _equipmentContinuity(origMeta, a.generatorMeta);
      if (eq != 0) return eq;
      // 4. Stable defaults first.
      final sa = a.generatorMeta?.stable ?? false;
      final sb = b.generatorMeta?.stable ?? false;
      if (sa != sb) return sa ? -1 : 1;
      // 5. Alphabetical.
      return a.name.compareTo(b.name);
    });

    return pool;
  }

  /// Replacement-pool eligibility: a `generatorExclude` exercise is blocked
  /// unless it explicitly opts in with `replaceOnly` (script.js 18991).
  static bool _isAllowedInReplacementPool(GeneratorMetadata? meta) {
    if (meta == null) return true;
    if (meta.generatorExclude && !meta.replaceOnly) return false;
    return true;
  }

  static bool _isAllowedForExperience(
    GeneratorMetadata? meta,
    ExperienceLevel level,
  ) {
    if (meta == null) return true;
    // Only the lower bound applies to manual replacement. [maxExperience] gates
    // *auto-generation* (e.g. Smith Machine for advanced users); a manual
    // replacement is an explicit user choice — the prototype's `unless
    // favorited/preferred` carve-out — so an advanced user may still swap in a
    // maxExperience-capped exercise on purpose.
    return level.rank >= meta.minExperience.rank;
  }

  /// Movement-pattern affinity of a candidate to the original — the strongest
  /// single signal wins (script.js 19010). 100 → 60 → 40 → 20 → 10 → 0.
  static int _movementAffinity(Exercise original, GeneratorMetadata? cand) {
    final orig = original.generatorMeta;
    if (orig == null || cand == null) return 0;
    if (orig.movementPattern != null &&
        orig.movementPattern == cand.movementPattern) {
      return 100;
    }
    if (orig.category == cand.category) return 60;
    if (orig.primaryMuscle != null &&
        orig.primaryMuscle == cand.primaryMuscle &&
        orig.jointPattern != null &&
        orig.jointPattern == cand.jointPattern) {
      return 40;
    }
    if (orig.primaryMuscle != null &&
        orig.primaryMuscle == cand.primaryMuscle) {
      return 20;
    }
    if (orig.stimulusType != null && orig.stimulusType == cand.stimulusType) {
      return 10;
    }
    return 0;
  }

  /// Equipment continuity: same equipment 50, same family 20, else 0
  /// (script.js 19049).
  static int _equipmentContinuity(
    GeneratorMetadata? orig,
    GeneratorMetadata? cand,
  ) {
    if (orig == null || cand == null) return 0;
    final oe = orig.equipment.label;
    final ce = cand.equipment.label;
    if (oe == ce) return 50;
    final of = _equipmentFamily[oe];
    final cf = _equipmentFamily[ce];
    if (of != null && cf != null && of == cf) return 20;
    return 0;
  }

  /// Equipment families for continuity scoring (script.js 19038).
  static const Map<String, String> _equipmentFamily = {
    'Barbell': 'freeweight',
    'Dumbbell': 'freeweight',
    'Kettlebell': 'freeweight',
    'Machine': 'stationary',
    'Plate-Loaded': 'stationary',
    'Smith Machine': 'stationary',
    'Cable': 'cable_like',
    'Landmine': 'cable_like',
    'Bodyweight': 'bodyweight',
  };
}
