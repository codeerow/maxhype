import 'package:flutter/material.dart';
import '../models/workout.dart';
import 'workout_card.dart';

class WorkoutCardsScroll extends StatelessWidget {
  final List<Workout> workouts;

  const WorkoutCardsScroll({
    super.key,
    required this.workouts,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: workouts.length,
        physics: const BouncingScrollPhysics(),
        itemExtent: screenWidth * 0.80,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index < workouts.length - 1 ? 16 : 0,
            ),
            child: WorkoutCard(
              workout: workouts[index],
              isActive: index == 0,
            ),
          );
        },
      ),
    );
  }
}
