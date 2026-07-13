/// The role a slot plays in the workout, driving set-density lookup.
enum SlotRole {
  primaryCompound,
  secondaryCompound,
  isolation,
  accessory,
  core;

  String get wireValue {
    switch (this) {
      case SlotRole.primaryCompound:
        return 'primary_compound';
      case SlotRole.secondaryCompound:
        return 'secondary_compound';
      case SlotRole.isolation:
        return 'isolation';
      case SlotRole.accessory:
        return 'accessory';
      case SlotRole.core:
        return 'core';
    }
  }

  static SlotRole? fromWire(String? value) {
    switch (value) {
      case 'primary_compound':
        return SlotRole.primaryCompound;
      case 'secondary_compound':
        return SlotRole.secondaryCompound;
      case 'isolation':
        return SlotRole.isolation;
      case 'accessory':
        return SlotRole.accessory;
      case 'core':
        return SlotRole.core;
      default:
        return null;
    }
  }
}

/// A runtime-selectable alternative form of a slot, chosen by the generator's
/// seedable RNG. Ported from the prototype's `Math.random() < probability`
/// coin flip on the Push triceps_push slot (which swaps its category order to
/// favor compound-press picks ~30% of the time).
class SlotRandomVariant {
  final double probability;
  final GeneratorSlot alt;

  const SlotRandomVariant({required this.probability, required this.alt});

  factory SlotRandomVariant.fromJson(Map<String, dynamic> json) =>
      SlotRandomVariant(
        probability: (json['probability'] as num).toDouble(),
        alt: GeneratorSlot.fromJson(json['alt'] as Map<String, dynamic>),
      );
}

/// One slot in a duration-specific PPL plan — the full prototype shape.
///
/// The generator walks a plan's ordered slots and fills each with an exercise
/// drawn from [categories] (a priority-ordered pool), honoring [unifyPool] /
/// [categoryBias] (weighted merge across categories), [excludeMovementGroups],
/// and [includeNameKeywords]. If nothing resolves, it falls back to
/// [defaultExercise].
class GeneratorSlot {
  /// Stable slot identity, e.g. "chest_compound", "triceps_push", "legs_core".
  final String? slotType;

  /// Set-density role. Null for the rare slot with no role hint.
  final SlotRole? role;

  /// Priority-ordered category pool the slot can draw from.
  final List<String> categories;

  /// Primary category (used for grouping / default resolution / caps).
  final String? category;

  /// When true, the fill's first pass merges all [categories] into one pool
  /// and scores candidates with [categoryBias] rather than trying categories
  /// in strict order.
  final bool unifyPool;

  /// category → additive bias used when [unifyPool] is set.
  final Map<String, int>? categoryBias;

  /// Movement groups the slot hard-excludes (e.g. triceps_stretch excludes
  /// pushdown/kickback groups).
  final List<String>? excludeMovementGroups;

  /// Soft keyword preference — the fill prefers names containing one of these.
  final List<String>? includeNameKeywords;

  final String? defaultExercise;
  final String? defaultPerf;

  /// Present only on slots that randomize their form at build time.
  final SlotRandomVariant? randomVariant;

  const GeneratorSlot({
    this.slotType,
    this.role,
    this.categories = const [],
    this.category,
    this.unifyPool = false,
    this.categoryBias,
    this.excludeMovementGroups,
    this.includeNameKeywords,
    this.defaultExercise,
    this.defaultPerf,
    this.randomVariant,
  });

  factory GeneratorSlot.fromJson(Map<String, dynamic> json) {
    return GeneratorSlot(
      slotType: json['slotType'] as String?,
      role: SlotRole.fromWire(json['role'] as String?),
      categories:
          (json['categories'] as List<dynamic>? ?? const []).cast<String>(),
      category: json['category'] as String?,
      unifyPool: json['unifyPool'] as bool? ?? false,
      categoryBias: (json['categoryBias'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)),
      excludeMovementGroups:
          (json['excludeMovementGroups'] as List<dynamic>?)?.cast<String>(),
      includeNameKeywords:
          (json['includeNameKeywords'] as List<dynamic>?)?.cast<String>(),
      defaultExercise: json['defaultExercise'] as String?,
      defaultPerf: json['defaultPerf'] as String?,
      randomVariant: json['randomVariant'] == null
          ? null
          : SlotRandomVariant.fromJson(
              json['randomVariant'] as Map<String, dynamic>),
    );
  }
}

/// All duration-specific slot plans for the three PPL splits.
/// split name → duration (minutes) → ordered slot list.
class SlotPlans {
  final Map<String, Map<int, List<GeneratorSlot>>> _plans;

  const SlotPlans(this._plans);

  /// Ordered slots for a split at a duration, or empty if none.
  List<GeneratorSlot> slotsFor(String splitName, int minutes) =>
      _plans[splitName]?[minutes] ?? const [];

  factory SlotPlans.fromJson(Map<String, dynamic> json) {
    final plans = <String, Map<int, List<GeneratorSlot>>>{};
    json.forEach((split, byDuration) {
      final durMap = <int, List<GeneratorSlot>>{};
      (byDuration as Map<String, dynamic>).forEach((minsKey, slots) {
        durMap[int.parse(minsKey)] = (slots as List<dynamic>)
            .map((s) => GeneratorSlot.fromJson(s as Map<String, dynamic>))
            .toList(growable: false);
      });
      plans[split] = durMap;
    });
    return SlotPlans(plans);
  }
}
