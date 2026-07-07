import 'experience_level.dart';

/// Set-density target for one (experience × split × duration) cell, ported from
/// the prototype's `DURATION_PROFILES`. Field names expand the prototype's
/// terse keys (ex/cS/iS/mS/sr).
class DurationProfile {
  /// Target number of exercises in the workout.
  final int exercises;

  /// Sets per compound exercise.
  final int compoundSets;

  /// Sets per isolation exercise.
  final int isolationSets;

  /// Cap on total working sets for any single exercise.
  final int maxWorkingSets;

  /// Inclusive [min, max] target range for total working sets in the workout.
  final int workingSetsMin;
  final int workingSetsMax;

  const DurationProfile({
    required this.exercises,
    required this.compoundSets,
    required this.isolationSets,
    required this.maxWorkingSets,
    required this.workingSetsMin,
    required this.workingSetsMax,
  });

  factory DurationProfile.fromJson(Map<String, dynamic> json) {
    final sr = (json['sr'] as List<dynamic>).cast<num>();
    return DurationProfile(
      exercises: json['ex'] as int,
      compoundSets: json['cS'] as int,
      isolationSets: json['iS'] as int,
      maxWorkingSets: json['mS'] as int,
      workingSetsMin: sr[0].toInt(),
      workingSetsMax: sr[1].toInt(),
    );
  }
}

/// All generator metadata tables, parsed from the `metadata` block of
/// `exercise_library.json`. Owned by the exercise repository and consumed by
/// the Part 2 generator.
class GeneratorMetadataTables {
  /// experience → split name → duration (minutes) → profile.
  final Map<ExperienceLevel, Map<String, Map<int, DurationProfile>>>
      durationProfiles;

  /// category → per-exercise working-set cap.
  final Map<String, int> setLimits;

  /// category → default selection tier ("A"/"B"/"C").
  final Map<String, String> categoryTier;

  const GeneratorMetadataTables({
    required this.durationProfiles,
    required this.setLimits,
    required this.categoryTier,
  });

  /// Looks up the profile for a cell, falling back to the nearest available
  /// duration tier — matching the prototype's `getDurationConfig` behavior.
  DurationProfile? profileFor({
    required ExperienceLevel experience,
    required String splitName,
    required int minutes,
  }) {
    final bySplit = durationProfiles[experience] ??
        durationProfiles[ExperienceLevel.beginner];
    if (bySplit == null) return null;
    final byDuration = bySplit[splitName] ?? bySplit['Push Day'];
    if (byDuration == null) return null;
    if (byDuration.containsKey(minutes)) return byDuration[minutes];

    // Nearest-tier fallback.
    int? best;
    for (final tier in byDuration.keys) {
      if (best == null || (tier - minutes).abs() < (best - minutes).abs()) {
        best = tier;
      }
    }
    return best == null ? null : byDuration[best];
  }

  /// Per-exercise set cap for a category, or [globalMax] when uncapped.
  int setLimitFor(String category, int globalMax) {
    final limit = setLimits[category];
    if (limit == null) return globalMax;
    return limit < globalMax ? limit : globalMax;
  }

  factory GeneratorMetadataTables.fromJson(Map<String, dynamic> json) {
    final rawProfiles =
        json['durationProfiles'] as Map<String, dynamic>? ?? const {};
    final profiles =
        <ExperienceLevel, Map<String, Map<int, DurationProfile>>>{};
    rawProfiles.forEach((expKey, splitMap) {
      final exp = ExperienceLevel.fromWire(expKey);
      final bySplit = <String, Map<int, DurationProfile>>{};
      (splitMap as Map<String, dynamic>).forEach((splitName, durMap) {
        final byDuration = <int, DurationProfile>{};
        (durMap as Map<String, dynamic>).forEach((minsKey, profile) {
          byDuration[int.parse(minsKey)] =
              DurationProfile.fromJson(profile as Map<String, dynamic>);
        });
        bySplit[splitName] = byDuration;
      });
      profiles[exp] = bySplit;
    });

    return GeneratorMetadataTables(
      durationProfiles: profiles,
      setLimits: (json['setLimits'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, v as int)),
      categoryTier: (json['categoryTier'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, v as String)),
    );
  }
}
