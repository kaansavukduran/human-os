import 'package:flutter/material.dart';

import 'aion.dart';

/// An empty area names the next step (U031): Aion, one concrete sentence
/// and, where it can be done from here, one action.
class FirstStep extends StatelessWidget {
  const FirstStep({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AionFigure(height: 64),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: Theme.of(context).textTheme.bodyLarge),
              if (action != null) ...[const SizedBox(height: 4), action],
            ],
          ),
        ),
      ],
    );
  }
}
