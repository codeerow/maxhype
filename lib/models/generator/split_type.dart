/// Training split architecture.
///
/// Part 1 supports all four splits at the *architecture* level so the fitness
/// plan can persist any of them without a future refactor. Part 2's generator
/// only implements [ppl]; the others are reserved (the web prototype routes
/// Upper/Lower and Full Body through a separate blueprint path).
enum SplitType {
  ppl,
  pplUpperLower,
  upperLower,
  fullBody;

  String get wireValue {
    switch (this) {
      case SplitType.ppl:
        return 'ppl';
      case SplitType.pplUpperLower:
        return 'ppl_upper_lower';
      case SplitType.upperLower:
        return 'upper_lower';
      case SplitType.fullBody:
        return 'full_body';
    }
  }

  String get displayName {
    switch (this) {
      case SplitType.ppl:
        return 'Push / Pull / Legs';
      case SplitType.pplUpperLower:
        return 'PPL + Upper / Lower';
      case SplitType.upperLower:
        return 'Upper / Lower';
      case SplitType.fullBody:
        return 'Full Body';
    }
  }

  /// Whether the Part 2 generator can currently produce this split.
  bool get isGeneratorSupported => this == SplitType.ppl;

  static SplitType fromWire(String? value) {
    switch (value) {
      case 'ppl':
        return SplitType.ppl;
      case 'ppl_upper_lower':
        return SplitType.pplUpperLower;
      case 'upper_lower':
        return SplitType.upperLower;
      case 'full_body':
        return SplitType.fullBody;
      default:
        return SplitType.ppl;
    }
  }
}

/// The workout durations the generator profiles support (minutes).
const List<int> kSupportedDurations = [45, 60, 75, 90, 105, 120];
