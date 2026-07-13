import '../../models/exercise.dart';
import '../../models/generator/duration_profile.dart';
import '../../models/generator/generator_slot.dart';
import '../../models/generator/set_density_table.dart';

/// Resolves the working-set count for a generated exercise.
///
/// Ports the prototype's `getDensityRoleForExercise` + `_setsForRole` +
/// per-category cap (`EXERCISE_SET_LIMITS`). The density *role* can differ from
/// the slot role: a movement whose category is a core category, or whose
/// metadata marks it a core/compound role, is scored on that basis rather than
/// the slot's nominal role. This keeps set counts honest when a lift lands in a
/// thin slot (e.g. a compound in a triceps-push slot, or a back-extension core
/// movement in a support slot).
class SetDensityResolver {
  final SetDensityTable table;
  final GeneratorMetadataTables metadata;

  SetDensityResolver({required this.table, required this.metadata});

  /// Core categories that always resolve to the core density role, matching the
  /// prototype's `DENSITY_CORE_CATEGORIES`.
  static const _coreCategories = {
    'abs',
    'core',
    'core accessory',
    'back extension',
    'crunch',
    'leg raise',
  };

  /// Hard set ceilings the prototype applies after the role lookup:
  /// compounds max 6, everything else max 5.
  static const _compoundHardCap = 6;
  static const _otherHardCap = 5;

  /// Working sets for [exercise] filling [slot] at [minutes].
  int setsFor(Exercise exercise, GeneratorSlot slot, int minutes) {
    final role = _densityRole(exercise, slot);
    final hardCap = _isCompoundRole(role) ? _compoundHardCap : _otherHardCap;

    // Role-derived working-set target (already includes isolation +1).
    var sets = table.setsFor(role, minutes);

    // Lower to the per-category cap when it's tighter (EXERCISE_SET_LIMITS).
    final category = exercise.generatorMeta?.category;
    if (category != null) {
      final categoryCap = metadata.setLimitFor(category, hardCap);
      if (categoryCap < sets) sets = categoryCap;
    }

    return sets.clamp(1, hardCap);
  }

  bool _isCompoundRole(SlotRole role) =>
      role == SlotRole.primaryCompound || role == SlotRole.secondaryCompound;

  /// Resolves the density role (metadata/category can override slot role).
  SlotRole _densityRole(Exercise exercise, GeneratorSlot slot) {
    final slotRole = slot.role ?? SlotRole.isolation;
    if (slotRole == SlotRole.core) return SlotRole.core;

    final meta = exercise.generatorMeta;
    // Category-driven core movements always get the core role.
    if (meta != null && _coreCategories.contains(meta.category)) {
      return SlotRole.core;
    }

    // Metadata hypertrophy role wins when present (accessory normalizes to
    // isolation, matching the prototype).
    final hyper = meta?.hypertrophyRole;
    switch (hyper) {
      case 'primary_compound':
        return SlotRole.primaryCompound;
      case 'secondary_compound':
        return SlotRole.secondaryCompound;
      case 'isolation':
      case 'accessory':
        return SlotRole.isolation;
      case 'core':
        return SlotRole.core;
    }
    return slotRole;
  }
}
