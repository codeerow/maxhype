import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../models/session/session_set.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// "Add Set" pill that opens a Cupertino action sheet with three options:
/// Set / Warm-Up / Drop Set, matching the MaxHype web prototype's
/// set-type pattern (milestone Phase 3 Part 3, Item 8).
///
/// Tap → action sheet → [onAddSet] called with the chosen [SetKind].
class AddSetButton extends StatelessWidget {
  final ValueChanged<SetKind> onAddSet;

  const AddSetButton({
    super.key,
    required this.onAddSet,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scaleDown: 0.97,
      onTap: () => _showKindSheet(context),
      // Edge-to-edge outlined pill, ~44 tall — sits across the full
      // width of the row beneath the last effective set.
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
    );
  }

  void _showKindSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Add Set'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAddSet(SetKind.effective);
            },
            child: const Text('Set'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAddSet(SetKind.warmup);
            },
            child: const Text('Warm-Up'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAddSet(SetKind.dropSet);
            },
            child: const Text('Drop Set'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
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
