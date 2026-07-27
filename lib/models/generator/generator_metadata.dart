import 'exercise_taxonomy.dart';
import 'experience_level.dart';

/// Generator-only metadata attached to an [Exercise].
///
/// Kept as a separate value object (rather than flattened onto [Exercise]) so
/// the generator's rich taxonomy stays clearly separated from the fields the
/// rest of the app already uses, and so an exercise that was never loaded from
/// the generator library simply has `generatorMeta == null`.
class GeneratorMetadata {
  /// Fine-grained category, e.g. "chest press", "side delt", "hinge".
  final String category;

  /// Prototype body-part label (finer than the coarse MuscleGroup enum).
  final BodyPart bodyPart;

  /// Full-fidelity equipment label (Smith Machine, Plate-Loaded, ...).
  final GeneratorEquipment equipment;

  final ExerciseType type;
  final ExerciseTier tier;

  /// Minimum experience required for this exercise to be eligible.
  final ExperienceLevel minExperience;

  /// Maximum experience at which this exercise is auto-generated, if capped.
  ///
  /// Mirror of [minExperience] for the opposite bound: an exercise with
  /// `maxExperience == intermediate` is generated for none/beginner/
  /// intermediate but never for advanced. This keeps experience gating in the
  /// data (the exercise library) rather than as hardcoded equipment checks in
  /// the generator — e.g. the prototype drops Smith Machine picks for advanced
  /// users, which we express as `maxExperience: "intermediate"` on those
  /// exercises. Null means no upper bound.
  final ExperienceLevel? maxExperience;

  /// Movement group used for duplicate/balancing rules (e.g. "flat_press").
  /// Null when the prototype had no group mapping for the exercise.
  final String? movementGroup;

  // --- Muscle & movement taxonomy (from EXERCISE_QUALITY_META) ---------------
  //
  // These are the ID/name/primary-muscle/secondary-muscles/movement-pattern
  // fields the milestone brief calls for. Primary muscle + movement pattern are
  // present for every generatable exercise; a few generator-excluded/olympic
  // lifts carry null.

  /// Primary muscle worked, e.g. "chest", "lats", "quads".
  final String? primaryMuscle;

  /// Secondary (synergist) muscles, e.g. ["triceps", "front_delt"].
  final List<String> secondaryMuscles;

  /// Movement pattern, e.g. "flat_press", "vertical_pull", "hinge", "squat".
  /// Coarser than [movementGroup]; used for balancing and focus targeting.
  final String? movementPattern;

  /// Additional generation-support fields the prototype attaches per exercise.
  /// Kept for Part 2's scoring rules (region bias, joint-pattern fatigue,
  /// compound/isolation stimulus, hypertrophy role). Nullable — not every
  /// exercise defines them.
  final String? region;
  final String? jointPattern;
  final String? stimulusType;
  final String? hypertrophyRole;

  /// Prototype selection flags:
  /// - [stable]: a reliable default pick for its slot.
  /// - [replaceOnly]: eligible only as a manual replacement, never generated.
  /// - [generatorExclude]: excluded from automatic generation entirely.
  final bool stable;
  final bool replaceOnly;
  final bool generatorExclude;

  const GeneratorMetadata({
    required this.category,
    required this.bodyPart,
    required this.equipment,
    required this.type,
    required this.tier,
    required this.minExperience,
    this.maxExperience,
    this.movementGroup,
    this.primaryMuscle,
    this.secondaryMuscles = const [],
    this.movementPattern,
    this.region,
    this.jointPattern,
    this.stimulusType,
    this.hypertrophyRole,
    this.stable = false,
    this.replaceOnly = false,
    this.generatorExclude = false,
  });

  /// Eligible for automatic generation at the given experience level.
  bool isGeneratableAt(ExperienceLevel userLevel) =>
      !replaceOnly &&
      !generatorExclude &&
      userLevel.rank >= minExperience.rank &&
      (maxExperience == null || userLevel.rank <= maxExperience!.rank);

  factory GeneratorMetadata.fromJson(Map<String, dynamic> json) {
    return GeneratorMetadata(
      category: json['category'] as String,
      bodyPart: BodyPart(json['bodyPart'] as String),
      equipment: GeneratorEquipment(json['equipment'] as String),
      type: ExerciseType.fromWire(json['type'] as String),
      tier: ExerciseTier.fromWire(json['tier'] as String),
      minExperience: ExperienceLevel.fromWire(json['minExperience'] as String?),
      maxExperience: json['maxExperience'] == null
          ? null
          : ExperienceLevel.fromWire(json['maxExperience'] as String?),
      movementGroup: json['movementGroup'] as String?,
      primaryMuscle: json['primaryMuscle'] as String?,
      secondaryMuscles:
          (json['secondaryMuscles'] as List<dynamic>? ?? const [])
              .cast<String>(),
      movementPattern: json['movementPattern'] as String?,
      region: json['region'] as String?,
      jointPattern: json['jointPattern'] as String?,
      stimulusType: json['stimulusType'] as String?,
      hypertrophyRole: json['hypertrophyRole'] as String?,
      stable: json['stable'] as bool? ?? false,
      replaceOnly: json['replaceOnly'] as bool? ?? false,
      generatorExclude: json['generatorExclude'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'bodyPart': bodyPart.label,
        'equipment': equipment.label,
        'type': type.wireValue,
        'tier': tier.wireValue,
        'minExperience': minExperience.wireValue,
        'maxExperience': maxExperience?.wireValue,
        'movementGroup': movementGroup,
        'primaryMuscle': primaryMuscle,
        'secondaryMuscles': secondaryMuscles,
        'movementPattern': movementPattern,
        'region': region,
        'jointPattern': jointPattern,
        'stimulusType': stimulusType,
        'hypertrophyRole': hypertrophyRole,
        'stable': stable,
        'replaceOnly': replaceOnly,
        'generatorExclude': generatorExclude,
      };
}
