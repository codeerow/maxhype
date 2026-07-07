/// User training experience, mirroring the web prototype's four tiers.
///
/// The prototype ranks these as none:0 < beginner:1 < intermediate:2 <
/// advanced:3 and gates exercises by a per-exercise minimum. [rank] preserves
/// that ordering so eligibility checks are a simple `userRank >= minRank`.
enum ExperienceLevel {
  none,
  beginner,
  intermediate,
  advanced;

  int get rank => index;

  String get wireValue {
    switch (this) {
      case ExperienceLevel.none:
        return 'none';
      case ExperienceLevel.beginner:
        return 'beginner';
      case ExperienceLevel.intermediate:
        return 'intermediate';
      case ExperienceLevel.advanced:
        return 'advanced';
    }
  }

  String get displayName {
    switch (this) {
      case ExperienceLevel.none:
        return 'Less than 1 year';
      case ExperienceLevel.beginner:
        return 'Beginner';
      case ExperienceLevel.intermediate:
        return 'Intermediate';
      case ExperienceLevel.advanced:
        return 'Advanced';
    }
  }

  /// Parses the prototype's lowercase string; unknown/legacy values fall back
  /// to [beginner], matching the prototype's own normalization.
  static ExperienceLevel fromWire(String? value) {
    switch (value) {
      case 'none':
        return ExperienceLevel.none;
      case 'beginner':
        return ExperienceLevel.beginner;
      case 'intermediate':
        return ExperienceLevel.intermediate;
      case 'advanced':
        return ExperienceLevel.advanced;
      default:
        return ExperienceLevel.beginner;
    }
  }
}
