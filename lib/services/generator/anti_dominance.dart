import 'dart:math' as math;

import '../../models/exercise.dart';
import '../../models/generator/experience_level.dart';
import 'build_state.dart';

/// Anti-dominance + canonical-anchor scoring, ported from the prototype's
/// pickAlternative (Part 2B). Both are additive terms on the candidate score.
///
///   * Anti-dominance (script.js:9717) — suppresses an exercise that already
///     dominates its slotType across the workout, on a severity² curve.
///   * Canonical anchors / Phase 14C (script.js:8623) — on primary-compound
///     opening slots, boosts canonical bodybuilding anchors and nudges
///     acceptable-but-non-canonical variants down, scaled by experience.
class AntiDominance {
  const AntiDominance();

  /// `SLOT_ANTI_DOM_MULTIPLIER` (script.js:3110). slotType → multiplier on the
  /// base severity curve; slots absent from the table use 1.0.
  static const Map<String, double> slotMultiplier = {
    'pull_lat_pull': 1.8,
    'pull_lat_or_upper_back_accessory': 2.0,
    'legs_glute_accessory': 2.2,
    'triceps_stretch': 1.3,
    'shoulder_iso_lateral': 1.2,
    'shoulder_iso_non_lateral': 1.4,
  };

  static const double _threshold = 0.2;
  static const double _severityExponent = 2.2;
  static const double _baseMultiplier = 5000;

  /// The anti-dominance penalty (<= 0) for [candidate] in [slotType], given the
  /// current per-slotType usage in [state]. Zero unless the candidate already
  /// occupies more than [_threshold] of that slotType's picks.
  ///
  /// penalty = -(severity^2.2) * 5000 * slotMult,  severity = (pct-0.2)/0.8.
  double penaltyFor(Exercise candidate, String? slotType, BuildState state) {
    if (slotType == null) return 0;
    final total = state.slotTotals[slotType] ?? 0;
    if (total <= 0) return 0;
    final usage = state.slotUsage[slotType]?[candidate.name] ?? 0;
    final pct = usage / total;
    if (pct <= _threshold) return 0;
    final severity = (pct - _threshold) / (1 - _threshold);
    final base = math.pow(severity, _severityExponent).toDouble() *
        _baseMultiplier;
    final mult = slotMultiplier[slotType] ?? 1.0;
    return -(base * mult);
  }

  /// Canonical-anchor rebalance (Phase 14C). Only fires on primary-compound
  /// slots. Canonical anchors get a boost; recognized variants get a smaller
  /// penalty. Magnitudes scale with experience (advanced most aggressive).
  /// Returns 0 for non-primary-compound slots or unrecognized names.
  double anchorAdjustment(
    Exercise candidate,
    ExperienceLevel experience, {
    required bool isPrimaryCompoundSlot,
  }) {
    if (!isPrimaryCompoundSlot) return 0;
    final name = candidate.name;
    final isCanon = canonicalAnchors.contains(name);
    final isVariant = variantAnchors.contains(name);
    if (!isCanon && !isVariant) return 0;

    final double boost;
    final double penalty;
    switch (experience) {
      case ExperienceLevel.advanced:
        boost = 18;
        penalty = 14;
      case ExperienceLevel.none:
      case ExperienceLevel.beginner:
        boost = 10;
        penalty = 6;
      case ExperienceLevel.intermediate:
        boost = 14;
        penalty = 10;
    }
    return isCanon ? boost : -penalty;
  }

  /// `CANONICAL_ANCHOR_NAMES` (script.js:34170). Names absent from this app's
  /// library simply never match (harmless), matching prototype behavior.
  static const Set<String> canonicalAnchors = {
    // Push
    'Barbell Bench Press',
    'Dumbbell Bench Press',
    'Barbell Incline Bench Press',
    'Dumbbell Incline Bench Press',
    'Barbell Shoulder Press',
    'Dumbbell Shoulder Press',
    'Standing Dumbbell Shoulder Press',
    'Seated Barbell Shoulder Press',
    // Pull
    'Barbell Row',
    'T-Bar Row',
    'Landmine Row',
    'Dumbbell Row',
    'Pull Ups',
    'Lat Pulldown',
    'Cable Row',
    // Legs
    'Back Squat',
    'Front Squat',
    'Romanian Deadlift',
    'Trap Bar Deadlift',
    'Conventional Deadlift',
    'Barbell Romanian Deadlift',
  };

  /// `VARIANT_ANCHOR_NAMES` (script.js:34185).
  static const Set<String> variantAnchors = {
    'Assisted Pull Ups',
    'Assisted Wide Grip Pull Up',
    'Chest Supported T-Row',
    'Plate-Loaded High Row',
    'Plate-Loaded Chest Supported Row',
    'Half Kneeling Cable Row',
    'Tripod Dumbbell Row',
    'Bench Braced Dumbbell Row',
    'Single Arm Standing Cable Row',
    'Smith Machine Front Squat',
    'Smith Machine Romanian Deadlift',
    'Dumbbell Romanian Deadlift',
    'Hack Squat',
    'Smith Machine Bent Over Row',
    'Stiff Leg Deadlift',
    'Stiff-Leg Deadlift',
    'Smith Machine Stiff Leg Deadlift',
    'Dumbbell Stiff Leg Deadlift',
  };
}
