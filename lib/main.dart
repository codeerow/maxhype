import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_scaffold.dart';
import 'screens/workout_session/workout_session_screen.dart';
import 'screens/workout_session/bloc/workout_session_bloc.dart';
import 'screens/workout_session/bloc/workout_session_event.dart';
import 'core/service_locator.dart';
import 'core/bloc_factory.dart';
import 'repositories/workout_session_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await setupDependencies();

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

  const MyApp({super.key, this.restoreActiveSession = false});

  @override
  Widget build(BuildContext context) {
    return Provider<BlocFactory>(
      create: (_) => BlocFactory(getIt: getIt),
      child: MaterialApp(
        title: 'MaxHype',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: _RootShell(restoreActiveSession: restoreActiveSession),
      ),
    );
  }
}

class _RootShell extends StatefulWidget {
  final bool restoreActiveSession;
  const _RootShell({required this.restoreActiveSession});

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (widget.restoreActiveSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Tell the bloc to load the persisted session, then push the screen.
        getIt<WorkoutSessionBloc>().add(const RestoreSession());
        _navKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => WorkoutSessionScreen.restored(),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (_) => const MainScaffold());
      },
    );
  }
}
