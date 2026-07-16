import '../../models/exercise.dart';
import '../../models/generator/generator_slot.dart';
import 'build_state.dart';

/// Phase 16 exercise-similarity smoothing, ported as an APPROVED SIMPLIFICATION
/// of the prototype's 21 pair-specific rules (script.js:8719-8866).
///
/// The prototype hand-codes ~21 rules (CGBP+flat, two lunges, two flyes, biceps
/// by grip, three raise types, rows by equipment, triceps by axis, …), most of
/// which parse exercise NAMES with regexes because its base metadata was too
/// coarse to express the distinction. This app's [Exercise] metadata is richer:
/// grip and execution-axis are already encoded in `movementPattern`
/// (elbow_curl vs elbow_curl_neutral vs elbow_curl_pronated; pushdown vs
/// skullcrusher vs overhead_extension), and delt/lunge/fly families already
/// share a distinct `primaryMuscle`+`movementPattern`.
///
/// So the 21 rules collapse to the prototype's OWN general core — the
/// biomechanical-axis cascade (Phase 16 Rule 1a/1b/1c + Rule 3 echo) — which
/// keys on primaryMuscle + movementPattern + stimulusType. Verified against the
/// library: this cascade already subsumes lunges, flyes, delts, biceps-grip,
/// triceps-axis and same-equipment rows. The ONE genuine outlier that does not
/// reduce to metadata is the CGBP↔flat-press pair (Close-Grip Bench is tagged
/// primaryMuscle=triceps / movementPattern=triceps_press, so it shares no axis
/// with a flat bench despite the heavy overlap) — it survives as one explicit
/// rule.
///
/// Penalty bands are the prototype's own (script.js:8722): -4 mild (one axis),
/// -7 moderate (two axes), -10 high (three axes / CGBP+flat), -14 extreme
/// (3rd-deep family echo). On primary_compound slots the penalty is capped at
/// -6 so the Phase 14C anchor boost still wins.
class Similarity {
  const Similarity();

  static const double _mild = 4; // one axis (muscle + stimulus)
  static const double _moderate = 7; // two axes (muscle + pattern)
  static const double _high = 10; // three axes / CGBP+flat pair
  static const double _extreme = 14; // 3rd-deep family echo
  static const double _anchorCap = 6; // primary_compound preservation cap

  /// The similarity penalty (<= 0) for [candidate] against everything already
  /// committed in [state]. Applied additively to the candidate score.
  double penaltyFor(Exercise candidate, GeneratorSlot slot, BuildState state) {
    final cMeta = candidate.generatorMeta;
    if (cMeta == null) return 0;
    final cMuscle = cMeta.primaryMuscle;
    final cPattern = cMeta.movementPattern;
    final cStim = cMeta.stimulusType;

    var penalty = 0.0;
    var familyEchoCount = 0; // count of full three-axis matches (Rule 3)

    for (final existing in state.exercises) {
      final eMeta = existing.generatorMeta;
      if (eMeta == null) continue;
      final eMuscle = eMeta.primaryMuscle;
      final ePattern = eMeta.movementPattern;
      final eStim = eMeta.stimulusType;

      // --- General biomechanical-axis cascade (Rules 1a/1b/1c) --------------
      if (cMuscle != null &&
          cPattern != null &&
          cStim != null &&
          cMuscle == eMuscle &&
          cPattern == ePattern &&
          cStim == eStim) {
        familyEchoCount++;
        if (penalty > -_high) penalty = -_high; // take the strongest so far
      } else if (cMuscle != null &&
          cPattern != null &&
          cMuscle == eMuscle &&
          cPattern == ePattern) {
        if (penalty > -_moderate) penalty = -_moderate;
      } else if (cMuscle != null &&
          cMuscle == eMuscle &&
          cStim != null &&
          cStim == eStim) {
        if (penalty > -_mild) penalty = -_mild;
      }

      // --- Genuine outlier: CGBP ↔ flat-press (Rule 2a) --------------------
      if (_isCgbpFlatPair(candidate, existing) && penalty > -_high) {
        penalty = -_high;
      }
    }

    // Rule 3 — family echo: a 3rd same-(muscle,pattern,stimulus) pick is an
    // extreme cluster (two already committed matched fully → this is the 3rd).
    if (familyEchoCount >= 2) penalty = -_extreme;

    // Anchor preservation: never bury a primary-compound anchor deeper than -6.
    if (slot.role == SlotRole.primaryCompound && penalty < -_anchorCap) {
      penalty = -_anchorCap;
    }
    return penalty;
  }

  /// Rule 2a: one of the pair is Close-Grip Bench Press (movementPattern
  /// triceps_press, name contains "close grip"), the other is a flat_press.
  /// This is the single overlap the metadata cascade can't see, because CGBP
  /// is tagged as a triceps press rather than a chest press.
  bool _isCgbpFlatPair(Exercise a, Exercise b) {
    bool isCgbp(Exercise e) =>
        e.generatorMeta?.movementPattern == 'triceps_press' &&
        e.name.toLowerCase().contains('close') &&
        e.name.toLowerCase().contains('grip');
    bool isFlat(Exercise e) => e.generatorMeta?.movementPattern == 'flat_press';
    return (isCgbp(a) && isFlat(b)) || (isFlat(a) && isCgbp(b));
  }
}
