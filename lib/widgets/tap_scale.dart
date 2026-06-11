import 'package:flutter/material.dart';
import '../core/haptic_manager.dart';
import '../core/service_locator.dart';

/// Press-feedback intensity for [TapScale]. The four-tier scale keeps
/// the app's tactile language consistent — a reader can tell exactly
/// what kind of control a widget is by how strongly it presses.
///
/// Customer brief: normal buttons, cards, and rows must press in the
/// 0.96–0.97 range so the app feels uniformly premium. Anything
/// outside that range must be a deliberate exception with a reason
/// the user can feel (an icon too small to register a soft press; a
/// CTA whose weight justifies a slightly stronger commit).
///
/// Pick by *what kind of control the widget is*, not by how strong
/// you want the press to feel. The whole point of the enum is to
/// take that decision off the call-site.
enum TapScalePreset {
  /// Large interactive surface — cards, list rows, sticky bottom CTAs,
  /// dashed Add Set / Add Exercise pills, the in-progress bar, action
  /// chips, value-input pills. The default for any "normal button /
  /// card / row" per the customer brief. **scaleDown = 0.97.**
  surface(0.97),

  /// Primary commit / destructive CTAs and the bottom navigation tab.
  /// Slightly stronger press conveys the weight of the action without
  /// breaking the premium 0.96–0.97 corridor. Use for Start Workout,
  /// Finish, Log Set / Done, the home tab row. **scaleDown = 0.96.**
  cta(0.96),

  /// Bare-icon hit targets — back arrow, close ✕, 3-dot menus,
  /// timer-cancel, sheet-close. Targets are typically 24–36 px; the
  /// 0.97 baseline is imperceptible at that size, so icons get a
  /// stronger 0.90 to confirm the tap registered. Reserved for
  /// icon-only controls. **scaleDown = 0.90.**
  icon(0.90),

  /// Glass-style oval icon pill (~44 px) on the LiquidGlassNavBar.
  /// Halfway between `icon` and the surface tier because it's still
  /// icon-driven but with a larger hit area. **scaleDown = 0.92.**
  glassIcon(0.92);

  final double scale;
  const TapScalePreset(this.scale);
}

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final double opacityDown;
  final Duration pressDownDuration;
  final Duration releaseUpDuration;
  final bool enableHaptic;

  /// Default constructor. When [scaleDown] is omitted it falls back to
  /// [TapScalePreset.surface] (0.97) — the "normal button/card/row"
  /// tier. New call-sites should prefer named values from
  /// [TapScalePreset] over raw doubles so the press-feedback tier is
  /// self-documenting.
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
    this.opacityDown = 0.92,
    this.pressDownDuration = const Duration(milliseconds: 80),
    this.releaseUpDuration = const Duration(milliseconds: 120),
    this.enableHaptic = false,
  });

  /// Preferred constructor — picks the scale value from [preset] so
  /// every call-site states *what kind of control it is* instead of a
  /// raw number. New code should always use this form; the raw
  /// `scaleDown:` parameter is kept only for the rare custom case.
  TapScale.preset({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    required TapScalePreset preset,
    double opacityDown = 0.92,
    Duration pressDownDuration = const Duration(milliseconds: 80),
    Duration releaseUpDuration = const Duration(milliseconds: 120),
    bool enableHaptic = false,
  }) : this(
          key: key,
          child: child,
          onTap: onTap,
          scaleDown: preset.scale,
          opacityDown: opacityDown,
          pressDownDuration: pressDownDuration,
          releaseUpDuration: releaseUpDuration,
          enableHaptic: enableHaptic,
        );

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDownDuration,
      reverseDuration: widget.releaseUpDuration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacityAnimation =
        Tween<double>(begin: 1.0, end: widget.opacityDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _onTap() {
    if (widget.enableHaptic) {
      getIt<HapticManager>().light();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null ? _onTap : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
