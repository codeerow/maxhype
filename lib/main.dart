import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:progressive_blur/progressive_blur.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_scaffold.dart';
import 'screens/workout_session/workout_session_screen.dart';
import 'screens/workout_session/bloc/workout_session_bloc.dart';
import 'screens/workout_session/bloc/workout_session_event.dart';
import 'core/app_lifecycle_observer.dart';
import 'core/rest_timer_notifications.dart';
import 'core/service_locator.dart';
import 'core/bloc_factory.dart';
import 'repositories/workout_session_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await setupDependencies();

  // Wire up rest-timer notifications. Init is fire-and-forget — actual
  // permission request happens at the moment the user starts a workout
  // (so we ask in context, not on cold launch).
  await RestTimerNotifications.instance.init();

  // Precache the progressive-blur shader so the first time it shows up
  // (workout detail screen) there's no pop-in while the fragment shader
  // compiles.
  unawaited(ProgressiveBlurWidget.precache());

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Probe for an active session before first frame so we can decide whether
  // to push the session screen on top of MainScaffold during launch.
  final hasActiveSession =
      await getIt<WorkoutSessionRepository>().loadActive() != null;

  runApp(MyApp(restoreActiveSession: hasActiveSession));
}

class MyApp extends StatelessWidget {
  final bool restoreActiveSession;

  /// Global key for the MaterialApp's root Navigator so we can push the
  /// restored session screen onto it after first frame. Pushing onto the
  /// **root** Navigator (not a nested one) is what lets the system back
  /// gesture pop the session screen instead of exiting the app.
  static final GlobalKey<NavigatorState> rootNavKey =
      GlobalKey<NavigatorState>();

  const MyApp({super.key, this.restoreActiveSession = false});

  @override
  Widget build(BuildContext context) {
    return Provider<BlocFactory>(
      create: (_) => BlocFactory(getIt: getIt),
      child: BlocProvider<WorkoutSessionBloc>.value(
        value: getIt<WorkoutSessionBloc>(),
        child: MaterialApp(
          title: 'MaxHype',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          navigatorKey: rootNavKey,
          navigatorObservers: [
            getIt<RouteObserver<PageRoute<dynamic>>>(),
          ],
          home: _LaunchShell(restoreActiveSession: restoreActiveSession),
        ),
      ),
    );
  }
}

/// Stateful wrapper that mounts MainScaffold and, on first frame, optionally
/// pushes the restored session screen onto the root Navigator. This keeps the
/// session route on the same Navigator stack as the rest of the app, so
/// system-back / Android predictive back works correctly.
class _LaunchShell extends StatefulWidget {
  final bool restoreActiveSession;
  const _LaunchShell({required this.restoreActiveSession});

  @override
  State<_LaunchShell> createState() => _LaunchShellState();
}

class _LaunchShellState extends State<_LaunchShell> {
  late final AppLifecycleObserver _lifecycle;

  @override
  void initState() {
    super.initState();
    if (widget.restoreActiveSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        getIt<WorkoutSessionBloc>().add(const RestoreSession());
        MyApp.rootNavKey.currentState?.push(
          CupertinoPageRoute<void>(
            builder: (_) => WorkoutSessionScreen.restored(),
          ),
        );
      });
    }

    // When the app comes back to the foreground we cancel the pending
    // rest-end notification — the in-app `RestTimerCard` plays the bell
    // itself, and we don't want a double-ring once the system catches up.
    _lifecycle = AppLifecycleObserver(
      onResumed: () => RestTimerNotifications.instance.cancel(),
    )..attach();
  }

  @override
  void dispose() {
    _lifecycle.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const MainScaffold();
}
