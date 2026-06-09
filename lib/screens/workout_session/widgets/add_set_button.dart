import 'package:flutter/material.dart';

import '../../../models/session/session_set.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// "Add Set" composite control — an inline type selector (Set / Warm-Up /
/// Drop Set pills with coloured dots) sitting above the dashed Add Set
/// pill. The selector is always visible: tapping a pill picks the type
/// the next Add Set tap will append. Selection persists between adds so
/// the user can fire multiple drop sets in a row without re-selecting.
///
/// Replaces the previous CupertinoActionSheet flow (milestone Phase 3
/// Part 3, Item 8 — customer asked for the inline MaxHype-web variant).
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
  /// Current type the Add Set button will append. Lives across multiple
  /// taps so the user doesn't have to re-pick after every add.
  SetKind _selectedKind = SetKind.effective;

  void _select(SetKind kind) {
    if (_selectedKind == kind) return;
    setState(() => _selectedKind = kind);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _KindPill(
              label: 'Set',
              dotColor: AppTheme.recoveryGreen,
              isSelected: _selectedKind == SetKind.effective,
              onTap: () => _select(SetKind.effective),
            ),
            const SizedBox(width: 8),
            _KindPill(
              label: 'Warm-Up',
              dotColor: AppTheme.recoveryYellow,
              isSelected: _selectedKind == SetKind.warmup,
              onTap: () => _select(SetKind.warmup),
            ),
            const SizedBox(width: 8),
            _KindPill(
              label: 'Drop Set',
              dotColor: AppTheme.primaryOrange,
              isSelected: _selectedKind == SetKind.dropSet,
              onTap: () => _select(SetKind.dropSet),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TapScale(
          scaleDown: 0.97,
          onTap: () => widget.onAddSet(_selectedKind),
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
    );
  }
}

/// Small capsule with a coloured dot + label, used in the row above
/// Add Set. Selected state gets the orange border + soft glow.
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
      scaleDown: 0.95,
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
