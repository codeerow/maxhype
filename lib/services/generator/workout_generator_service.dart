import '../../models/exercise.dart';
import '../../models/generator/experience_level.dart';
import '../../models/generator/generator_slot.dart';
import '../../models/generator/split_type.dart';
import '../../repositories/asset_exercise_repository.dart';
import 'build_state.dart';
import 'seeded_rng.dart';
import 'slot_filler.dart';
import 'set_density_resolver.dart';

/// Input parameters for one workout generation, derived from the user's
/// `FitnessPlan` plus which split/day is being built.
class GenerationRequest {
  final String splitName; // "Push Day" / "Pull Day" / "Legs + Core"
  final int durationMinutes;
  final ExperienceLevel experience;

  const GenerationRequest({
    required this.splitName,
    required this.durationMinutes,
    required this.experience,
  });
}

/// The generated result for one workout: the ordered exercises plus a little
/// provenance for diagnostics/tests.
class GeneratedWorkout {
  final String splitName;
  final int durationMinutes;
  final ExperienceLevel experience;
  final List<Exercise> exercises;

  const GeneratedWorkout({
    required this.splitName,
    required this.durationMinutes,
    required this.experience,
    required this.exercises,
  });
}

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

    // Fill loop (task 15) resolves each slot; wired in the next step.
    final exercises = _fill(slots, request, rng);

    return GeneratedWorkout(
      splitName: request.splitName,
      durationMinutes: request.durationMinutes,
      experience: request.experience,
      exercises: exercises,
    );
  }

  /// Walks the ordered slot plan, resolving each slot to an exercise via the
  /// multi-pass [SlotFiller] and committing it to the build state. A slot that
  /// can't resolve (even to its default) is cleanly skipped rather than
  /// aborting the build — matching the prototype, which tolerates a rare empty
  /// slot rather than producing an invalid workout.
  List<Exercise> _fill(
    List<GeneratorSlot> slots,
    GenerationRequest request,
    SeededRng rng,
  ) {
    final state = BuildState(request.splitName);
    for (final slot in slots) {
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
    return state.exercises;
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
