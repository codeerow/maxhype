import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/app_header.dart';
import '../../widgets/workout_cards_scroll.dart';
import '../../widgets/all_time_charts.dart';
import '../../core/bloc_factory.dart';
import '../home_tab_visibility.dart';
import '../workout_session/bloc/workout_session_bloc.dart';
import '../workout_session/bloc/workout_session_state.dart';
import 'bloc/home_bloc.dart';
import 'bloc/home_event.dart';
import 'bloc/home_state.dart';

// Bottom padding for the scrolling tab content so its tail can pass
// under the floating WORKOUT IN PROGRESS bar pinned by MainScaffold.
// Sized to comfortably clear the bar's visual height including its
// SafeArea inset on devices with a home indicator.
const double _kBottomBarReserve = 96;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        const event = HomeInitial();
        return context.read<BlocFactory>().create<HomeBloc>()..add(event);
      },
      // Poke a workout re-read when the app returns to the foreground on Home
      // (tab re-selected or resumed from background). The generated repository
      // rebuilds the cards if the ISO week rolled over, so a new week reflects
      // rotation memory without a manual plan save.
      child: _HomeForegroundRefresh(
        child: BlocListener<WorkoutSessionBloc, WorkoutSessionState>(
          // Refresh the completion map whenever a session finishes so the
          // matching workout card flips to its "Completed" state without
          // the user having to navigate away and back (brief §1).
          listenWhen: (prev, next) =>
              prev is! SessionFinished && next is SessionFinished,
          listener: (context, _) {
            final homeBloc = context.read<HomeBloc>();
            homeBloc.add(const RefreshCompletions());
          },
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              return switch (state) {
                HomeLoading() => const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                HomeError(:final message) => Scaffold(
                  body: Center(
                    child: Text('Error: $message'),
                  ),
                ),
                HomeSuccess(
                  :final workouts,
                  :final monthlyData,
                  :final completions,
                ) =>
                  Scaffold(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    body: SafeArea(
                      child: SingleChildScrollView(
                        // Bottom padding reserves space for the floating
                        // WORKOUT IN PROGRESS bar so the last chart can
                        // scroll under it instead of stopping at its edge.
                        padding: const EdgeInsets.only(
                          bottom: _kBottomBarReserve,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            const SizedBox(
                              width: double.infinity,
                              child: AppHeader(),
                            ),
                            const SizedBox(height: 32),
                            WorkoutCardsScroll(
                              workouts: workouts,
                              completions: completions,
                            ),
                            const SizedBox(height: 8),
                            AllTimeCharts(monthlyData: monthlyData),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
              };
            },
          ),
        ),
      ),
    );
  }
}

/// Dispatches [RefreshWorkouts] to the ambient [HomeBloc] whenever the app
/// returns to the foreground on the Home tab — either the bottom-nav switching
/// back to Home, or the app resuming from background. Keeps the workout list in
/// sync with an ISO-week rollover (see [RefreshWorkouts]) without any manual
/// action. A plain lifecycle/visibility observer; renders its [child] as-is.
class _HomeForegroundRefresh extends StatefulWidget {
  const _HomeForegroundRefresh({required this.child});

  final Widget child;

  @override
  State<_HomeForegroundRefresh> createState() => _HomeForegroundRefreshState();
}

class _HomeForegroundRefreshState extends State<_HomeForegroundRefresh>
    with WidgetsBindingObserver {
  ValueNotifier<int>? _tabIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = HomeTabVisibility.of(context);
    if (notifier != _tabIndex) {
      _tabIndex?.removeListener(_onTabChanged);
      _tabIndex = notifier;
      _tabIndex?.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (_tabIndex?.value == HomeTabVisibility.homeIndex) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only when Home is the visible tab — no point rebuilding cards the user
    // isn't looking at; the next return-to-Home covers that.
    if (state == AppLifecycleState.resumed &&
        (_tabIndex?.value ?? HomeTabVisibility.homeIndex) ==
            HomeTabVisibility.homeIndex) {
      _refresh();
    }
  }

  void _refresh() {
    if (!mounted) return;
    context.read<HomeBloc>().add(const RefreshWorkouts());
  }

  @override
  void dispose() {
    _tabIndex?.removeListener(_onTabChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
