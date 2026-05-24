import 'dart:async';

import 'package:clock/clock.dart';

import '../../../core/rest_timer_notifications.dart';
import '../../../core/session_audio.dart';

/// Coordinates the rest-timer bell across foreground/background.
///
/// Exactly one bell rings per deadline. The class enforces this by making
/// sure only one source is armed at any time:
///
///   * **Foreground**: a Dart Timer fires the in-app bell via [RestBell].
///     The OS notification is NOT scheduled — it could race with the
///     in-app timer.
///   * **Background**: the OS notification is the only source. The Dart
///     Timer is cancelled the moment we leave foreground.
///
/// Lifecycle transitions ([onLifecycleChange]) swap the source: leaving
/// foreground → schedule notification, cancel timer; returning to
/// foreground → cancel notification, re-arm timer.
///
/// If the deadline already elapsed while backgrounded, the OS notification
/// has already played and the re-arm path detects the negative remaining
/// and refuses to fire a second bell.
///
/// Reads the wall clock via `package:clock` so callers can drive it
/// under `fakeAsync`. The owner (bloc) tells the coordinator when the
/// deadline elapses by hand — it doesn't keep a reference to the
/// session state.
class RestBellCoordinator {
  RestBellCoordinator({
    required this.onDeadlineElapsed,
    RestBell? bell,
    RestNotificationScheduler? scheduler,
  })  : _bell = bell ?? SessionAudio.instance,
        _scheduler = scheduler ?? RestTimerNotifications.instance;

  /// Called from the foreground Timer when it fires. The owner clears
  /// its own deadline state in response — keeping that authority out
  /// of this class so the coordinator stays a pure side-effect manager.
  ///
  /// NOTE: We don't rely on RestTimerCard's onCompleted callback to do
  /// this — the widget ticks on its own 1s clock and can race ahead of
  /// this Timer, dispatching CancelRestTimer (which would cancel
  /// _restBellTimer) before we ever fire. That race is exactly the
  /// "silent-on-logging-screen" bug, since the logging screen is the
  /// only place RestTimerCard is mounted.
  final void Function() onDeadlineElapsed;

  final RestBell _bell;
  final RestNotificationScheduler _scheduler;

  Timer? _foregroundTimer;
  bool _appInForeground = true;

  /// React to a change in the active rest deadline. Pass the previous
  /// and next deadline values (null = no rest timer); a no-op when they
  /// match. The deadline source-of-truth lives on the session model;
  /// the coordinator never stores it.
  void onDeadlineChange(DateTime? before, DateTime? after) {
    if (before == after) return;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    if (after == null) {
      _scheduler.cancel();
      return;
    }
    if (_appInForeground) {
      // Foreground owns the bell — no OS notification scheduled.
      _scheduler.cancel();
      _armForegroundBell(after);
    } else {
      // Background owns the bell — OS notification handles it.
      _scheduler.schedule(after);
    }
  }

  /// React to an app foreground/background transition. [currentDeadline]
  /// is the active rest deadline at the time of the transition, or null
  /// if no rest timer is running. A no-op when foreground state hasn't
  /// actually changed.
  void onLifecycleChange({
    required bool foreground,
    required DateTime? currentDeadline,
  }) {
    if (foreground == _appInForeground) return;
    _appInForeground = foreground;
    if (currentDeadline == null) return;
    if (foreground) {
      // Returning to foreground: cancel the OS notification, re-arm the
      // Dart timer. If the deadline elapsed while we were backgrounded,
      // _armForegroundBell sees a negative remaining and does nothing —
      // the OS notification already rang.
      _scheduler.cancel();
      _armForegroundBell(currentDeadline);
    } else {
      // Leaving foreground: hand the bell to the OS notification.
      _foregroundTimer?.cancel();
      _foregroundTimer = null;
      _scheduler.schedule(currentDeadline);
    }
  }

  void _armForegroundBell(DateTime ends) {
    _foregroundTimer?.cancel();
    final remaining = ends.difference(clock.now());
    if (remaining.isNegative) return;
    _foregroundTimer = Timer(remaining, () {
      _foregroundTimer = null;
      _bell.playRestComplete();
      onDeadlineElapsed();
    });
  }

  /// Cancel any in-flight OS notification. Called from finish/cancel
  /// paths where the bloc shuts everything down deterministically.
  Future<void> cancelNotification() => _scheduler.cancel();

  void dispose() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
  }
}
