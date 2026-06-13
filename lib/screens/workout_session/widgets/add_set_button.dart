import 'package:flutter/material.dart';

import '../../../models/session/session_set.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// "Add Set" composite control. Default state shows just the dashed
/// `+ Add Set` row. Tapping it opens a dropdown anchored to the button
/// with three pills — Set (green), Warm-Up (yellow), Drop Set (orange).
/// Tapping a pill commits a row of that type and closes the dropdown.
/// Tapping anywhere outside the dropdown closes it without committing.
///
/// Customer brief (M5 follow-up clarification on item 4): the type
/// picker should be a temporary dropdown anchored to the Add Set
/// button, not a permanent inline row. No iOS/Cupertino action sheet.
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
  /// Anchor key on the Add Set button — used to read the button's
  /// global rect when opening the dropdown so we can position it
  /// directly above the button regardless of where it sits in the
  /// scroll viewport.
  final GlobalKey _buttonKey = GlobalKey();
  final OverlayPortalController _portal = OverlayPortalController();

  /// Cached anchor rect for the open dropdown. Captured at show()
  /// time; if the user scrolls we close the popup anyway, so a static
  /// snapshot is fine.
  Rect? _anchorRect;

  /// ScrollPosition we're subscribed to while the dropdown is open.
  /// Cleared on hide so we don't keep callbacks alive on stale
  /// positions when the surrounding ListView swaps in/out.
  ScrollPosition? _watchedScroll;

  void _toggleDropdown() {
    if (_portal.isShowing) {
      _hide();
    } else {
      _show();
    }
  }

  void _show() {
    final box =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);
    _anchorRect = topLeft & box.size;
    _portal.show();
    // Watch the ancestor scroll position so a drag-to-scroll closes
    // the popup the moment the user starts moving the list.
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != null) {
      _watchedScroll = pos..addListener(_onScroll);
    }
  }

  void _hide() {
    _portal.hide();
    _watchedScroll?.removeListener(_onScroll);
    _watchedScroll = null;
  }

  void _onScroll() {
    if (_portal.isShowing) _hide();
  }

  void _commit(SetKind kind) {
    _hide();
    widget.onAddSet(kind);
  }

  @override
  void dispose() {
    _watchedScroll?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayContext) {
        final rect = _anchorRect;
        if (rect == null) return const SizedBox.shrink();
        // Anchor the dropdown directly above the captured button rect.
        // Bottom of the dropdown = top of the button - 8px gap. We
        // also pin its horizontal centre to the button's centre so it
        // stays visually attached even on narrow screens.
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(overlayContext).size.height -
                  rect.top +
                  8,
              child: Center(
                // TapRegion observes outside taps without absorbing
                // them, so the underlying ListView still receives
                // scroll drags. Pointer-down outside the pills →
                // close. Pointer-down on a pill → its tap handler
                // runs (TapRegion does not interfere with descendants).
                child: TapRegion(
                  onTapOutside: (_) => _portal.hide(),
                  child: _Dropdown(onPick: _commit),
                ),
              ),
            ),
          ],
        );
      },
      child: TapScale(
        key: _buttonKey,
        scaleDown: TapScalePreset.surface.scale,
        onTap: _toggleDropdown,
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
}

/// Floating pill row shown above the Add Set button.
class _Dropdown extends StatefulWidget {
  final ValueChanged<SetKind> onPick;

  const _Dropdown({required this.onPick});

  @override
  State<_Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<_Dropdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The popup is a Material island so any ripple / theming defaults
    // resolve cleanly — without it pills outside the main Scaffold
    // would assert about a missing Material ancestor.
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          return Opacity(
            opacity: _t.value,
            child: Transform.translate(
              offset: Offset(0, 6 * (1 - _t.value)),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _KindPill(
                label: 'Set',
                dotColor: AppTheme.recoveryGreen,
                onTap: () => widget.onPick(SetKind.effective),
              ),
              const SizedBox(width: 8),
              _KindPill(
                label: 'Warm-Up',
                dotColor: AppTheme.recoveryYellow,
                onTap: () => widget.onPick(SetKind.warmup),
              ),
              const SizedBox(width: 8),
              _KindPill(
                label: 'Drop Set',
                dotColor: AppTheme.primaryOrange,
                onTap: () => widget.onPick(SetKind.dropSet),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small capsule with a coloured dot + label, shown in the floating
/// dropdown above Add Set. Press feedback adds an orange outline +
/// glow while the finger is held down so the user sees a clear
/// "this is what's about to commit" preview before lifting off.
class _KindPill extends StatefulWidget {
  final String label;
  final Color dotColor;
  final VoidCallback onTap;

  const _KindPill({
    required this.label,
    required this.dotColor,
    required this.onTap,
  });

  @override
  State<_KindPill> createState() => _KindPillState();
}

class _KindPillState extends State<_KindPill> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    const orange = AppTheme.primaryOrange;
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: TapScale(
        scaleDown: TapScalePreset.cta.scale,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pressed
                  ? orange
                  : Colors.white.withValues(alpha: 0.10),
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: [
              if (_pressed)
                BoxShadow(
                  color: orange.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 0.5,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
