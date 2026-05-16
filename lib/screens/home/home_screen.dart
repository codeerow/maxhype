import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/app_header.dart';
import '../../widgets/workout_cards_scroll.dart';
import '../../widgets/all_time_charts.dart';
import '../../core/bloc_factory.dart';
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
            HomeSuccess(:final workouts, :final monthlyData) => Scaffold(
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
                        WorkoutCardsScroll(workouts: workouts),
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
    );
  }
}
