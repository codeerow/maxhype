import 'package:flutter/material.dart';
import '../models/workout.dart';
import 'workout_card.dart';

class WorkoutCardsScroll extends StatefulWidget {
  final List<Workout> workouts;

  const WorkoutCardsScroll({
    super.key,
    required this.workouts,
  });

  @override
  State<WorkoutCardsScroll> createState() => _WorkoutCardsScrollState();
}

class _WorkoutCardsScrollState extends State<WorkoutCardsScroll> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // viewportFraction < 1.0 allows partial visibility of adjacent cards
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: 0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.workouts.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: WorkoutCard(
              workout: widget.workouts[index],
              isActive: index == _currentPage,
            ),
          );
        },
      ),
    );
  }
}
