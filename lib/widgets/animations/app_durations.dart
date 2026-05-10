/// Centralized animation duration tokens used across the app's reusable
/// animation widgets. Concrete numbers live here so visual feel stays
/// consistent and tweakable from one place.
class AppDurations {
  AppDurations._();

  /// Quick press feedback (TapScale press-down).
  static const Duration pressDown = Duration(milliseconds: 80);

  /// Quick press release (TapScale release-up).
  static const Duration pressUp = Duration(milliseconds: 120);

  /// Soft glow pulse — single-pass triangular envelope. Used for the
  /// active-exercise indicator and the completion-checkmark badge.
  static const Duration pulseSoft = Duration(milliseconds: 260);

  /// Slightly longer pulse for "celebratory" moments (exercise completed).
  static const Duration pulseCelebratory = Duration(milliseconds: 520);

  /// Scale-in pop, e.g., the completion checkmark appearing.
  static const Duration scaleInPop = Duration(milliseconds: 260);

  /// Default delay before completion / pulse animations start, so they
  /// don't fire under an incoming Cupertino transition.
  static const Duration screenSettle = Duration(milliseconds: 420);
}
