import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../theme/app_theme.dart';
import '../screens/workout_detail/workout_detail_screen.dart';

class WorkoutCard extends StatefulWidget {
  final Workout workout;

  const WorkoutCard({
    super.key,
    required this.workout,
  });

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Color _getRecoveryColor() {
    switch (widget.workout.recoveryInfo.status) {
      case RecoveryStatus.ready:
        return AppTheme.recoveryGreen;
      case RecoveryStatus.almostReady:
        return AppTheme.recoveryYellow;
      case RecoveryStatus.notReady:
        return AppTheme.recoveryRed;
    }
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  void _onTap() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WorkoutDetailScreen(workout: widget.workout),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.05, 0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: offsetAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recoveryColor = _getRecoveryColor();

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryOrange, width: 2),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.workout.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                widget.workout.subtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.workout.duration} - ${widget.workout.exerciseCount} exercises',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: recoveryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: recoveryColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: recoveryColor.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.workout.recoveryInfo.statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: recoveryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.workout.recoveryInfo.description,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ),
                    Text(
                      '${widget.workout.recoveryInfo.percentage.toInt()}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: recoveryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
