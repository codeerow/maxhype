import 'experience_level.dart';
import 'split_type.dart';

enum WeightUnit {
  lb,
  kg;

  String get wireValue => this == WeightUnit.lb ? 'lb' : 'kg';
  String get displayName => this == WeightUnit.lb ? 'lb' : 'kg';

  static WeightUnit fromWire(String? value) =>
      value == 'kg' ? WeightUnit.kg : WeightUnit.lb;
}

enum Sex {
  male,
  female,
  unspecified;

  String get wireValue {
    switch (this) {
      case Sex.male:
        return 'male';
      case Sex.female:
        return 'female';
      case Sex.unspecified:
        return 'unspecified';
    }
  }

  static Sex fromWire(String? value) {
    switch (value) {
      case 'male':
        return Sex.male;
      case 'female':
        return Sex.female;
      default:
        return Sex.unspecified;
    }
  }
}

/// Persistent user fitness plan — the parameter set the generator reads.
///
/// This is the whole user-settings/profile layer, which did not exist in the
/// app before. Part 1 delivers the model + persistence with safe defaults;
/// onboarding UI to edit these values is out of scope for this milestone
/// (values are seeded and survive restarts via the repository).
class FitnessPlan {
  final SplitType split;
  final int daysPerWeek;

  /// Target workout duration in minutes (one of [kSupportedDurations]).
  final int durationMinutes;

  final ExperienceLevel experience;
  final WeightUnit units;
  final Sex sex;
  final int age;

  /// Bodyweight, stored in the user's chosen [units].
  final double weight;

  const FitnessPlan({
    required this.split,
    required this.daysPerWeek,
    required this.durationMinutes,
    required this.experience,
    required this.units,
    required this.sex,
    required this.age,
    required this.weight,
  });

  /// Safe starting values so the app has a valid plan before any onboarding
  /// UI exists. PPL, 3 days/week, 60-minute beginner sessions in pounds.
  factory FitnessPlan.defaults() => const FitnessPlan(
        split: SplitType.ppl,
        daysPerWeek: 3,
        durationMinutes: 60,
        experience: ExperienceLevel.beginner,
        units: WeightUnit.lb,
        sex: Sex.unspecified,
        age: 30,
        weight: 175,
      );

  FitnessPlan copyWith({
    SplitType? split,
    int? daysPerWeek,
    int? durationMinutes,
    ExperienceLevel? experience,
    WeightUnit? units,
    Sex? sex,
    int? age,
    double? weight,
  }) {
    return FitnessPlan(
      split: split ?? this.split,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      experience: experience ?? this.experience,
      units: units ?? this.units,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      weight: weight ?? this.weight,
    );
  }

  Map<String, dynamic> toJson() => {
        'split': split.wireValue,
        'daysPerWeek': daysPerWeek,
        'durationMinutes': durationMinutes,
        'experience': experience.wireValue,
        'units': units.wireValue,
        'sex': sex.wireValue,
        'age': age,
        'weight': weight,
      };

  factory FitnessPlan.fromJson(Map<String, dynamic> json) {
    final defaults = FitnessPlan.defaults();
    return FitnessPlan(
      split: SplitType.fromWire(json['split'] as String?),
      daysPerWeek: json['daysPerWeek'] as int? ?? defaults.daysPerWeek,
      durationMinutes:
          json['durationMinutes'] as int? ?? defaults.durationMinutes,
      experience: ExperienceLevel.fromWire(json['experience'] as String?),
      units: WeightUnit.fromWire(json['units'] as String?),
      sex: Sex.fromWire(json['sex'] as String?),
      age: json['age'] as int? ?? defaults.age,
      weight: (json['weight'] as num?)?.toDouble() ?? defaults.weight,
    );
  }
}
