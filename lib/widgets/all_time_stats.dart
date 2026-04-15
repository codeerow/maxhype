import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/all_time_stats.dart';

class AllTimeStatsWidget extends StatelessWidget {
  final AllTimeStats stats;

  const AllTimeStatsWidget({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALL-TIME STATS',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 20),
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  label: 'Total Workouts',
                  value: stats.totalWorkouts.toString(),
                  icon: Icons.fitness_center,
                  color: AppTheme.primaryOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  label: 'Total KCAL',
                  value: _formatNumber(stats.totalKcal),
                  icon: Icons.local_fire_department,
                  color: AppTheme.recoveryRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  label: 'Total Volume',
                  value: '${_formatNumber(stats.totalVolume / 1000)}k',
                  icon: Icons.trending_up,
                  color: AppTheme.recoveryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  label: 'Current Streak',
                  value: '${stats.currentStreak} days',
                  icon: Icons.whatshot,
                  color: AppTheme.recoveryYellow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    } else {
      return number.toStringAsFixed(0);
    }
  }
}
