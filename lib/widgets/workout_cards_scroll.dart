import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/workout.dart';
import '../models/workout_completion.dart';
import '../screens/home_tab_visibility.dart';
import '../screens/workout_session/bloc/workout_session_bloc.dart';
import '../screens/workout_session/bloc/workout_session_state.dart';
import 'carousel_positioning.dart';
import 'workout_card.dart';

/// Horizontal scroller of workout cards on the Home screen.
///
/// Auto-positioning (milestone Phase 3 Part 3, Item 3):
///
///   - On mount with a session already active → animate to the active
///     workout's card. The user returns to Home mid-session and lands
///     on what they're working on.
///   - On Active → Finished → hold on the just-finished (now Completed)
///     card for a brief moment so the user reads the new state, then
///     scroll to the next *not-completed* workout in the carousel.
///     Stays on the finished card if there is no such next workout.
///   - On Active → Cancelled → no special move; the cancelled card
///     reverts to Ready and the user stays where they are.
class WorkoutCardsScroll extends StatefulWidget {
  final List<Workout> workouts;
  final Map<String, WorkoutCompletion> completions;

  const WorkoutCardsScroll({
    super.key,
    required this.workouts,
    this.completions = const {},
  });

  @override
  State<WorkoutCardsScroll> createState() => _WorkoutCardsScrollState();
}

class _WorkoutCardsScrollState extends State<WorkoutCardsScroll> {
  final ScrollController _ctrl = ScrollController();
  String? _lastActiveWorkoutId;
  StreamSubscription<WorkoutSessionState>? _sub;
  Timer? _postFinishHold;

  /// Notifier exposed by MainScaffold that flips between Home / History
  /// indices. We listen so we can re-anchor on the active workout card
  /// the moment Home becomes visible again.
  ValueNotifier<int>? _tabIndex;

  /// Briefly hold on the completed card before scrolling to the next.
  /// Clarification 3.7 — long enough to register, short enough not to
  /// feel sluggish.
  static const Duration _completedHold = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    final bloc = context.read<WorkoutSessionBloc>();
    final cur = bloc.state;
    if (cur is SessionActive) {
      _lastActiveWorkoutId = cur.session.workoutId;
      // First-frame land on the active card. MediaQuery can't be
      // read during initState, so we defer to the post-frame
      // callback. _scrollTo internally waits for the controller to
      // have clients before driving the animation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final idx = activeCardIndex(
          workouts: widget.workouts,
          activeWorkoutId: cur.session.workoutId,
        );
        if (idx != null) _scrollTo(idx);
      });
    }
    _sub = bloc.stream.listen(_onState);
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
    if (_tabIndex?.value != HomeTabVisibility.homeIndex) return;
    // The bottom-nav just snapped back to Home. If a session is still
    // active, jump the carousel onto its card so the user lands on
    // what they're working on (brief Phase 3 Part 3 §3).
    final cur = context.read<WorkoutSessionBloc>().state;
    if (cur is! SessionActive) return;
    final idx = activeCardIndex(
      workouts: widget.workouts,
      activeWorkoutId: cur.session.workoutId,
    );
    if (idx != null) _scrollTo(idx);
  }

  @override
  void didUpdateWidget(WorkoutCardsScroll old) {
    super.didUpdateWidget(old);
    // If the active session id changed (e.g., user started a new
    // workout from a different card while Home was offscreen), pull
    // the carousel onto the new active card. The session bloc stream
    // listener also captures this for in-screen transitions; this
    // handles the rebuild that follows RefreshCompletions etc.
    final bloc = context.read<WorkoutSessionBloc>();
    final cur = bloc.state;
    if (cur is SessionActive &&
        cur.session.workoutId != _lastActiveWorkoutId) {
      _lastActiveWorkoutId = cur.session.workoutId;
      final idx = activeCardIndex(
        workouts: widget.workouts,
        activeWorkoutId: cur.session.workoutId,
      );
      if (idx != null) _scrollTo(idx);
    }
  }

  void _onState(WorkoutSessionState state) {
    // Keep `_lastActiveWorkoutId` populated for the entire Active →
    // Finishing → Finished chain. SessionFinishing arrives synchronously
    // before SessionFinished, and earlier we were wiping the cursor on
    // every non-Active state — by the time SessionFinished landed,
    // finishedId was already lost and the post-finish scroll never ran.
    //
    // Termination semantics we care about:
    //   SessionActive    → remember workoutId
    //   SessionFinishing → no-op (still part of the finish flow)
    //   SessionFinished  → snap onto the finished card, then animate to next
    //   SessionCancelled → drop the cursor without scrolling
    //   SessionIdle      → no-op (it's just the trailing reset emit)
    //   SessionLoading   → no-op
    if (state is SessionActive) {
      _lastActiveWorkoutId = state.session.workoutId;
      return;
    }
    if (state is SessionFinishing || state is SessionLoading) {
      return;
    }
    if (state is SessionCancelled) {
      _lastActiveWorkoutId = null;
      return;
    }
    if (state is! SessionFinished) {
      // SessionIdle — but only treat it as "drop cursor" when there's no
      // active session waiting in the wings (e.g., a stray Idle emit
      // after a finish has already been handled).
      return;
    }

    final finishedId = _lastActiveWorkoutId;
    _lastActiveWorkoutId = null;
    if (finishedId == null) return;

    final idx = widget.workouts.indexWhere((w) => w.id == finishedId);
    if (idx < 0 || widget.workouts.length < 2) return;

    _scrollTo(idx);
    _postFinishHold?.cancel();
    _postFinishHold = Timer(_completedHold, () {
      if (!mounted) return;
      final localCompletions = Map<String, WorkoutCompletion>.from(
        widget.completions,
      )..putIfAbsent(
          finishedId,
          () => WorkoutCompletion(
            workoutId: finishedId,
            completedAt: DateTime.now(),
            durationSeconds: 0,
          ),
        );
      final nextIdx = nextNotCompletedIndex(
        workouts: widget.workouts,
        fromIndex: idx,
        completions: localCompletions,
        now: DateTime.now(),
      );
      if (nextIdx == null || nextIdx == idx) return;
      _scrollTo(nextIdx);
    });
  }

  /// Width of one carousel slot, including the trailing 16-px gap
  /// between cards. Must match the ListView.builder's `itemExtent` so
  /// `index * _slotWidth` lines a card up at the leading edge.
  double _slotWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.80;

  void _scrollTo(int index, {bool animate = true}) {
    if (!mounted) return;
    final offset = index * _slotWidth(context);
    void run() {
      if (!mounted || !_ctrl.hasClients) return;
      final clamped = offset.clamp(
        _ctrl.position.minScrollExtent,
        _ctrl.position.maxScrollExtent,
      );
      if (animate) {
        _ctrl.animateTo(
          clamped,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      } else {
        _ctrl.jumpTo(clamped);
      }
    }

    if (_ctrl.hasClients) {
      run();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    }
  }

  @override
  void dispose() {
    _tabIndex?.removeListener(_onTabChanged);
    _sub?.cancel();
    _postFinishHold?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final now = DateTime.now();

    return SizedBox(
      height: 220,
      child: ListView.builder(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.workouts.length,
        physics: const BouncingScrollPhysics(),
        itemExtent: screenWidth * 0.80,
        itemBuilder: (context, index) {
          final workout = widget.workouts[index];
          final completion = widget.completions[workout.id];
          final completionThisWeek =
              (completion != null && isInSameWeek(completion.completedAt, now))
                  ? completion
                  : null;
          return Padding(
            padding: EdgeInsets.only(
              right: index < widget.workouts.length - 1 ? 16 : 0,
            ),
            child: WorkoutCard(
              workout: workout,
              completionThisWeek: completionThisWeek,
            ),
          );
        },
      ),
    );
  }
}
