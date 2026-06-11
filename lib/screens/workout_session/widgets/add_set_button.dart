import 'package:flutter/material.dart';

import '../../../models/session/session_set.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// "Add Set" composite control. Default state shows just the dashed
/// `+ Add Set` row. Tapping it expands a temporary inline selector
/// above the button with three pills — Set (green), Warm-Up (yellow),
/// Drop Set (orange). The user picks a type, then taps `+ Add Set`
/// again to commit; that commit collapses the selector back. A tap
/// anywhere outside the control also collapses it.
///
/// Customer brief (M5 follow-up clarification on item 4): the pills
/// must be a temporary inline expansion, not a permanent row. No
/// iOS/Cupertino action sheet.
class AddSetButton extends StatefulWidget {
  final ValueChanged<SetKind> onAddSet;

  const AddSetButton({
    super.key,
    required this.onAddSet,
  });

  @override
  State<AddSetButton> createState() => _AddSetButtonState();
}

class _AddSetButtonState extends State<AddSetButton> {
  /// Whether the inline selector is currently shown. Toggled by the
  /// Add Set button itself (first tap opens; second tap commits and
  /// closes) and by a tap-outside region listener.
  bool _expanded = false;

  /// Last picked type. Survives a collapse so re-opening the selector
  /// shows the user's previous choice — a small quality-of-life nudge
  /// that doesn't violate the "default state is just Add Set" rule.
  SetKind _selectedKind = SetKind.effective;

  void _selectKind(SetKind kind) {
    if (_selectedKind == kind) return;
    setState(() => _selectedKind = kind);
  }

  void _handleAddSetTap() {
    if (!_expanded) {
      setState(() => _expanded = true);
      return;
    }
    widget.onAddSet(_selectedKind);
    setState(() => _expanded = false);
  }

  void _handleTapOutside() {
    if (!_expanded) return;
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => _handleTapOutside(),
      child: Column(
        children: [
          // Inline selector — animated in/out so the expansion reads
          // as a single fluid gesture rather than a hard pop.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _KindPill(
                          label: 'Set',
                          dotColor: AppTheme.recoveryGreen,
                          isSelected: _selectedKind == SetKind.effective,
                          onTap: () => _selectKind(SetKind.effective),
                        ),
                        const SizedBox(width: 8),
                        _KindPill(
                          label: 'Warm-Up',
                          dotColor: AppTheme.recoveryYellow,
                          isSelected: _selectedKind == SetKind.warmup,
                          onTap: () => _selectKind(SetKind.warmup),
                        ),
                        const SizedBox(width: 8),
                        _KindPill(
                          label: 'Drop Set',
                          dotColor: AppTheme.primaryOrange,
                          isSelected: _selectedKind == SetKind.dropSet,
                          onTap: () => _selectKind(SetKind.dropSet),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
          TapScale(
            scaleDown: TapScalePreset.surface.scale,
            onTap: _handleAddSetTap,
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: AppTheme.primaryOrange.withValues(alpha: 0.55),
                strokeWidth: 1,
                radius: 22,
                dashLength: 5,
                gapLength: 4,
              ),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Add Set',
                      style: TextStyle(
                        color: AppTheme.primaryOrange,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small capsule with a coloured dot + label, shown in the temporary
/// selector above Add Set. Selected state gets the orange border +
/// soft glow.
class _KindPill extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _KindPill({
    required this.label,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppTheme.primaryOrange
        : Colors.white.withValues(alpha: 0.10);
    return TapScale(
      scaleDown: TapScalePreset.cta.scale,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    final stride = dashLength + gapLength;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += stride;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}
