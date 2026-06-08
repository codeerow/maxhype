import 'package:maxhype/core/rest_timer_notifications.dart';
import 'package:maxhype/core/session_audio.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/session/personal_record.dart';
import 'package:maxhype/models/session/session_exercise.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/models/session/workout_session.dart';
import 'package:maxhype/repositories/personal_record_repository.dart';
import 'package:maxhype/repositories/workout_session_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSessionRepository extends Mock
    implements WorkoutSessionRepository {}

class MockPersonalRecordRepository extends Mock
    implements PersonalRecordRepository {}

class _WorkoutSessionFake extends Fake implements WorkoutSession {}

/// Call once from `setUpAll` (or before any `when(... any())` involving
/// repository methods that take a `WorkoutSession`).
void registerSessionFallback() {
  registerFallbackValue(_WorkoutSessionFake());
}

/// Build a `WorkoutSession` shaped like one produced by `StartSession`,
/// but constructed directly so tests can enter the bloc via
/// `RestoreSession` and skip the platform-touching `StartSession` path
/// (`RestTimerNotifications.requestPermission`).
WorkoutSession makeSession({
  String id = 'session_1',
  List<SessionExercise>? exercises,
}) {
  return WorkoutSession(
    id: id,
    workoutId: 'workout_1',
    workoutName: 'Test workout',
    startedAt: DateTime(2025, 1, 1, 10),
    exercises: exercises ??
        [
          makeExercise(exerciseId: 'ex1', setIds: ['set_a', 'set_b']),
        ],
  );
}

SessionExercise makeExercise({
  required String exerciseId,
  String name = 'Bench',
  List<String> setIds = const ['set_a'],
  bool withWarmup = false,
  List<String> warmupIds = const [],
  List<String> dropSetIds = const [],
}) {
  // Back-compat for callers that pass `withWarmup: true` and expect a
  // single warmup row with the legacy id 'warmup_a'.
  final warmups = warmupIds.isNotEmpty
      ? warmupIds
          .map((id) => SessionSet(id: id, kind: SetKind.warmup))
          .toList()
      : (withWarmup
          ? const [SessionSet(id: 'warmup_a', kind: SetKind.warmup)]
          : const <SessionSet>[]);
  return SessionExercise(
    exerciseId: exerciseId,
    name: name,
    equipment: EquipmentType.barbell,
    targetSets: setIds.length,
    sets: setIds.map((id) => SessionSet(id: id)).toList(),
    warmups: warmups,
    dropSets: dropSetIds
        .map((id) => SessionSet(id: id, kind: SetKind.dropSet))
        .toList(),
  );
}

/// Records each `playRestComplete()` call so tests can assert that the
/// foreground bell rang exactly the expected number of times.
class FakeBell implements RestBell {
  int rings = 0;

  @override
  Future<void> playRestComplete() async {
    rings++;
  }
}

/// Records each `schedule`/`cancel`/`requestPermission` call so tests
/// can assert OS notification handoff without touching the platform
/// plugin.
class FakeScheduler implements RestNotificationScheduler {
  final List<DateTime> scheduled = [];
  int cancels = 0;
  int permissionRequests = 0;

  @override
  Future<void> schedule(DateTime endsAt) async {
    scheduled.add(endsAt);
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }
}

PersonalRecord pr({
  String exerciseId = 'ex1',
  double weight = 100,
  int reps = 5,
  DateTime? achievedAt,
}) {
  return PersonalRecord(
    exerciseId: exerciseId,
    weight: weight,
    reps: reps,
    achievedAt: achievedAt ?? DateTime(2024, 12, 1),
  );
}