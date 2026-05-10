/// Reusable animation building blocks shared across the app.
///
/// Includes:
///  * `PulseGlow`    — colored shadow with a constant base + one-shot pulse
///  * `ScaleInPop`   — scale-in pop animation for confirmation badges
///  * `AppDurations` — shared duration tokens used by these widgets
///
/// `TapScale` (in `widgets/tap_scale.dart`) is the press-feedback wrapper
/// and is part of the same animation toolkit but kept at its long-standing
/// path to avoid touching its many call sites.
library;

export 'app_durations.dart';
export 'pulse_glow.dart';
export 'scale_in_pop.dart';
