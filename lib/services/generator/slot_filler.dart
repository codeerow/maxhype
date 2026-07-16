import '../../models/exercise.dart';
import '../../models/generator/exercise_taxonomy.dart';
import '../../models/generator/experience_level.dart';
import '../../models/generator/generator_slot.dart';
import '../../repositories/asset_exercise_repository.dart';
import 'build_state.dart';
import 'exercise_scorer.dart';
import 'seeded_rng.dart';

/// Resolves one slot to an exercise, porting the prototype's multi-pass
/// fallback. Used by the generator's fill loop.
///
/// The pass structure (eligibility + duplicate/movement-group diversity, then
/// a pick from the survivors) is stable across 2A/2B. Part 2B replaces the pick
/// step with the ported scoring engine: each surviving candidate is scored by
/// [ExerciseScorer] (equipment preference, movement-group diversity, shoulder
/// & dips ecosystem rules), a FIRST_SLOT_TIER soft filter shapes the opener,
/// and the final choice is a stochastic [SeededRng.weightedPickFromTop] over
/// the top-ranked candidates. Every slot still resolves to a real exercise (or
/// its default), so workouts stay valid and playable.
class SlotFiller {
  final AssetExerciseRepository repo;
  final ExerciseScorer _scorer;

  SlotFiller(this.repo, {ExerciseScorer? scorer})
      : _scorer = scorer ?? const ExerciseScorer();

  /// `FIRST_SLOT_TIER` (script.js:1661). For the first exercise of a category
  /// in a split, restrict candidates to these tiers (soft filter — applied only
  /// if it leaves a non-empty pool). Ensures a workout opens on a proper
  /// primary compound rather than an accessory that merely shares the category.
  static const Map<String, Map<String, List<ExerciseTier>>> _firstSlotTier = {
    'Push Day': {
      'chest press': [ExerciseTier.a, ExerciseTier.b],
      'shoulder press': [ExerciseTier.a, ExerciseTier.b],
    },
    'Pull Day': {
      'row': [ExerciseTier.a],
      'pulldown': [ExerciseTier.a],
    },
    'Legs + Core': {
      'squat': [ExerciseTier.a],
      'hinge': [ExerciseTier.a, ExerciseTier.b],
    },
  };

  /// Resolves [slot] against the current [state]. Returns the picked exercise,
  /// or null only if even the default can't resolve (should not happen given
  /// the extractor asserts every default is a real library exercise).
  Exercise? fill(
    GeneratorSlot slot,
    BuildState state,
    ExperienceLevel experience,
    SeededRng rng,
  ) {
    // The Push triceps_push slot randomizes its form ~30% of the time.
    final effective = _resolveRandomVariant(slot, rng);

    // Pass 1: unified pool weighted by categoryBias (when unifyPool), else a
    // strict per-category walk in priority order. Movement-group diversity is
    // preferred here (duplicate groups excluded).
    final picked = _pickFromPool(effective, state, experience, rng,
            allowGroupReuse: false) ??
        // Pass 2: relax movement-group diversity (name dedup + caps still hold),
        // so a slot whose fresh groups are exhausted can still fill.
        _pickFromPool(effective, state, experience, rng,
            allowGroupReuse: true) ??
        // Pass 3: default exercise, if still eligible and not already used.
        _pickDefault(effective, state, experience);

    return picked;
  }

  /// Applies the slot's random-variant coin flip (e.g. triceps_push swapping to
  /// a compound-press-primary category order ~30% of the time).
  GeneratorSlot _resolveRandomVariant(GeneratorSlot slot, SeededRng rng) {
    final rv = slot.randomVariant;
    if (rv == null) return slot;
    return rng.chance(rv.probability) ? rv.alt : slot;
  }

  /// Builds the candidate pool for the slot and picks one, honoring
  /// eligibility, dedup, slot filters, and categoryBias weighting.
  Exercise? _pickFromPool(
    GeneratorSlot slot,
    BuildState state,
    ExperienceLevel experience,
    SeededRng rng, {
    required bool allowGroupReuse,
  }) {
    // Gather candidates across the slot's category pool (priority order).
    final candidates = <Exercise>[];
    final seen = <String>{};
    for (final category in slot.categories) {
      for (final ex in repo.getExercisesByCategory(category)) {
        if (seen.add(ex.id)) candidates.add(ex);
      }
    }

    var eligible = candidates
        .where((ex) => _isEligible(ex, slot, state, experience,
            allowGroupReuse: allowGroupReuse))
        .toList();
    if (eligible.isEmpty) return null;

    // FIRST_SLOT_TIER: if this is the first exercise of its category in the
    // build, prefer the allowed opening tiers (soft — only if some survive).
    eligible = _applyFirstSlotTier(eligible, slot, state);

    // Score every candidate with the ported base engine, then pick
    // stochastically from the top via weightedPickFromTop. The slot's
    // categoryBias (unifyPool) is added on top of the base score as the
    // prototype does — a positive category bias lifts, a negative one lowers,
    // without ever hard-zeroing a candidate.
    final bias = slot.categoryBias;
    final scored = <({Exercise item, double score})>[
      for (final ex in eligible)
        (
          item: ex,
          score: _scorer.scoreOf(ex, slot, state, experience) +
              (bias?[ex.generatorMeta?.category] ?? 0).toDouble(),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    return rng.weightedPickFromTop(scored);
  }

  /// Applies the FIRST_SLOT_TIER soft filter. If [slot]'s primary category has
  /// an opening-tier rule for this split, and no exercise of that category has
  /// been committed yet, keep only candidates whose tier is allowed — but only
  /// if that leaves at least one candidate (otherwise fall back to the full
  /// pool, exactly like the prototype).
  List<Exercise> _applyFirstSlotTier(
    List<Exercise> eligible,
    GeneratorSlot slot,
    BuildState state,
  ) {
    final byCategory = _firstSlotTier[state.split];
    final category = slot.category;
    if (byCategory == null || category == null) return eligible;
    final allowed = byCategory[category];
    if (allowed == null) return eligible;

    // Is this already-not the first of its category? Then no restriction.
    final alreadyHasCategory =
        state.exercises.any((e) => e.generatorMeta?.category == category);
    if (alreadyHasCategory) return eligible;

    final filtered = eligible
        .where((ex) {
          final tier = ex.generatorMeta?.tier;
          return tier != null && allowed.contains(tier);
        })
        .toList();
    return filtered.isNotEmpty ? filtered : eligible;
  }

  /// Eligibility for automatic generation in this slot.
  bool _isEligible(
    Exercise ex,
    GeneratorSlot slot,
    BuildState state,
    ExperienceLevel experience, {
    required bool allowGroupReuse,
  }) {
    final meta = ex.generatorMeta;
    if (meta == null) return false;
    // Generation eligibility: min-experience + replaceOnly/generatorExclude.
    if (!meta.isGeneratableAt(experience)) return false;
    // Duplicate name — always a hard block.
    if (state.isNameUsed(ex.name)) return false;
    // Movement-group diversity (relaxed on the second pass).
    final mg = meta.movementGroup;
    if (!allowGroupReuse && mg != null && state.usedMovementGroups.contains(mg)) {
      return false;
    }
    // Slot-level movement-group exclusion (e.g. triceps_stretch excludes
    // pushdown/kickback groups).
    if (slot.excludeMovementGroups != null &&
        mg != null &&
        slot.excludeMovementGroups!.contains(mg)) {
      return false;
    }
    // Slot-level keyword preference — soft in the prototype, but on the strict
    // passes we honor it; the default pass ignores it as a last resort.
    final keywords = slot.includeNameKeywords;
    if (keywords != null && keywords.isNotEmpty) {
      final lower = ex.name.toLowerCase();
      if (!keywords.any(lower.contains)) return false;
    }
    return true;
  }

  /// Last resort: the slot's declared default exercise, if usable.
  Exercise? _pickDefault(
    GeneratorSlot slot,
    BuildState state,
    ExperienceLevel experience,
  ) {
    final name = slot.defaultExercise;
    if (name == null) return null;
    final ex = repo.getExerciseByName(name);
    if (ex == null) return null;
    if (state.isNameUsed(ex.name)) return null;
    // Prefer to keep the default within the user's experience: if the curated
    // default is gated above them, don't force an out-of-experience exercise
    // into a beginner's workout. (With composite categories resolved, the pool
    // passes almost always fill the slot before we ever reach here.)
    final meta = ex.generatorMeta;
    if (meta != null && !meta.isGeneratableAt(experience)) return null;
    return ex;
  }
}
