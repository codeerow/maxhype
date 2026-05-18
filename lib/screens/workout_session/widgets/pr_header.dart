import 'package:flutter/material.dart';

import '../../../models/session/personal_record.dart';
import '../../../theme/app_theme.dart';

/// Premium PR banner shown above the action chips on the logging screen.
///
/// Layout:
///   ┌──────────────────────────────┐
///   │  🔥  PERSONAL RECORD  🔥     │   ← orange filled pill
///   └──────────────────────────────┘
///         180 lb × 7                ← big bold value
///   Previous Best: 160 lb × 9       ← muted, hidden when no prior
///
/// During the session, after a fresh PR is set, the previous best
/// snapshot is rendered under the value as "Previous Best", and the
/// title line above the value reads "New Best" instead of the current
/// value alone — driven by [isFresh].
class PrHeader extends StatelessWidget {
  final PersonalRecord pr;
  final PersonalRecord? previousBest;

  /// True when the PR was set during this session (drives the "New Best"
  /// wording and a brighter glow). False = persistent header showing
  /// the user's all-time best at session start.
  final bool isFresh;

  const PrHeader({
    super.key,
    required this.pr,
    this.previousBest,
    this.isFresh = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Pill(),
          const SizedBox(height: 8),
          Text(
            '${_formatWeight(pr.weight)} lb × ${pr.reps}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          if (previousBest != null) ...[
            const SizedBox(height: 4),
            Text(
              isFresh
                  ? 'Previous Best: ${_formatWeight(previousBest!.weight)} lb × ${previousBest!.reps}'
                  : 'Last session: ${_formatWeight(previousBest!.weight)} lb × ${previousBest!.reps}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatWeight(double w) {
    if (w == w.truncate()) return w.toInt().toString();
    return w.toStringAsFixed(1);
  }
}

class _Pill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
          Text(
            'PERSONAL RECORD',
            style: TextStyle(
              color: AppTheme.primaryOrange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          SizedBox(width: 8),
          Text('🔥', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
