import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MaxHype',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'MADE FOR GARY',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ],
    );
  }
}
