import '../../models/exercise.dart';
import '../../models/generator/experience_level.dart';
import '../../models/generator/generator_slot.dart';
import '../../models/generator/rotation_memory.dart';
import '../../models/generator/split_type.dart';
import '../../repositories/asset_exercise_repository.dart';
import 'build_state.dart';
import 'exercise_orderer.dart';
import 'seeded_rng.dart';
import 'slot_filler.dart';
import 'set_density_resolver.dart';

/// Input parameters for one workout generation, derived from the user's
/// `FitnessPlan` plus which split/day is being built.
class GenerationRequest {
  final String splitName; // "Push Day" / "Pull Day" / "Legs + Core"
  final int durationMinutes;
  final ExperienceLevel experience;

  /// Cross-session rotation memory steering the pick away from recently-trained
  /// exercises. Defaults to empty so generation stays a pure function of its
  /// inputs (tests and fresh installs pass nothing); the app loads the current
  /// snapshot and passes it in.
  final RotationMemory rotationMemory;

  const GenerationRequest({
    required this.splitName,
    required this.durationMinutes,
    required this.experience,
    this.rotationMemory = const RotationMemory.empty(),
  });
}

/// The generated result for one workout: the ordered exercises plus a little
/// provenance for diagnostics/tests.
class GeneratedWorkout {
  final String splitName;

  /// The user's *target* duration (the plan setting, e.g. 75). Drives slot
  /// selection and set density; it is the request, not the estimate.
  final int durationMinutes;

  /// The generator's per-workout minute estimate shown on the card. Anchored to
  /// [durationMinutes] and nudged a few minutes by which exercises were picked,
  /// so a 75-min plan reads as 72 / 75 / 78 across re-rolls rather than a flat
  /// echo of the pick. See [estimateWorkoutMinutes].
  final int estimatedMinutes;

  final ExperienceLevel experience;
  final List<Exercise> exercises;

  const GeneratedWorkout({
    required this.splitName,
    required this.durationMinutes,
    required this.estimatedMinutes,
    required this.experience,
    required this.exercises,
  });
}

/// Estimates the per-workout duration shown on the card, in minutes, anchored
/// to the [targetMinutes] the user picked and nudged a few minutes by *which*
/// exercises were assembled.
///
/// Why not a pure work+rest physics sum: for a fixed plan (same target, level,
/// split) the generator produces an identical training load on every re-roll —
/// the exercise *count*, per-exercise `sets`, and `reps` don't change, only
/// which movements fill the slots. So any volume-derived estimate is constant
/// (45 → always 45, 75 → always 75), and the card never shows the natural
/// "72 / 78" spread around the pick.
///
/// Instead the shift is a deterministic function of the chosen exercises (their
/// ids and load), mapped into a tight window around the target. Different rolls
/// pick different exercises → different shift → the card reads 72 / 75 / 78,
/// while the same roll always reproduces the same number. The window keeps it
/// close to the pick (±[_kEstimateWindowFraction] of the target, ≈ ±6 min at
/// 75), so it always reads as "near 75".
int estimateWorkoutMinutes(
  List<Exercise> exercises, {
  required int targetMinutes,
}) {
  if (exercises.isEmpty) return targetMinutes;

  final window = (targetMinutes * _kEstimateWindowFraction).round();
  if (window == 0) return targetMinutes;

  // Deterministic fingerprint of this exact selection: fold the exercise ids
  // (identity of what was picked) together with per-exercise load so both a
  // different movement set and a different volume move the number. FNV-1a-style
  // mixing over character codes keeps it stable and well-spread without dart:*
  // hashing (which isn't guaranteed stable across runs).
  var hash = 0x811c9dc5;
  for (final e in exercises) {
    for (final code in e.id.codeUnits) {
      hash = (hash ^ code) * 0x01000193 & 0x7fffffff;
    }
    hash = (hash ^ (e.sets * 31 + e.reps)) * 0x01000193 & 0x7fffffff;
  }

  // Map the fingerprint uniformly onto [-window, +window].
  final span = 2 * window + 1;
  final shift = (hash % span) - window;
  return targetMinutes + shift;
}

/// Half-width of the estimate window as a fraction of the target duration: the
/// card's minute estimate stays within ±(fraction × target) of the pick.
const double _kEstimateWindowFraction = 0.08;

/// Ports the MaxHype PPL generation engine (Part 2A core).
///
/// This is a pure, seedable service: given a [GenerationRequest] and a seed, it
/// walks the duration-specific slot plan, fills each slot from the exercise
/// library (multi-pass fallback), applies basic set density, and returns the
/// ordered exercises. It reads all data from [AssetExerciseRepository] (Part 1)
/// and holds no global state — every build runs on a fresh [SeededRng] and
/// build-state, so it's reproducible under a fixed seed and reentrant.
///
/// The advanced scoring/rotation intelligence (Part 2B) plugs in later as a
/// candidate-ranking step inside the fill loop; 2A uses a simpler,
/// invariant-safe selection so workouts are already valid and playable.
abstract class WorkoutGeneratorService {
  /// Generates one workout for the given request. [seed] pins the RNG:
  /// production passes a varying seed (time/counter) for variety, tests pass a
  /// fixed seed for reproducibility.
  GeneratedWorkout generate(GenerationRequest request, {required int seed});

  /// Whether the service can generate the given split. 2A supports only PPL.
  bool supports(SplitType split);
}

/// Default implementation backed by the ported asset data.
class AssetWorkoutGeneratorService implements WorkoutGeneratorService {
  final AssetExerciseRepository _repo;
  final SlotFiller _filler;
  SetDensityResolver? _density;

  AssetWorkoutGeneratorService(this._repo) : _filler = SlotFiller(_repo);

  static const _pplSplits = {'Push Day', 'Pull Day', 'Legs + Core'};

  SetDensityResolver get _densityResolver => _density ??= SetDensityResolver(
    table: _repo.setDensity,
    metadata: _repo.metadataTables!,
  );

  @override
  bool supports(SplitType split) => split == SplitType.ppl;

  @override
  GeneratedWorkout generate(GenerationRequest request, {required int seed}) {
    if (!_pplSplits.contains(request.splitName)) {
      throw ArgumentError(
        'Part 2A generates PPL only; got "${request.splitName}".',
      );
    }
    final rng = SeededRng(seed);
    final slots = _repo.slotPlans.slotsFor(
      request.splitName,
      request.durationMinutes,
    );

    // Experience-aware exercise budget (prototype `maxExercises`,
    // script.js:6503): `min(DURATION_PROFILES[exp][split][mins].ex, slots)`.
    // Slot plans are authored at the advanced layout; lower experience tiers
    // budget fewer exercises, dropping optional tail slots exactly like the
    // prototype's fill-loop bound (script.js:6874).
    final profile = _repo.metadataTables?.profileFor(
      experience: request.experience,
      splitName: request.splitName,
      minutes: request.durationMinutes,
    );
    final budget = profile == null
        ? slots.length
        : (profile.exercises < slots.length ? profile.exercises : slots.length);

    final exercises = _fill(slots, request, rng, maxExercises: budget);

    return GeneratedWorkout(
      splitName: request.splitName,
      durationMinutes: request.durationMinutes,
      estimatedMinutes: estimateWorkoutMinutes(
        exercises,
        targetMinutes: request.durationMinutes,
      ),
      experience: request.experience,
      exercises: exercises,
    );
  }

  /// Walks the ordered slot plan, resolving each slot to an exercise via the
  /// multi-pass [SlotFiller] and committing it to the build state. A slot that
  /// can't resolve (even to its default) is cleanly skipped rather than
  /// aborting the build — matching the prototype, which tolerates a rare empty
  /// slot rather than producing an invalid workout.
  ///
  /// [maxExercises] is the experience-aware budget: the walk keeps trying
  /// slots in order (a failed slot doesn't consume budget) and stops as soon
  /// as the budget is met — the prototype's exact loop bound
  /// (`_psi < slots.length && exercises.length < maxExercises`).
  List<Exercise> _fill(
    List<GeneratorSlot> slots,
    GenerationRequest request,
    SeededRng rng, {
    required int maxExercises,
  }) {
    final state = BuildState(
      request.splitName,
      rotationMemory: request.rotationMemory,
    );
    for (final slot in slots) {
      if (state.exercises.length >= maxExercises) break;
      final picked = _filler.fill(slot, state, request.experience, rng);
      if (picked == null) continue;
      // Apply set density (role × duration, category-capped) so a 45-min and a
      // 120-min workout differ, and each exercise carries its target set count.
      final sets = _densityResolver.setsFor(
        picked,
        slot,
        request.durationMinutes,
      );
      // Seed planned weight/reps from the slot's default performance string
      // (e.g. "135 x 8"). These become the muted placeholders on the pre-start
      // logging screen; without them the fields render empty.
      final perf = _parsePerf(slot.defaultPerf);
      state.commit(
        picked.copyWith(sets: sets, weight: perf.weight, reps: perf.reps),
        slotType: slot.slotType,
        movementGroup: picked.generatorMeta?.movementGroup,
      );
    }
    // FINAL ORDERING PASS (script.js:7599): rebuild in the split's canonical
    // bodybuilding order — compounds before isolation, core last on Legs —
    // regardless of slot/generation order.
    return const ExerciseOrderer().order(request.splitName, state.exercises);
  }

  /// Parses a slot default-performance string like "135 x 8", "BW x 10", or
  /// "30 x 12" into planned (weight, reps). Bodyweight ("BW") maps to weight 0.
  /// Falls back to (0, 10) when the string is missing or unparseable.
  ({double weight, int reps}) _parsePerf(String? perf) {
    if (perf == null) return (weight: 0, reps: 10);
    final parts = perf.toLowerCase().split('x');
    if (parts.length != 2) return (weight: 0, reps: 10);
    final weightStr = parts[0].trim();
    final weight = weightStr == 'bw' ? 0.0 : double.tryParse(weightStr) ?? 0.0;
    final reps = int.tryParse(parts[1].trim()) ?? 10;
    return (weight: weight, reps: reps);
  }
}
