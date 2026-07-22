import '../../models/exercise.dart';
import '../../models/generator/experience_level.dart';
import '../../models/generator/exercise_taxonomy.dart';
import '../../models/generator/generator_slot.dart';
import 'anti_dominance.dart';
import 'build_state.dart';
import 'movement_caps.dart';
import 'similarity.dart';

/// Scores a candidate exercise for a slot, porting the web prototype's base
/// selection factors (Part 2B, first layer).
///
/// The prototype builds each candidate's score in `pickAlternative` as:
///
///   _s = scoreEquipmentPreference(candidate, current)   // equipment.dart §1
///      + (freshMovementGroup ?  +3 : 0)                 // diversity nudge
///      + (repeatedMovementGroup ? -15 : 0)              // soft dup penalty
///
/// where `scoreEquipmentPreference` is itself the sum of four sub-scores
/// (beginner, advanced, shoulder, dips). Scores are NOT clamped — negative
/// values are meaningful and flow into the downstream anti-dominance filter and
/// the final `weightedPickFromTop` roulette.
///
/// This class ports ONLY the base factors. The later 2B layers (movement caps,
/// rotation memory, anti-dominance severity² curve, Phase-16 similarity) plug in
/// as additional additive terms in [scoreOf] without changing this structure.
///
/// Faithful to script.js:
///   * scoreBeginnerEquipment  (7844-7868), BEGINNER_MAX_SMITH=2 (7842)
///   * scoreAdvancedEquipment  (7874-7922)
///   * scoreShoulderCandidate  (2185-2203)
///   * scoreDipsCandidate      (7932-7950), MAX_PRESS_PER_WORKOUT=3 (7755)
///   * MG diversity            (8534-8539): +3 fresh / -15 repeat
class ExerciseScorer {
  const ExerciseScorer({
    MovementCaps caps = const MovementCaps(),
    AntiDominance antiDominance = const AntiDominance(),
    Similarity similarity = const Similarity(),
  }) : _caps = caps,
       _antiDom = antiDominance,
       _similarity = similarity;

  final MovementCaps _caps;
  final AntiDominance _antiDom;
  final Similarity _similarity;

  // --- Prototype constants ---------------------------------------------------

  /// `BEGINNER_MAX_SMITH` (script.js:7842) — Smith Machine soft-cap for
  /// none/beginner lifters before the +8 preference flips to a -50 soft-block.
  static const int _beginnerMaxSmith = 2;

  /// `MAX_PRESS_PER_WORKOUT` (script.js:7755) — dips is hard-blocked (-100)
  /// once this many press movements are already in the workout.
  static const int _maxPressPerWorkout = 3;

  /// Movement-group diversity nudges (script.js:8537-8538).
  static const double _freshGroupBonus = 3;
  static const double _repeatGroupPenalty = -15;

  /// Legs near-duplicate soft caps (script.js:9341-9361). These catch two
  /// near-identical movements the taxonomy-based similarity pass can miss when
  /// the names differ but the exercise is effectively the same lift:
  ///   * a 2nd hip thrust / bridge  → -40
  ///   * a 2nd leg-curl variant     → -30
  /// Name-based, matching the prototype (which matched on lowercased names).
  static const double _secondHipThrustPenalty = -40;
  static const double _secondLegCurlPenalty = -30;

  /// Categories `countPressMovements` treats as a press (script.js:7754
  /// `PRESS_CATEGORIES`). Exactly these four — "compound press" is deliberately
  /// NOT counted, matching the prototype. Drives the dips press-overlap block.
  static const Set<String> _pressCategories = {
    'chest press',
    'incline press',
    'decline press',
    'shoulder press',
  };

  // --- Public API ------------------------------------------------------------

  /// The base score for [candidate] in [slot], given the exercises committed so
  /// far in [state] and the user's [experience]. Higher is better; scores are
  /// unclamped (negatives are meaningful).
  double scoreOf(
    Exercise candidate,
    GeneratorSlot slot,
    BuildState state,
    ExperienceLevel experience,
  ) {
    final equip = _scoreEquipmentPreference(candidate, state, experience);
    final mgScore = _scoreMovementGroupDiversity(candidate, state);
    final balance = _scoreBalancePenalties(candidate, state);
    // Anti-dominance (severity² suppression of an exercise dominating its
    // slotType) and canonical-anchor rebalance (primary-compound openers).
    final antiDom = _antiDom.penaltyFor(candidate, slot.slotType, state);
    final anchor = _antiDom.anchorAdjustment(
      candidate,
      experience,
      isPrimaryCompoundSlot: slot.role == SlotRole.primaryCompound,
    );
    // Phase 16 similarity smoothing (collapsed to the biomechanical-axis
    // cascade + the one CGBP/flat-press outlier).
    final similarity = _similarity.penaltyFor(candidate, slot, state);
    // Legs near-duplicate soft caps (2nd hip thrust / 2nd leg-curl).
    final legsDup = _scoreLegsNearDuplicate(candidate, state);
    return equip + mgScore + balance + antiDom + anchor + similarity + legsDup;
  }

  /// Ports the prototype's two name-based legs soft caps (script.js:9341-9361):
  /// a second hip thrust / bridge is penalized -40, a second leg-curl -30. Fires
  /// only when a matching movement is already committed. These are distinct from
  /// the taxonomy similarity pass — they key on the exercise name, so they catch
  /// same-lift duplicates whose metadata differs.
  double _scoreLegsNearDuplicate(Exercise candidate, BuildState state) {
    final name = candidate.name.toLowerCase();
    final isThrustOrBridge =
        name.contains('hip thrust') || name.contains('bridge');
    final isLegCurl =
        name.contains('leg curl') || name.contains('hamstring curl');
    if (!isThrustOrBridge && !isLegCurl) return 0;

    for (final ex in state.exercises) {
      final other = ex.name.toLowerCase();
      if (isThrustOrBridge &&
          (other.contains('hip thrust') || other.contains('bridge'))) {
        return _secondHipThrustPenalty;
      }
      if (isLegCurl &&
          (other.contains('leg curl') || other.contains('hamstring curl'))) {
        return _secondLegCurlPenalty;
      }
    }
    return 0;
  }

  /// Soft movement-balance penalties (the score-side of the cap system):
  ///   * pattern bucket: `-10` per existing use (script.js:9825)
  ///   * stimulus bucket: `-12` per existing use (script.js:9839)
  /// The pattern HARD cap and movement-group hard exclusion live in the pool
  /// filter (SlotFiller); this method is only the additive soft pressure.
  double _scoreBalancePenalties(Exercise candidate, BuildState state) {
    var penalty = 0.0;
    final pBucket = _caps.patternBucketOf(candidate, state.split);
    if (pBucket != null) {
      final used = state.patternUsage[pBucket] ?? 0;
      if (used > 0) penalty -= used * MovementCaps.patternSoftPenaltyPerUse;
    }
    final sBucket = _caps.stimulusBucketOf(candidate, state.split);
    if (sBucket != null) {
      final used = state.stimulusUsage[sBucket] ?? 0;
      if (used > 0) penalty -= used * MovementCaps.stimulusSoftPenaltyPerUse;
    }
    return penalty;
  }

  /// Movement-group diversity: `+3` for a group not yet used this build, `-15`
  /// for a repeat. A candidate with no movement group is neutral.
  double _scoreMovementGroupDiversity(Exercise candidate, BuildState state) {
    final mg = candidate.generatorMeta?.movementGroup;
    if (mg == null) return 0;
    if (state.usedMovementGroups.contains(mg)) return _repeatGroupPenalty;
    return _freshGroupBonus;
  }

  /// `scoreEquipmentPreference` = beginner + advanced + shoulder + dips
  /// (script.js:7951). Each sub-score self-gates on experience, so the sum is
  /// the right value at every level.
  double _scoreEquipmentPreference(
    Exercise candidate,
    BuildState state,
    ExperienceLevel experience,
  ) {
    return _scoreBeginnerEquipment(candidate, state, experience) +
        _scoreAdvancedEquipment(candidate, state, experience) +
        _scoreShoulderCandidate(candidate, state, experience) +
        _scoreDipsCandidate(candidate, state, experience);
  }

  /// script.js:7844-7868 — only for none/beginner (rank < intermediate).
  /// Smith Machine: `+8` while under [_beginnerMaxSmith], else `-50`.
  /// Barbell: `-5`. Everything else neutral.
  double _scoreBeginnerEquipment(
    Exercise candidate,
    BuildState state,
    ExperienceLevel experience,
  ) {
    // EXPERIENCE_RANK >= 2 → return 0 (intermediate/advanced).
    if (experience.rank >= ExperienceLevel.intermediate.rank) return 0;
    final equip = candidate.generatorMeta?.equipment.label;
    if (equip == null) return 0;

    if (equip == 'Smith Machine') {
      final smithCount = _countEquipment(state, 'Smith Machine');
      return smithCount >= _beginnerMaxSmith ? -50 : 8;
    }
    if (equip == 'Barbell') return -5;
    return 0;
  }

  /// script.js:7874-7922 — advanced only. Free-weight compound bonus, EZ/Trap
  /// bonus, free-weight diversity bonus, machine/plate-loaded compound
  /// penalties, and a machine-dominance guard.
  double _scoreAdvancedEquipment(
    Exercise candidate,
    BuildState state,
    ExperienceLevel experience,
  ) {
    if (experience != ExperienceLevel.advanced) return 0;
    final meta = candidate.generatorMeta;
    if (meta == null) return 0;
    final equip = meta.equipment.label;
    final isCompound = meta.type == ExerciseType.compound;

    var machineCount = 0;
    var hasBarbell = false;
    var hasDumbbell = false;
    for (final e in state.exercises) {
      final eq = e.generatorMeta?.equipment.label;
      if (eq == null) continue;
      if (eq == 'Machine' || eq == 'Plate-Loaded') machineCount++;
      if (eq == 'Barbell') hasBarbell = true;
      if (eq == 'Dumbbell') hasDumbbell = true;
    }

    var score = 0.0;

    // Free-weight compound bonus (no barbell>dumbbell bias); isolation gets +4.
    if ((equip == 'Barbell' || equip == 'Dumbbell') && isCompound) {
      score += 10;
    } else if (equip == 'Barbell' || equip == 'Dumbbell') {
      score += 4;
    }
    if (equip == 'EZ Bar' || equip == 'Trap Bar') score += 4;

    // Free-weight diversity: reward switching to the missing free-weight type.
    if (equip == 'Dumbbell' && hasBarbell && !hasDumbbell) score += 5;
    if (equip == 'Barbell' && hasDumbbell && !hasBarbell) score += 5;

    // Machine compound penalty — softer for supported rows (avoid shadowing).
    if (equip == 'Machine' && isCompound) {
      score += (meta.movementGroup == 'supported_row') ? -3 : -6;
    }
    if (equip == 'Plate-Loaded' && isCompound) score += -3;

    // Machine/Plate-Loaded dominance guard.
    if ((equip == 'Machine' || equip == 'Plate-Loaded') && machineCount >= 2) {
      score += -25;
    }
    return score;
  }

  /// script.js:2185-2203 — advanced only, shoulder-press category only. If no
  /// free-weight shoulder press is in the workout yet: `+12` for a free-weight
  /// press, `-10` for a machine one.
  double _scoreShoulderCandidate(
    Exercise candidate,
    BuildState state,
    ExperienceLevel experience,
  ) {
    if (experience != ExperienceLevel.advanced) return 0;
    final meta = candidate.generatorMeta;
    if (meta == null || meta.category != 'shoulder press') return 0;

    var hasFreeWeightPress = false;
    for (final e in state.exercises) {
      final em = e.generatorMeta;
      if (em == null || em.category != 'shoulder press') continue;
      final eq = em.equipment.label;
      if (eq == 'Barbell' || eq == 'Dumbbell') hasFreeWeightPress = true;
    }
    if (hasFreeWeightPress) return 0;

    final equip = meta.equipment.label;
    if (equip == 'Barbell' || equip == 'Dumbbell') return 12;
    if (equip == 'Machine') return -10;
    return 0;
  }

  /// script.js:7932-7950 — advanced only, the "Dips" exercise only. Hard-blocks
  /// on press saturation (`-100`) or close-grip-bench overlap (`-50`), else a
  /// `+10` premium-compound bonus.
  double _scoreDipsCandidate(
    Exercise candidate,
    BuildState state,
    ExperienceLevel experience,
  ) {
    if (experience != ExperienceLevel.advanced) return 0;
    if (candidate.name != 'Dips') return 0;

    final pressCount = _countPressMovements(state);
    if (pressCount >= _maxPressPerWorkout) return -100;

    for (final e in state.exercises) {
      if (e.name == 'Close Grip Bench Press' ||
          e.name == 'Smith Machine Close-Grip Bench Press') {
        return -50;
      }
    }
    return 10;
  }

  // --- Helpers ---------------------------------------------------------------

  int _countEquipment(BuildState state, String equipmentLabel) {
    var n = 0;
    for (final e in state.exercises) {
      if (e.generatorMeta?.equipment.label == equipmentLabel) n++;
    }
    return n;
  }

  int _countPressMovements(BuildState state) {
    var n = 0;
    for (final e in state.exercises) {
      final cat = e.generatorMeta?.category;
      if (cat != null && _pressCategories.contains(cat)) n++;
    }
    return n;
  }
}
