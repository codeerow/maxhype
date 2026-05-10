import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight iOS-style top banner used in place of Material SnackBar.
///
/// `AppToast.show(context, 'message')` overlays a translucent pill at the
/// top of the screen for a couple of seconds. No haptic, no actions —
/// purely informational. For destructive confirmations use a
/// CupertinoAlertDialog.
class AppToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 1800),
    Color? accent,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _current?.remove();

    final entry = OverlayEntry(
      builder: (_) => _ToastEntry(
        message: message,
        duration: duration,
        accent: accent,
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
  final VoidCallback onDismissed;

  const _ToastEntry({
    required this.message,
    required this.duration,
    required this.onDismissed,
    this.accent,
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
      top: media.padding.top + 8,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_controller.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, -12 * (1 - t)),
                child: child,
              ),
            );
          },
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
