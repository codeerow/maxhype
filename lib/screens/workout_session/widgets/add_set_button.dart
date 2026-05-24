import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// Round "+" icon followed by an "Add Set" label in the accent colour.
///
/// Tap = +1 set. Long-press opens a Cupertino picker for adding multiple
/// sets at once (3 / 5 / 10).
class AddSetButton extends StatelessWidget {
  final VoidCallback onAddOne;
  final ValueChanged<int> onAddMany;

  const AddSetButton({
    super.key,
    required this.onAddOne,
    required this.onAddMany,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showPicker(context),
      child: TapScale(
        scaleDown: 0.97,
        onTap: onAddOne,
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
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Add multiple sets'),
        actions: [
          for (final count in const [3, 5, 10])
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                onAddMany(count);
              },
              child: Text('Add $count sets'),
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
