import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// One cell in the SET / REPS / WEIGHT row.
///
/// Tristate visual:
///  * [PillState.logged] — solid green fill, dark bold value
///  * [PillState.draft]  — light fill, dark bold value (the "currently
///    editable" feel from the design ref)
///  * [PillState.empty]  — dark fill, muted value (placeholder pre-fill)
enum PillState { empty, draft, logged }

class EffectiveSetPill extends StatelessWidget {
  final String text;
  final PillState state;

  /// Custom child overrides [text] (used for the SET column to render a
  /// checkmark icon when logged).
  final Widget? child;

  /// Fixed width (e.g., narrow SET column). When null, the pill expands.
  final double? width;
  final double height;
  final VoidCallback? onTap;

  const EffectiveSetPill({
    super.key,
    this.text = '',
    this.state = PillState.empty,
    this.child,
    this.width,
    this.height = 50,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(state);
    final pill = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child ??
          Text(
            text,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
    );

    if (onTap == null) return pill;
    return TapScale(scaleDown: 0.96, onTap: onTap, child: pill);
  }

  _PillColors _colorsFor(PillState s) {
    switch (s) {
      case PillState.logged:
        return _PillColors(
          background: AppTheme.recoveryGreen,
          foreground: const Color(0xFF062716),
        );
      case PillState.draft:
        return _PillColors(
          background: const Color(0xFFE6E8EE),
          foreground: const Color(0xFF0A0E27),
        );
      case PillState.empty:
        return _PillColors(
          background: AppTheme.cardBackground,
          foreground: AppTheme.textSecondary,
        );
    }
  }
}

class _PillColors {
  final Color background;
  final Color foreground;
  const _PillColors({required this.background, required this.foreground});
}
