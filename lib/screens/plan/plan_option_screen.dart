import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/tap_scale.dart';

/// One selectable option on a [PlanOptionScreen].
class PlanOption<T> {
  const PlanOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.comingSoon = false,
  });

  final T value;
  final String title;

  /// Optional secondary line under the title (e.g. a split description).
  final String? subtitle;

  /// Disabled options can't be selected; tapping shows a "coming soon" hint.
  final bool enabled;

  /// Renders a small "Coming soon" pill next to the title.
  final bool comingSoon;
}

/// Full-screen single-select picker used by the Fitness Plan menu, mirroring
/// the web prototype's sub-screens (`screen-routine`, `screen-duration`, …):
/// a list of `Title [subtitle] ✓` rows with a check on the selected one, an
/// orange back arrow, and a title. Tapping a row pops with the chosen value.
///
/// Purely a UI surface — it holds no plan/generator state; the caller applies
/// the returned value. Push it with [show] and await the result.
class PlanOptionScreen<T> extends StatelessWidget {
  const PlanOptionScreen({
    required this.title,
    required this.options,
    required this.selected,
    super.key,
  });

  final String title;
  final List<PlanOption<T>> options;
  final T selected;

  /// Pushes the picker and resolves to the chosen value, or `null` if the user
  /// backed out without changing anything.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<PlanOption<T>> options,
    required T selected,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        builder: (_) => PlanOptionScreen<T>(
          title: title,
          options: options,
          selected: selected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.planBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _topBar(context),
            const SizedBox(height: 20),
            _card(context),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Row(
    children: [
      TapScale.preset(
        preset: TapScalePreset.icon,
        enableHaptic: true,
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0x0DFFFFFF), // white @ 5%
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_back,
            color: AppTheme.planBackArrow,
            size: 20,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      const SizedBox(width: 36),
    ],
  );

  Widget _card(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));
    // Border on the OUTER box (outside the clip) so it isn't shaved off, and
    // the row fills clipped by an INNER ClipRRect so an opaque top/bottom row
    // can't bleed past the rounded corners. Doing both on one clipped
    // Container either eats the rounding (fills) or the stroke (border).
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppTheme.planCardBorder),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: AppTheme.planCardBackground,
          child: Column(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x0FFFFFFF), // white @ 6%
                  ),
                _optionRow(context, options[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionRow(BuildContext context, PlanOption<T> option) {
    final isSelected = option.value == selected;
    return Opacity(
      opacity: option.enabled ? 1 : 0.45,
      // App-standard [TapScale] press (scale + light haptic), not an InkWell:
      // each row paints an opaque fill above the child, so a Material ripple
      // would render behind that fill and bleed past the card's rounded
      // corners.
      child: TapScale.preset(
        preset: TapScalePreset.surface,
        enableHaptic: option.enabled,
        onTap: () {
          if (!option.enabled) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            return;
          }
          Navigator.of(context).pop(option.value);
        },
        child: Container(
          // Selected row gets a subtly lighter navy fill than the unselected
          // rows so the checked option reads clearly.
          color: isSelected ? const Color(0xFF18232D) : const Color(0xFF181C2D),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            option.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (option.comingSoon) ...[
                          const SizedBox(width: 8),
                          _comingSoonPill(),
                        ],
                      ],
                    ),
                    if (option.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        option.subtitle!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  color: AppTheme.primaryOrange,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _comingSoonPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Text(
      'Coming soon',
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
