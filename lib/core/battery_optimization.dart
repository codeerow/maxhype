import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks the user to whitelist the app from Android battery optimization on
/// their *first* workout, then tracks the answer:
///
///  * If the user grants the exemption (or already had), we trust the OS
///    to keep our scheduled rest-end notification alive.
///  * If the user declines, we start a `flutter_foreground_task` service
///    for the duration of each workout — the persistent notification
///    stops aggressive killers (Xiaomi, Huawei…) from suspending us
///    mid-rest.
///
/// On iOS this is a no-op — the platform handles scheduled notifications
/// reliably without user opt-in.
class BatteryOptimization {
  BatteryOptimization._();
  static final instance = BatteryOptimization._();

  static const _kPrefKey = 'battery_optimization.user_choice';
  // 'granted'   — user said yes (or system reports already exempt).
  // 'declined'  — user said no, fall back to foreground service.

  bool _foregroundServiceInitialized = false;

  /// Decide whether we need a foreground service for this workout, and
  /// (if Android) prompt the user the first time. Safe to call on every
  /// `StartSession`; the prompt only shows once.
  Future<void> ensureCovered(BuildContext context) async {
    if (!Platform.isAndroid) return;

    // If already exempt — nothing to do, no service needed.
    if (await Permission.ignoreBatteryOptimizations.isGranted) {
      await _markGranted();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kPrefKey);
    if (stored == null) {
      if (!context.mounted) return;
      final wantsExempt = await _showExplainerDialog(context);
      if (wantsExempt) {
        final result =
            await Permission.ignoreBatteryOptimizations.request();
        if (result.isGranted) {
          await _markGranted();
          return;
        }
        // User declined the system dialog — same fallback path as if
        // they tapped "Skip" in our explainer.
      }
      await prefs.setString(_kPrefKey, 'declined');
    }

    // Either declined now, or declined before — start the foreground
    // service so the OS keeps us alive during the workout.
    await _startForegroundService();
  }

  /// Stop the foreground service when the workout ends or is cancelled.
  Future<void> stopForegroundService() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> _markGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, 'granted');
  }

  Future<bool> _showExplainerDialog(BuildContext context) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reliable rest notifications'),
        content: const Text(
          'Allow MaxHype to ignore battery optimization so the rest-timer '
          'notification fires exactly on time, even when your screen is '
          'off. You can change this later in Settings.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Skip'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _startForegroundService() async {
    if (!_foregroundServiceInitialized) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'maxhype_workout',
          channelName: 'Workout in progress',
          channelDescription:
              'Keeps the rest-timer accurate while a workout is running',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          allowWakeLock: true,
        ),
      );
      _foregroundServiceInitialized = true;
    }
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      notificationTitle: 'Workout in progress',
      notificationText: 'MaxHype keeps your rest timer running',
    );
  }
}
