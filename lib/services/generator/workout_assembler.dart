import '../../models/exercise.dart';
import '../../models/muscle_group.dart';
import '../../models/workout.dart';
import '../../models/generator/fitness_plan.dart';
import '../../models/generator/rotation_memory.dart';
import '../../models/generator/split_type.dart';
import 'workout_generator_service.dart';

/// Turns generated PPL workouts into the app's [Workout] model and builds the
/// per-plan card set (one card per training day).
///
/// This is the bridge between the pure generator and the existing UI/session
/// stack: home, detail, session, logging, completion, and Replace all consume
/// [Workout], so mapping into it is what makes generated output a drop-in
/// replacement for the mock catalog.
class WorkoutAssembler {
  final WorkoutGeneratorService generator;

  WorkoutAssembler(this.generator);

  /// The PPL day cycle. Cards for a plan are these splits repeated up to
  /// [FitnessPlan.daysPerWeek], so a 3-day plan is P/P/L and a 5-day plan is
  /// P/P/L/P/P.
  static const _pplCycle = ['Push Day', 'Pull Day', 'Legs + Core'];

  /// Builds the full card set for [plan]. Each card is a generated workout;
  /// [seedBase] pins reproducibility (each card offsets the base so cards in a
  /// plan differ from each other while the whole plan is reproducible).
  List<Workout> buildCards(
    FitnessPlan plan, {
    required int seedBase,
    RotationMemory rotationMemory = const RotationMemory.empty(),
  }) {
    if (plan.split != SplitType.ppl) {
      throw ArgumentError('2A generates PPL only; got ${plan.split}.');
    }
    final days = plan.daysPerWeek.clamp(1, 7);
    final cards = <Workout>[];
    for (var i = 0; i < days; i++) {
      final splitName = _pplCycle[i % _pplCycle.length];
      final generated = generator.generate(
        GenerationRequest(
          splitName: splitName,
          durationMinutes: plan.durationMinutes,
          experience: plan.experience,
          rotationMemory: rotationMemory,
        ),
        seed: seedBase + i,
      );
      cards.add(_toWorkout(generated, index: i));
    }
    return cards;
  }

  Workout _toWorkout(GeneratedWorkout g, {required int index}) {
    final title = _titleFor(g.splitName);
    final muscles = _targetMuscles(g.exercises);
    return Workout(
      id: 'gen_${g.splitName.replaceAll(RegExp(r'\s+'), '_').toLowerCase()}_$index',
      title: title,
      subtitle: _subtitle(muscles),
      duration: _durationLabel(g.durationMinutes),
      exerciseCount: g.exercises.length,
      exercises: g.exercises,
      targetMuscles: muscles,
      // Recovery is a display concern not driven by the generator; generated
      // cards start "ready". (Recovery modeling is out of Part 2A scope.)
      recoveryInfo: RecoveryInfo(
        status: RecoveryStatus.ready,
        percentage: 100,
        description: 'Recovered and ready to go',
      ),
    );
  }

  String _titleFor(String splitName) {
    switch (splitName) {
      case 'Push Day':
        return 'Push';
      case 'Pull Day':
        return 'Pull';
      case 'Legs + Core':
        return 'Legs + Core';
      default:
        return splitName;
    }
  }

  /// Distinct target muscles in first-appearance order (primary muscle of each
  /// exercise, projected to the coarse [MuscleGroup] the UI uses).
  List<MuscleGroup> _targetMuscles(List<Exercise> exercises) {
    final seen = <MuscleGroup>{};
    final ordered = <MuscleGroup>[];
    for (final e in exercises) {
      for (final m in e.muscleGroups) {
        if (seen.add(m)) ordered.add(m);
      }
    }
    return ordered;
  }

  String _subtitle(List<MuscleGroup> muscles) {
    if (muscles.isEmpty) return '';
    return muscles.take(4).map((m) => m.displayName).join(', ');
  }

  /// Human duration label matching the app's style ("60 min", "2 hrs").
  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    if (minutes % 60 == 0) {
      final hrs = minutes ~/ 60;
      return hrs == 1 ? '1 hr' : '$hrs hrs';
    }
    final hrs = minutes / 60;
    return '${hrs.toStringAsFixed(1)} hrs';
  }
}
