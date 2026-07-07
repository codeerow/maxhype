/// One slot in a workout template — a priority-ordered position the generator
/// fills with an exercise from [category], falling back to [defaultExercise]
/// when generation can't resolve a candidate.
class WorkoutSlot {
  final String category;
  final String defaultExercise;

  /// Prototype's placeholder performance string, e.g. "135 x 8".
  final String defaultPerf;

  const WorkoutSlot({
    required this.category,
    required this.defaultExercise,
    required this.defaultPerf,
  });

  factory WorkoutSlot.fromJson(Map<String, dynamic> json) => WorkoutSlot(
        category: json['category'] as String,
        defaultExercise: json['defaultExercise'] as String,
        defaultPerf: json['defaultPerf'] as String,
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'defaultExercise': defaultExercise,
        'defaultPerf': defaultPerf,
      };
}

/// A slot-based workout template (Push Day / Pull Day / Legs + Core). Slots are
/// priority-ordered: the generator walks them and trims to the target exercise
/// count from the active duration profile.
class WorkoutTemplate {
  final String name;
  final List<WorkoutSlot> slots;

  const WorkoutTemplate({required this.name, required this.slots});

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) => WorkoutTemplate(
        name: json['name'] as String,
        slots: (json['slots'] as List<dynamic>)
            .map((s) => WorkoutSlot.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
