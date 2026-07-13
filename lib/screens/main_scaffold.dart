import 'package:flutter/material.dart';
import '../core/haptic_manager.dart';
import '../core/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../widgets/workout_in_progress_bar.dart';
import 'home/home_screen.dart';
import 'history/history_screen.dart';
import 'plan/plan_screen.dart';
import 'home_tab_visibility.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  late final ValueNotifier<int> _tabIndex = ValueNotifier<int>(_currentIndex);

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    PlanScreen(),
  ];

  @override
  void dispose() {
    _tabIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: HomeTabVisibility(
        notifier: _tabIndex,
        child: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: WorkoutInProgressBar(),
          ),
        ],
      ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'History',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.tune_rounded,
                  label: 'Plan',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return TapScale(
      scaleDown: TapScalePreset.cta.scale,
      onTap: () {
        if (_currentIndex != index) {
          getIt<HapticManager>().selection();
          setState(() {
            _currentIndex = index;
          });
          _tabIndex.value = index;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryOrange.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedScale(
          scale: isActive ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Row(
            children: [
              Icon(
                icon,
                color:
                    isActive ? AppTheme.primaryOrange : AppTheme.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isActive
                      ? AppTheme.primaryOrange
                      : AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
