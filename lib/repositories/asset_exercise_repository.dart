import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/exercise.dart';
import '../models/muscle_group.dart';
import '../models/generator/experience_level.dart';
import '../models/generator/exercise_taxonomy.dart';
import '../models/generator/generator_metadata.dart';
import '../models/generator/duration_profile.dart';
import '../models/generator/workout_template.dart';
import 'exercise_repository.dart';

/// Exercise repository backed by the ported generator library asset
/// (`assets/data/exercise_library.json`, 187 exercises + metadata tables +
/// PPL templates). This is the data source the Part 2 generator will read.
///
/// It is registered *alongside* [MockExerciseRepository] rather than replacing
/// it — the hand-curated home workouts depend on the mock repo's specific
/// `ex_001..ex_047` id mapping, whereas this repo carries the full prototype
/// library with generator metadata.
class AssetExerciseRepository extends ExerciseRepository {
  static const _assetPath = 'assets/data/exercise_library.json';

  /// Test seam: inject raw JSON instead of reading the bundled asset.
  final Future<String> Function()? _jsonLoader;

  AssetExerciseRepository({Future<String> Function()? jsonLoader})
      : _jsonLoader = jsonLoader;

  List<Exercise> _exercises = const [];
  Map<String, Exercise> _byId = const {};
  GeneratorMetadataTables? _metadata;
  List<WorkoutTemplate> _templates = const [];
  bool _loaded = false;

  @override
  Future<void> load() async {
    if (_loaded) return;
    final raw = await (_jsonLoader?.call() ??
        rootBundle.loadString(_assetPath));
    final json = jsonDecode(raw) as Map<String, dynamic>;

    _exercises = (json['exercises'] as List<dynamic>)
        .map((e) => _exerciseFromLibraryJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _byId = {for (final e in _exercises) e.id: e};
    _metadata = GeneratorMetadataTables.fromJson(
        json['metadata'] as Map<String, dynamic>);
    _templates = (json['templates'] as List<dynamic>)
        .map((t) => WorkoutTemplate.fromJson(t as Map<String, dynamic>))
        .toList(growable: false);
    _loaded = true;
  }

  /// Builds an [Exercise] from a library record. The generator metadata is the
  /// full-fidelity payload; the coarse [Exercise] fields (muscleGroups,
  /// equipmentType) are projected down so the existing atlas / Replace UI can
  /// still render these exercises.
  Exercise _exerciseFromLibraryJson(Map<String, dynamic> json) {
    final meta = GeneratorMetadata.fromJson(json);
    final coarseMuscle = meta.bodyPart.toMuscleGroup();
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      // Library records carry no default prescription; the generator fills
      // sets/reps/weight from duration profiles at build time. Neutral seeds.
      sets: 3,
      reps: 10,
      weight: 0,
      muscleGroups: coarseMuscle == null ? const [] : [coarseMuscle],
      equipmentType: meta.equipment.toEquipmentType(),
      rating: 0,
      generatorMeta: meta,
    );
  }

  void _ensureLoaded() {
    if (!_loaded) {
      throw StateError(
          'AssetExerciseRepository.load() must be awaited before use.');
    }
  }

  @override
  List<Exercise> getAllExercises() {
    _ensureLoaded();
    return List.unmodifiable(_exercises);
  }

  @override
  Exercise? getExerciseById(String id) {
    _ensureLoaded();
    return _byId[id];
  }

  Exercise? getExerciseByName(String name) {
    _ensureLoaded();
    for (final e in _exercises) {
      if (e.name == name) return e;
    }
    return null;
  }

  @override
  List<Exercise> getExercisesByMuscleGroup(MuscleGroup muscleGroup) {
    _ensureLoaded();
    return _exercises
        .where((e) => e.muscleGroups.contains(muscleGroup))
        .toList();
  }

  @override
  List<Exercise> getTopExercisesByMuscleGroup(
    MuscleGroup muscleGroup, {
    int limit = 8,
  }) {
    final list = getExercisesByMuscleGroup(muscleGroup)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return list.take(limit).toList();
  }

  @override
  List<Exercise> getExercisesByCategory(String category) {
    _ensureLoaded();
    return _exercises
        .where((e) => e.generatorMeta?.category == category)
        .toList();
  }

  @override
  List<Exercise> getExercisesByTier(ExerciseTier tier) {
    _ensureLoaded();
    return _exercises.where((e) => e.generatorMeta?.tier == tier).toList();
  }

  @override
  List<Exercise> getGeneratableExercises(ExperienceLevel level) {
    _ensureLoaded();
    return _exercises
        .where((e) => e.generatorMeta?.isGeneratableAt(level) ?? false)
        .toList();
  }

  @override
  GeneratorMetadataTables? get metadataTables {
    _ensureLoaded();
    return _metadata;
  }

  /// The ported PPL templates (Push / Pull / Legs + Core). Not on the base
  /// [ExerciseRepository] interface — Part 2's generator consumes it directly
  /// from this concrete repository.
  List<WorkoutTemplate> get pplTemplates {
    _ensureLoaded();
    return List.unmodifiable(_templates);
  }
}
