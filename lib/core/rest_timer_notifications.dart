import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules a wall-clock notification that fires when the rest timer
/// runs out. Survives app backgrounding and process kill — on Android via
/// AlarmManager exact alarms, on iOS via UNUserNotificationCenter.
///
/// Boxing-bell sound is bundled at:
///   * `android/app/src/main/res/raw/boxing_bell.mp3` (raw resource)
///   * `ios/Runner/boxing_bell.caf` (bundle resource — add via Xcode)
///
/// Android binds the sound at *channel creation* time. The channel id is
/// versioned (`rest_timer_v2`) so devices that already created the v1
/// silent channel get a fresh one with the bell attached.
class RestTimerNotifications {
  RestTimerNotifications._();
  static final instance = RestTimerNotifications._();

  // Bumped on every change to channel sound or audio attributes — both
  // are locked at channel creation on Android 8+ and the only way to
  // update existing users is a fresh channel id. v3 adds USAGE_ALARM so
  // the bell plays through DND and via the louder alarm stream.
  static const _channelId = 'rest_timer_v3';
  static const _channelName = 'Rest timer';
  static const _channelDescription =
      'Plays the boxing bell when your rest timer is up';
  static const _legacyChannelIds = ['rest_timer', 'rest_timer_v2'];
  static const _notificationId = 1001;
  // Android resource name (without extension) under res/raw/.
  static const _androidSoundResource = 'boxing_bell';
  // iOS bundle resource — drop boxing_bell.caf into the Runner target.
  static const _iosSoundFile = 'boxing_bell.caf';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Best-effort local timezone — falls back to UTC if the lookup fails.
    try {
      tz.setLocalLocation(tz.getLocation(tz.local.name));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      // We request these later through requestPermissions(); init defaults
      // here are conservative.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create the Android channel up front with the bell wired in. The
    // sound is locked to the channel at creation time on Android 8+, so
    // this must run before the first schedule() call. Re-running it is a
    // no-op when the channel already exists with the same settings.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Drop legacy channels so they stop showing in the user's
      // app-notification settings (and so any device that already had
      // them with weaker settings stops using them).
      for (final id in _legacyChannelIds) {
        await android.deleteNotificationChannel(channelId: id);
      }
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(_androidSoundResource),
          enableVibration: true,
          // Route bell playback through STREAM_ALARM. Combined with
          // CATEGORY_ALARM on each notification, this:
          //  - plays through Do-Not-Disturb without extra permissions,
          //  - uses the (louder) alarm volume slider,
          //  - is not suppressed when the app is in foreground.
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    }

    _initialized = true;
  }

  /// Ask the user for notification permission. Returns whether the
  /// permission is granted (true) or denied (false). Safe to call
  /// repeatedly — the OS shows the dialog only once.
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  /// Schedule (or replace) the rest-end notification for [endsAt]. If the
  /// timer is already past, fires immediately.
  Future<void> schedule(DateTime endsAt) async {
    await init();
    final when = endsAt.isAfter(DateTime.now())
        ? endsAt
        : DateTime.now().add(const Duration(seconds: 1));

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(_androidSoundResource),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: _iosSoundFile,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Rest complete',
      body: 'Time to crush the next set 💪',
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails:
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
      // setAlarmClock under the hood — strictly stronger than
      // exactAllowWhileIdle: shows a permanent clock icon, exits Doze
      // with the highest priority, and is broadly respected by aggressive
      // OEM killers (Xiaomi/Vivo/OPPO) as a user-facing alarm rather
      // than a discretionary background task.
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }

  /// Cancel the scheduled rest notification, if any.
  Future<void> cancel() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notificationId);
  }
}
