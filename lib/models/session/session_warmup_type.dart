enum WarmupType { none, treadmill, stationaryBike, elliptical }

extension WarmupTypeExtension on WarmupType {
  String get displayName {
    switch (this) {
      case WarmupType.none:
        return 'None';
      case WarmupType.treadmill:
        return 'Treadmill';
      case WarmupType.stationaryBike:
        return 'Stationary Bike';
      case WarmupType.elliptical:
        return 'Elliptical';
    }
  }

  String get storageKey {
    switch (this) {
      case WarmupType.none:
        return 'none';
      case WarmupType.treadmill:
        return 'treadmill';
      case WarmupType.stationaryBike:
        return 'stationaryBike';
      case WarmupType.elliptical:
        return 'elliptical';
    }
  }

  static WarmupType fromKey(String? key) {
    switch (key) {
      case 'treadmill':
        return WarmupType.treadmill;
      case 'stationaryBike':
        return WarmupType.stationaryBike;
      case 'elliptical':
        return WarmupType.elliptical;
      default:
        return WarmupType.none;
    }
  }
}
