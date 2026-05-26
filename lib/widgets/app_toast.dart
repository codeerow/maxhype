import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight bottom banner used in place of Material SnackBar.
///
/// `AppToast.show(context, 'message')` overlays a pill at the bottom of
/// the screen for a couple of seconds. No haptic, no actions — purely
/// informational. The premium variant uses a solid orange bubble with
/// black text and is reserved for workout-flow feedback (completed,
/// cancelled, validation). For destructive confirmations use a
/// CupertinoAlertDialog.
class AppToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 1800),
    Color? accent,
  }) =>
      _present(
        context,
        message: message,
        duration: duration,
        accent: accent,
        premium: false,
      );

  /// Larger, glow-y variant used for celebratory moments
  /// (workout completed). Wider bubble, longer hold, accent halo.
  static void showPremium(
    BuildContext context,
    String message, {
    String? icon,
    Color? accent,
    Duration duration = const Duration(milliseconds: 2500),
  }) =>
      _present(
        context,
        message: message,
        duration: duration,
        accent: accent,
        icon: icon,
        premium: true,
      );

  static void _present(
    BuildContext context, {
    required String message,
    required Duration duration,
    required bool premium,
    Color? accent,
    String? icon,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _insert(overlay,
        message: message,
        duration: duration,
        premium: premium,
        accent: accent,
        icon: icon);
  }

  /// Variant used when the caller has an [OverlayState] directly — needed
  /// when showing a toast right after popUntil(rootNavigator), where the
  /// root Navigator's `context` is *above* the overlay, so `Overlay.of`
  /// returns null.
  static void showPremiumOnOverlay(
    OverlayState overlay,
    String message, {
    String? icon,
    Color? accent,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    _insert(overlay,
        message: message,
        duration: duration,
        premium: true,
        accent: accent,
        icon: icon);
  }

  /// Standard (non-premium) toast on a pre-resolved [OverlayState].
  static void showOnOverlay(
    OverlayState overlay,
    String message, {
    Color? accent,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    _insert(overlay,
        message: message,
        duration: duration,
        premium: false,
        accent: accent);
  }

  static void _insert(
    OverlayState overlay, {
    required String message,
    required Duration duration,
    required bool premium,
    Color? accent,
    String? icon,
  }) {
    _current?.remove();
    final entry = OverlayEntry(
      builder: (_) => _ToastEntry(
        message: message,
        duration: duration,
        accent: accent,
        icon: icon,
        premium: premium,
        onDismissed: () {
          _current?.remove();
          _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastEntry extends StatefulWidget {
  final String message;
  final Duration duration;
  final Color? accent;
  final String? icon;
  final bool premium;
  final VoidCallback onDismissed;

  const _ToastEntry({
    required this.message,
    required this.duration,
    required this.onDismissed,
    required this.premium,
    this.accent,
    this.icon,
  });

  @override
  State<_ToastEntry> createState() => _ToastEntryState();
}

class _ToastEntryState extends State<_ToastEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _controller.forward();
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final accent = widget.accent ?? AppTheme.recoveryGreen;
    return Positioned(
      bottom: media.padding.bottom + 24,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_controller.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - t)),
                child: child,
              ),
            );
          },
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.premium ? 22 : 16,
                  vertical: widget.premium ? 14 : 10,
                ),
                decoration: BoxDecoration(
                  color: widget.premium
                      ? accent
                      : AppTheme.cardBackground.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(widget.premium ? 24 : 20),
                  border: widget.premium
                      ? null
                      : Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                  boxShadow: [
                    if (widget.premium)
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Text(
                        widget.icon!,
                        style: TextStyle(
                          fontSize: widget.premium ? 22 : 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.premium
                              ? Colors.black
                              : AppTheme.textPrimary,
                          fontSize: widget.premium ? 16 : 14,
                          fontWeight: widget.premium
                              ? FontWeight.w800
                              : FontWeight.w500,
                          letterSpacing: widget.premium ? 0.3 : 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
