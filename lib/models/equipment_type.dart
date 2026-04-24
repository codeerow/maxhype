enum EquipmentType {
  dumbbell,
  barbell,
  cable,
  bodyweight,
  machine,
}

extension EquipmentTypeExtension on EquipmentType {
  String get displayName {
    switch (this) {
      case EquipmentType.dumbbell:
        return 'Dumbbell';
      case EquipmentType.barbell:
        return 'Barbell';
      case EquipmentType.cable:
        return 'Cable';
      case EquipmentType.bodyweight:
        return 'Bodyweight';
      case EquipmentType.machine:
        return 'Machine';
    }
  }
}
