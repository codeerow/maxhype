import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/tap_scale.dart';

/// Full-screen duration picker: a horizontal segmented control of the supported
/// durations (45…120) inside a rounded track, with the selected value outlined
/// in orange and a "Selected: N min" caption underneath. Distinct from the
/// generic list-style `PlanOptionScreen` — durations are few, fixed, and read
/// best as a single-row segmented picker.
///
/// The pick is applied on *exit*, not on tap: tapping a segment only moves the
/// highlight, so the user can try values freely without triggering a plan save
/// + workout regeneration each time. When the screen is dismissed (back arrow
/// or system back) it pops with the final selection — or `null` if it never
/// changed, so the caller skips the (expensive) regenerate when nothing moved.
class WorkoutDurationScreen extends StatefulWidget {
  const WorkoutDurationScreen({
    required this.options,
    required this.selected,
    super.key,
  });

  /// The selectable durations in minutes, in display order.
  final List<int> options;

  /// The duration in minutes selected when the screen opened.
  final int selected;

  /// Pushes the picker and resolves to the chosen duration on exit, or `null`
  /// if the user backed out without changing the selection.
  static Future<int?> show(
    BuildContext context, {
    required List<int> options,
    required int selected,
  }) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => WorkoutDurationScreen(
          options: options,
          selected: selected,
        ),
      ),
    );
  }

  @override
  State<WorkoutDurationScreen> createState() => _WorkoutDurationScreenState();
}

class _WorkoutDurationScreenState extends State<WorkoutDurationScreen> {
  late int _selected = widget.selected;

  /// The value to hand back on exit: the new pick, or `null` when unchanged so
  /// the caller doesn't save/regenerate for a no-op.
  int? get _result => _selected == widget.selected ? null : _selected;

  void _select(int minutes) {
    if (minutes == _selected) return;
    setState(() => _selected = minutes);
  }

  @override
  Widget build(BuildContext context) {
    // Own the pop so both the back arrow and the system back gesture return the
    // final selection instead of a bare `null`.
    return PopScope<int?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_result);
      },
      child: Scaffold(
        backgroundColor: AppTheme.planBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(context),
                const SizedBox(height: 32),
                _segmentTrack(context),
                const SizedBox(height: 20),
                Text(
                  'Selected: $_selected min',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Back arrow on the left with the screen title centered over the full width,
  /// matching the screenshot (the title is centered, not left-aligned).
  Widget _topBar(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const Text(
        'Workout Duration',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TapScale.preset(
          preset: TapScalePreset.icon,
          enableHaptic: true,
          onTap: () => Navigator.of(context).pop(_result),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0x0DFFFFFF), // white @ 5%
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back,
              color: AppTheme.planBackArrow,
              size: 20,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _segmentTrack(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.planCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.planCardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _segment(context, widget.options[i])),
          ],
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, int minutes) {
    final isSelected = minutes == _selected;
    return TapScale.preset(
      preset: TapScalePreset.surface,
      enableHaptic: true,
      onTap: () => _select(minutes),
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF181C2D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryOrange
                : const Color(0x14FFFFFF),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          '$minutes',
          style: TextStyle(
            color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
