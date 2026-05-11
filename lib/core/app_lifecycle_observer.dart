import 'package:flutter/widgets.dart';

/// Thin `WidgetsBindingObserver` wrapper that calls [onResumed] /
/// [onPaused] callbacks. Used by the rest-timer pipeline to dedupe
/// notification firing — when the app comes back to the foreground we
/// cancel the pending notification (the in-app `RestTimerCard` will play
/// the bell instead).
class AppLifecycleObserver with WidgetsBindingObserver {
  final VoidCallback? onResumed;
  final VoidCallback? onPaused;

  AppLifecycleObserver({this.onResumed, this.onPaused});

  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResumed?.call();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        onPaused?.call();
    }
  }
}
