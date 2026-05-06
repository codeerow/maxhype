import 'package:flutter/material.dart';

/// Structural slot for the "Personal Record" header.
/// Part 1 renders nothing here; Part 2 will swap in the PR display
/// (fire emojis + last-session weight × reps) without reflow risk.
class PrPlaceholderHeader extends StatelessWidget {
  const PrPlaceholderHeader({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
