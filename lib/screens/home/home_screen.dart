import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/workout_cards_scroll.dart';
import '../../widgets/all_time_stats.dart';
import '../../core/bloc_factory.dart';
import 'bloc/home_bloc.dart';
import 'bloc/home_event.dart';
import 'bloc/home_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        const event = HomeInitial();
        return context.read<BlocFactory>().create<HomeBloc>()..add(event);
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
            HomeSuccess(:final workouts, :final monthlyData, :final allTimeStats) => Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: AppHeader(),
                        ),
                        const SizedBox(height: 32),
                        WorkoutCardsScroll(workouts: workouts),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: AllTimeStatsWidget(stats: allTimeStats),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
          };
        },
      ),
    );
  }
}
