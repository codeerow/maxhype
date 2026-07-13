import 'generator_slot.dart';

/// The prototype's `_setsForRole` table: working sets per (role × duration).
///
/// Isolation/accessory rows are stored one BELOW the displayed target — the
/// prototype's `makeSets` adds a +1 "display compensation" in default mode
/// (there's no warm-up row for isolation), while core is exempt. [setsFor]
/// applies that rule so callers get the displayed working-set count directly.
class SetDensityTable {
  /// role wire value → duration (minutes) → raw table value.
  final Map<String, Map<int, int>> _byRole;

  /// The +1 added to isolation/accessory displayed counts (core exempt).
  final int isolationDisplayCompensation;

  const SetDensityTable(this._byRole, {this.isolationDisplayCompensation = 1});

  /// Displayed working sets for a role at a duration, with the isolation
  /// compensation already applied. Falls back to the nearest duration tier.
  int setsFor(SlotRole role, int minutes) {
    final byDuration = _byRole[role.wireValue];
    if (byDuration == null || byDuration.isEmpty) return 3;

    var raw = byDuration[minutes];
    if (raw == null) {
      int? best;
      for (final tier in byDuration.keys) {
        if (best == null || (tier - minutes).abs() < (best - minutes).abs()) {
          best = tier;
        }
      }
      raw = byDuration[best]!;
    }

    if (role == SlotRole.isolation || role == SlotRole.accessory) {
      return raw + isolationDisplayCompensation;
    }
    return raw;
  }

  factory SetDensityTable.fromJson(
    Map<String, dynamic> setsByRole, {
    int isolationDisplayCompensation = 1,
  }) {
    final byRole = <String, Map<int, int>>{};
    setsByRole.forEach((role, byDuration) {
      byRole[role] = (byDuration as Map<String, dynamic>)
          .map((minsKey, sets) => MapEntry(int.parse(minsKey), sets as int));
    });
    return SetDensityTable(
      byRole,
      isolationDisplayCompensation: isolationDisplayCompensation,
    );
  }
}
