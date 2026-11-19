import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// Records that could not be read, said in words with a way to try again
/// (AIONIA v1.2): never a spinner forever or a blank area. Nothing was
/// changed by the failed read. [id] keeps the keys apart where several
/// areas share a screen (`<id>-read-failed`, `<id>-try-again`).
class ReadFailedNote extends StatelessWidget {
  const ReadFailedNote({super.key, required this.id, required this.onRetry});

  final String id;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          // Its own node, so a card around it never swallows the
          // announcement.
          container: true,
          liveRegion: true,
          child: Text(s.readFailed, key: ValueKey('$id-read-failed')),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: ValueKey('$id-try-again'),
          onPressed: onRetry,
          child: Text(s.tryAgain),
        ),
      ],
    );
  }
}
