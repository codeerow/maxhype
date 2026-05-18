import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Centralized haptic feedback service.
///
/// All UI code should call into [HapticManager] rather than `HapticFeedback.*`
/// directly so we have one place to:
///   - tune intensity tiers consistently across the app,
///   - mute everything (e.g., a future user setting),
///   - swap implementations on platforms that don't support it.
///
/// Tiered API maps semantically to user-facing meaning, not platform APIs:
///
///   * [selection] — picker/tab change. Feather-light tick.
///   * [light]     — primary tap on a non-destructive interactive element.
///   * [medium]    — confirmation of a meaningful state change (set logged,
///                   exercise completed).
///   * [success]   — positive completion (workout finished). Stronger than
///                   [medium].
///   * [warning]   — destructive confirmation needed (cancel workout).
///   * [error]     — failure / blocked action.
///   * [strongest] — celebratory: PR achieved, workout completed. The
///                   loudest tier; uses a multi-tap pattern.
abstract class HapticManager {
  bool get enabled;
  set enabled(bool value);

  Future<void> selection();
  Future<void> light();
  Future<void> medium();
  Future<void> success();
  Future<void> warning();
  Future<void> error();
  Future<void> strongest();
}

class DefaultHapticManager implements HapticManager {
  bool _enabled = true;

  /// Cached probe for whether the device's vibrator supports custom
  /// patterns. We only check once.
  bool? _supportsPatterns;

  @override
  bool get enabled => _enabled;

  @override
  set enabled(bool value) => _enabled = value;

  @override
  Future<void> selection() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  @override
  Future<void> light() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  @override
  Future<void> medium() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  @override
  Future<void> success() async {
    if (!_enabled) return;
    // Heavier than medium; on iOS this maps to UIImpactFeedbackGenerator
    // .heavy, which reads as "thing-completed".
    await HapticFeedback.heavyImpact();
  }

  @override
  Future<void> warning() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  @override
  Future<void> error() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  @override
  Future<void> strongest() async {
    if (!_enabled) return;
    if (Platform.isAndroid) {
      await _strongestAndroid();
      return;
    }
    // iOS: UIKit doesn't expose custom patterns through Flutter's
    // HapticFeedback, but chained heavy impacts read distinctly louder
    // than success() alone.
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.selectionClick();
  }

  Future<void> _strongestAndroid() async {
    _supportsPatterns ??= await Vibration.hasCustomVibrationsSupport();
    if (_supportsPatterns!) {
      // [delay, vibe, gap, vibe, gap, vibe] in ms — a celebratory triple-tap.
      await Vibration.vibrate(
        pattern: [0, 60, 50, 60, 50, 120],
        intensities: [0, 200, 0, 200, 0, 255],
      );
    } else {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    }
  }
}
