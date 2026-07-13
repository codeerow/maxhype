import '../../models/exercise.dart';
import '../../models/generator/experience_level.dart';
import '../../models/generator/generator_slot.dart';
import '../../repositories/asset_exercise_repository.dart';
import 'build_state.dart';
import 'seeded_rng.dart';

/// Resolves one slot to an exercise, porting the prototype's multi-pass
/// fallback. Used by the generator's fill loop.
///
/// The prototype layers a ~2,200-line scoring engine on top of this (Part 2B).
/// For 2A the selection is deliberately simpler but invariant-safe: eligibility
/// + duplicate prevention + movement-group diversity, then a bias-weighted pick
/// from the surviving candidates. Every slot still resolves to a real exercise
/// (or its default), so 2A workouts are valid and playable; 2B swaps the pick
/// step for the full scoring without changing this pass structure.
class SlotFiller {
  final AssetExerciseRepository repo;

  SlotFiller(this.repo);

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

    final eligible = candidates
        .where((ex) => _isEligible(ex, slot, state, experience,
            allowGroupReuse: allowGroupReuse))
        .toList();
    if (eligible.isEmpty) return null;

    // Weight by categoryBias (unified pool). Default weight 1 keeps a uniform
    // pick when no bias is defined. Bias is additive in the prototype; we shift
    // to positive weights so a negative bias just lowers (never zeroes) a
    // candidate's odds.
    final bias = slot.categoryBias;
    if (bias == null || bias.isEmpty) {
      return rng.pick(eligible);
    }
    var minBias = 0;
    for (final b in bias.values) {
      if (b < minBias) minBias = b;
    }
    final weights = [
      for (final ex in eligible)
        (((bias[ex.generatorMeta?.category] ?? 0) - minBias) + 1).toDouble(),
    ];
    return rng.weightedPick(eligible, weights);
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
