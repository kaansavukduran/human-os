import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// Records being read, said in words (U031): a small spinner and "Opening
/// your records…", announced once. Never "none" before the first read has
/// finished.
class LoadingLine extends StatelessWidget {
  const LoadingLine({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: s.loadingRecords,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.loadingRecords,
                key: const ValueKey('loading-line'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
