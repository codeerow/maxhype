import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules a wall-clock notification that fires when the rest timer
/// runs out. Survives app backgrounding and process kill — on Android via
/// AlarmManager exact alarms, on iOS via UNUserNotificationCenter.
///
/// The boxing-bell sample we already ship as `assets/audio/boxing_bell.mp3`
/// is also wired in as the notification sound. On Android this needs the
/// raw resource (not an asset) — for now we use the platform default
/// notification sound; ship a raw resource in M11 polish.
class RestTimerNotifications {
  RestTimerNotifications._();
  static final instance = RestTimerNotifications._();

  static const _channelId = 'rest_timer';
  static const _channelName = 'Rest timer';
  static const _channelDescription =
      'Plays the boxing bell when your rest timer is up';
  static const _notificationId = 1001;

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
      // Default sound for now — see class doc.
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      // Falls back to default notification sound. To use the boxing bell
      // sample, drop a `boxing_bell.caf` next to the iOS Runner target and
      // pass `sound: 'boxing_bell.caf'` here.
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Rest complete',
      body: 'Time to crush the next set 💪',
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails:
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel the scheduled rest notification, if any.
  Future<void> cancel() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notificationId);
  }
}
