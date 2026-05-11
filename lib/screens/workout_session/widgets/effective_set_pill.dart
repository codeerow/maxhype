import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// Visual state of an effective-set pill.
///  * [logged] — solid green fill, dark bold value (a finished set).
///  * [draft]  — light fill, dark bold value (the row currently being typed).
///  * [empty]  — dark card fill, muted value (placeholder pre-fill).
///  * [pr]     — solid orange fill, dark bold value (a personal record).
enum PillState { empty, draft, logged, pr }

/// Background + foreground pair for a [PillState]. Shared between the
/// static [EffectiveSetPill] and the editable text-field pill in
/// `effective_set_row.dart` so they stay visually in sync.
class PillColors {
  final Color background;
  final Color foreground;
  const PillColors({required this.background, required this.foreground});
}

PillColors pillColorsFor(PillState state) {
  switch (state) {
    case PillState.logged:
      return const PillColors(
        background: AppTheme.recoveryGreen,
        foreground: Color(0xFF062716),
      );
    case PillState.draft:
      return const PillColors(
        background: Color(0xFFE6E8EE),
        foreground: Color(0xFF0A0E27),
      );
    case PillState.empty:
      return const PillColors(
        background: AppTheme.cardBackground,
        foreground: AppTheme.textSecondary,
      );
    case PillState.pr:
      return const PillColors(
        background: AppTheme.primaryOrange,
        foreground: Color(0xFF2A1500),
      );
  }
}

/// One cell in the SET / REPS / WEIGHT row. Static — no input. The editable
/// pill lives in `effective_set_row.dart` and uses the same [pillColorsFor].
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
    final colors = pillColorsFor(state);
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
}
