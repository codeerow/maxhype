import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Large green M:SS counter at the top of the session main screen.
///
/// Source of truth is `startedAt`; we recompute elapsed against wall-clock
/// every second so backgrounding/resume is transparent.
class PersistentWorkoutTimer extends StatefulWidget {
  final DateTime startedAt;
  final double fontSize;

  const PersistentWorkoutTimer({
    super.key,
    required this.startedAt,
    this.fontSize = 36,
  });

  @override
  State<PersistentWorkoutTimer> createState() => _PersistentWorkoutTimerState();
}

class _PersistentWorkoutTimerState extends State<PersistentWorkoutTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final mins = total ~/ 60;
    final secs = total % 60;
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final remMins = mins % 60;
      return '$hrs:${remMins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    return Center(
      child: Text(
        _format(elapsed),
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w700,
          color: AppTheme.recoveryGreen,
          letterSpacing: 1.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
