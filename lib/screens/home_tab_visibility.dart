import 'package:flutter/widgets.dart';

/// Notifies Home-tab descendants whenever they become visible after
/// the bottom-nav switched away and back. Carousel uses this so it
/// can re-anchor on the active workout the moment the user returns
/// from History (brief Phase 3 Part 3 §3 — "Returning Home should
/// auto-scroll/land on the active in-progress workout card").
///
/// MainScaffold publishes the current bottom-nav index via
/// [HomeTabVisibility.of(context)?.value]; consumers register for
/// rebuilds with `context.dependOnInheritedWidgetOfExactType`.
class HomeTabVisibility extends InheritedNotifier<ValueNotifier<int>> {
  /// Index of the bottom-nav slot Home occupies. Anything else means
  /// the Home tab is hidden behind another screen.
  static const homeIndex = 0;

  const HomeTabVisibility({
    super.key,
    required ValueNotifier<int> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ValueNotifier<int>? of(BuildContext context) {
    final inh =
        context.dependOnInheritedWidgetOfExactType<HomeTabVisibility>();
    return inh?.notifier;
  }
}
