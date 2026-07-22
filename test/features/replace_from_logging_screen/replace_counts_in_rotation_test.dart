// Verifies the milestone requirement that a REPLACED exercise is what feeds
// cross-session rotation memory on finish — so the next generation rotates
// away from the exercise the user actually trained, not the one the generator
// originally picked.
//
// Flow: start a generated Push session → replace its exercise with another →
// log a set → finish. The rotation repository must receive the REPLACEMENT's
// name (resolved to its library metadata and bucketed), and NOT the original.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/muscle_group.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';
import 'package:maxhype/models/generator/rotation_memory.dart';
import 'package:maxhype/repositories/rotation_memory_repository.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../screens/workout_session/bloc/helpers.dart';

/// A rotation repo that just captures what gets recorded.
class _CapturingRotationRepo implements RotationMemoryRepository {
  RotationMemory memory = const RotationMemory.empty();
  final List<({String split, List<String> names})> recorded = [];

  @override
  Future<RotationMemory> load() async => memory;

  @override
  Future<void> recordCompletion(
    String split,
    List<Exercise> exercises, {
    required String completionKey,
  }) async {
    recorded.add((split: split, names: exercises.map((e) => e.name).toList()));
    memory = memory.recordCompletion(split, exercises);
  }
}

/// A metadata-bearing chest-press exercise, so the resolver returns something
/// that buckets into Push/chest_compound.
Exercise _chestPress(String id, String name) => Exercise(
  id: id,
  name: name,
  sets: 3,
  reps: 8,
  weight: 0,
  muscleGroups: const [MuscleGroup.chest],
  equipmentType: EquipmentType.barbell,
  rating: 0,
  generatorMeta: GeneratorMetadata(
    category: 'chest press',
    bodyPart: const BodyPart('chest'),
    equipment: const GeneratorEquipment('Barbell'),
    type: ExerciseType.compound,
    tier: ExerciseTier.a,
    minExperience: ExperienceLevel.beginner,
    primaryMuscle: 'chest',
    movementPattern: 'flat_press',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerSessionFallback);

  late MockWorkoutSessionRepository repo;
  late MockPersonalRecordRepository prRepo;
  late _CapturingRotationRepo rotationRepo;
  late WorkoutSessionBloc bloc;

  // Library the resolver draws from.
  final library = {
    'Barbell Bench Press': _chestPress('bbp', 'Barbell Bench Press'),
    'Dumbbell Bench Press': _chestPress('dbp', 'Dumbbell Bench Press'),
  };

  setUp(() {
    repo = MockWorkoutSessionRepository();
    prRepo = MockPersonalRecordRepository();
    rotationRepo = _CapturingRotationRepo();
    // A generated Push card (gen_ prefix workoutId) so rotation recording fires
    // and the split resolves to "Push Day".
    when(() => repo.loadActive()).thenAnswer(
      (_) async => makeSession(
        id: 'session_gen_push',
        workoutId: 'gen_push_day_0',
        exercises: [
          makeExercise(
            exerciseId: 'bbp',
            name: 'Barbell Bench Press',
            setIds: ['set_a'],
          ),
        ],
      ),
    );
    when(() => repo.save(any())).thenAnswer((_) async {});
    when(() => repo.archiveFinished(any())).thenAnswer((_) async {});
    when(() => repo.clearActive()).thenAnswer((_) async {});
    when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);

    bloc = WorkoutSessionBloc(
      repository: repo,
      prRepository: prRepo,
      rotationMemoryRepository: rotationRepo,
      exerciseResolver: (name) => library[name],
      bell: FakeBell(),
      scheduler: FakeScheduler(),
    );
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await bloc.close();
  });

  Future<void> _restored() async {
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);
  }

  test(
    'a replaced exercise is what gets recorded into rotation memory on finish',
    () async {
      await _restored();

      // Replace the generated pick with a different chest press.
      bloc.add(
        ReplaceExercise(
          oldExerciseId: 'bbp', // slotId == exerciseId in the fixture
          newExercise: library['Dumbbell Bench Press']!,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // Log a set so the finish isn't blocked as empty. The bloc addresses a
      // logged set by SLOT id (preserved across the replace), which stays 'bbp'.
      bloc.add(
        const LogSet(
          exerciseId: 'bbp',
          setId: 'set_a',
          weight: 100,
          reps: 8,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      bloc.add(const FinishWorkout());
      await bloc.stream.firstWhere((s) => s is SessionFinished);
      await Future<void>.delayed(Duration.zero);

      expect(
        rotationRepo.recorded,
        isNotEmpty,
        reason: 'a generated Push workout must record rotation memory',
      );
      final names = rotationRepo.recorded.single.names;
      expect(
        names,
        contains('Dumbbell Bench Press'),
        reason: 'the replacement must feed rotation memory',
      );
      expect(
        names,
        isNot(contains('Barbell Bench Press')),
        reason: 'the original (replaced-out) exercise must NOT be recorded',
      );

      // And it buckets correctly: the recorded memory now penalizes the
      // replacement in the same Push bucket.
      final penalty = rotationRepo.memory.penaltyFor(
        library['Dumbbell Bench Press']!,
        'Push Day',
        5, // pool >= 2 so the gate is open
      );
      expect(
        penalty,
        lessThan(0),
        reason: 'the replacement is now a recently-trained Push exercise',
      );
    },
  );
}
