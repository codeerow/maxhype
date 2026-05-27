import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../theme/app_theme.dart';
import 'tap_scale.dart';

/// Floating iOS-style nav bar with a real liquid-glass blur.
///
/// Architecture mirrors the package's own sample `LiquidGlassBottomBar`:
/// the [LiquidGlassLayer] wraps **only** the bar itself, not the screen
/// body. The shader reads the backdrop directly from the framebuffer
/// (what was already painted under the bar's rect), so the bar must be
/// positioned over the body via a Stack — never wrapped around it.
///
/// Usage:
///
///   Scaffold(
///     body: Stack(
///       children: [
///         yourScrollableBody,
///         const Positioned(
///           top: 0, left: 0, right: 0,
///           child: LiquidGlassNavBar(title: Text('Sunday'), ...),
///         ),
///       ],
///     ),
///   )
class LiquidGlassNavBar extends StatelessWidget {
  final Widget? title;
  final IconData? backIcon;
  final VoidCallback? onBack;
  final List<LiquidGlassNavAction> actions;

  const LiquidGlassNavBar({
    super.key,
    this.title,
    this.backIcon,
    this.onBack,
    this.actions = const [],
  });

  static const double pillSize = 44;

  /// Total height the bar occupies including the status bar. Useful for
  /// scrollable padding-top calculations.
  static double heightWith(BuildContext context) =>
      MediaQuery.of(context).padding.top + kToolbarHeight;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return LiquidGlassLayer(
      // Matches the basic_app sample's tuned settings — a thicker pane
      // with mild aberration, low-alpha tint so refracted content is
      // actually visible underneath.
      settings: const LiquidGlassSettings(
        // Calibrated against the reference shot. Visible bending of
        // letters at the pill edge, but the body of the letter remains
        // readable through the centre. No artificial highlight rim, no
        // milky frost.
        thickness: 20,
        blur: 3.5,
        chromaticAberration: 0.04,
        refractiveIndex: 1.32,
        lightIntensity: 0.25,
        ambientStrength: 0.40,
        saturation: 1.15,
        // Cool neutral tint at low alpha so the pill reads as "cold
        // glass" instead of inheriting the dark-blue background.
        glassColor: Color.fromARGB(20, 200, 215, 240),
      ),
      child: LiquidGlassBlendGroup(
        blend: 10,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 6),
          child: SizedBox(
            height: kToolbarHeight - 12,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (title != null)
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    child: title!,
                  ),
                if (onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _GlassPill(
                      onTap: onBack!,
                      child: Icon(
                        backIcon ?? Icons.arrow_back,
                        color: AppTheme.primaryOrange,
                        size: 22,
                      ),
                    ),
                  ),
                if (actions.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final a in actions) ...[
                          _GlassPill(
                            onTap: a.onTap,
                            child: Icon(
                              a.icon,
                              color: a.iconColor ?? AppTheme.textPrimary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassNavAction {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const LiquidGlassNavAction({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GlassPill({required this.child, required this.onTap});

  static const _shadows = [
    BoxShadow(
      blurStyle: BlurStyle.outer,
      color: Color.fromARGB(13, 0, 0, 0),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      blurStyle: BlurStyle.outer,
      color: Color.fromARGB(25, 0, 0, 0),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scaleDown: 0.92,
      onTap: onTap,
      child: LiquidGlass.grouped(
        shape: const LiquidOval(),
        shadows: _shadows,
        child: SizedBox(
          width: LiquidGlassNavBar.pillSize,
          height: LiquidGlassNavBar.pillSize,
          child: Center(child: child),
        ),
      ),
    );
  }
}
