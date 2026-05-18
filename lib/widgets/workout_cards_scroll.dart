import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/workout.dart';
import '../screens/workout_session/bloc/workout_session_bloc.dart';
import '../screens/workout_session/bloc/workout_session_state.dart';
import 'workout_card.dart';

/// Horizontal scroller of workout cards on the Home screen.
///
/// Listens for the active workout finishing (state transition
/// `SessionActive → !SessionActive`) and animates to the next workout
/// card. "Next" is the card after the just-finished one in the list,
/// wrapping back to the first when the finished card was last.
class WorkoutCardsScroll extends StatefulWidget {
  final List<Workout> workouts;

  const WorkoutCardsScroll({super.key, required this.workouts});

  @override
  State<WorkoutCardsScroll> createState() => _WorkoutCardsScrollState();
}

class _WorkoutCardsScrollState extends State<WorkoutCardsScroll> {
  final ScrollController _ctrl = ScrollController();
  String? _lastActiveWorkoutId;
  StreamSubscription<WorkoutSessionState>? _sub;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<WorkoutSessionBloc>();
    final cur = bloc.state;
    if (cur is SessionActive) _lastActiveWorkoutId = cur.session.workoutId;
    _sub = bloc.stream.listen(_onState);
  }

  void _onState(WorkoutSessionState state) {
    if (state is SessionActive) {
      _lastActiveWorkoutId = state.session.workoutId;
      return;
    }
    // Just transitioned away from SessionActive — figure out which card to
    // bring into view next.
    final finishedId = _lastActiveWorkoutId;
    _lastActiveWorkoutId = null;
    if (finishedId == null) return;
    final idx = widget.workouts.indexWhere((w) => w.id == finishedId);
    if (idx < 0 || widget.workouts.length < 2) return;
    final nextIdx = (idx + 1) % widget.workouts.length;
    _scrollTo(nextIdx);
  }

  void _scrollTo(int index) {
    if (!_ctrl.hasClients) return;
    final width = MediaQuery.of(context).size.width;
    final itemExtent = width * 0.80 + 16; // matches itemExtent + spacing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ctrl.hasClients) return;
      _ctrl.animateTo(
        index * itemExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
          return Padding(
            padding: EdgeInsets.only(
              right: index < widget.workouts.length - 1 ? 16 : 0,
            ),
            child: WorkoutCard(workout: widget.workouts[index]),
          );
        },
      ),
    );
  }
}
