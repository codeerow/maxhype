import 'package:shared_preferences/shared_preferences.dart';

/// Provides the app's *week-scoped* notion of "now".
///
/// Only the milestone's week-scoped behaviour reads this — the "Completed this
/// week" card lock and cross-session rotation memory (which dedups completions
/// per ISO week). Rest/session timers deliberately do NOT use it; they stay on
/// real wall-clock time (`clock.now()` / `DateTime.now()`) so nothing about a
/// running timer changes when the demo week is bumped.
///
/// Two implementations:
///  * [RealWeekClock]  — `now()` is exactly real time. Used in production
///    release builds and in tests by default.
///  * [DemoWeekClock]  — `now()` is real time shifted by a whole number of
///    weeks, so a presenter can fast-forward past the week boundary from inside
///    the app (debug builds only, via the Plan screen's debug section).
// ignore: one_member_abstracts
abstract class WeekClock {
  /// The app's week-scoped "now".
  DateTime now();
}

/// Real time. No offset, nothing persisted. This is what ships.
class RealWeekClock implements WeekClock {
  const RealWeekClock();

  @override
  DateTime now() => DateTime.now();
}

/// A demo-only [WeekClock] that fast-forwards "now" by whole weeks WITHOUT
/// touching the device system clock.
///
/// Why not change the phone's date: that also yanks rest-timers, history, and
/// the calendar, and Android's network-time sync can silently revert it
/// mid-demo. Shifting only the week-scoped clock keeps everything else on real
/// time. The offset is persisted so a bump survives an app restart (a
/// completed-lock demo often restarts the app to prove persistence).
class DemoWeekClock implements WeekClock {
  DemoWeekClock({SharedPreferences? prefs}) : _prefs = prefs;

  static const _prefsKey = 'demo_week_offset';

  SharedPreferences? _prefs;
  int _weekOffset = 0;

  /// Number of whole weeks the clock is shifted forward from real time.
  /// 0 means it behaves exactly like real time.
  int get weekOffset => _weekOffset;

  /// Load the persisted offset. Call once at startup.
  Future<void> load() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    _weekOffset = prefs.getInt(_prefsKey) ?? 0;
  }

  /// Shift the demo clock by [delta] weeks (result clamped to 0..12 so a demo
  /// can't wander into a date that breaks unrelated date math).
  Future<void> bumpWeeks(int delta) => setWeekOffset(_weekOffset + delta);

  /// Reset back to real time.
  Future<void> reset() => setWeekOffset(0);

  Future<void> setWeekOffset(int offset) async {
    _weekOffset = offset.clamp(0, 12);
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, _weekOffset);
  }

  @override
  DateTime now() => DateTime.now().add(Duration(days: 7 * _weekOffset));
}
