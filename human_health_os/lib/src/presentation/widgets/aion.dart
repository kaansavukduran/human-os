import 'package:flutter/material.dart';

import '../../app/appearance_scope.dart';
import '../../domain/settings/appearance.dart';
import '../../l10n/strings.dart';

/// Aion, the Human OS character (A001): a still picture from the owner's
/// reference sheet. It greets and keeps empty screens company; it never
/// speaks for the app, gives advice or stands for a clinician. Hidden when
/// the person turns it off in Settings.
class AionFigure extends StatelessWidget {
  const AionFigure({super.key, this.height = 120});

  final double height;

  static const asset = 'assets/aion/aion_wave.png';

  @override
  Widget build(BuildContext context) {
    final show =
        (AppearanceScope.watch(context, AppearanceAspect.aion) ??
                const AppearanceSettings())
            .showAion;
    if (!show) return const SizedBox.shrink();
    return Image.asset(
      asset,
      key: const ValueKey('aion'),
      height: height,
      // Decoded at the drawn size, not the 480 px source (R008).
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(64, 480),
      fit: BoxFit.contain,
      semanticLabel: S.of(context).aionAlt,
      // A missing or unreadable picture leaves only empty space.
      errorBuilder: (_, _, _) => SizedBox(height: height),
    );
  }
}

/// One neutral line beside Aion (U031), the same all day: where things are
/// kept, how a correction works. It never mentions a value, a count or
/// praise, and it is hidden with Aion.
class AionLine extends StatelessWidget {
  const AionLine({super.key, this.day});

  /// The day that picks the line; today when null.
  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final show =
        (AppearanceScope.watch(context, AppearanceAspect.aion) ??
                const AppearanceSettings())
            .showAion;
    if (!show) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Text(
      S.of(context).aionLine(day ?? DateTime.now()),
      key: const ValueKey('aion-line'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
