import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../l10n/strings.dart';

/// Visible on every non-production build so test builds are never mistaken
/// for a release (v0.27 doc 209 item 4).
///
/// One line at every size (U035): the whole sentence when it fits, else a
/// shorter form that still names the build ("DEVELOPMENT BUILD · not for
/// clinical decisions", then "DEVELOPMENT BUILD"). The whole sentence is
/// always the banner's screen-reader label and its tooltip, and a tap shows
/// it on screen; nothing is cut with an ellipsis.
class BuildProfileBanner extends StatefulWidget {
  const BuildProfileBanner({super.key, required this.config});

  final AppConfig config;

  @override
  State<BuildProfileBanner> createState() => _BuildProfileBannerState();
}

class _BuildProfileBannerState extends State<BuildProfileBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    if (config.isProduction) return const SizedBox.shrink();
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final staging = config.profile == BuildProfile.staging;
    final full = staging ? s.stagingBanner : s.devBanner;
    final forms = [
      full,
      staging ? s.stagingBannerMedium : s.devBannerMedium,
      staging ? s.stagingBannerShort : s.devBannerShort,
    ];
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: scheme.onTertiaryContainer);
    return LayoutBuilder(
      builder: (context, box) {
        // Padding 16 + 16, the icon 16 and its gap 8, the expand mark 16
        // and its gap 8.
        final room = box.maxWidth - 80;
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        bool fits(String t) {
          final p = TextPainter(
            text: TextSpan(text: t, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final ok = p.width <= room;
          p.dispose();
          return ok;
        }

        final wholeFits = fits(full);
        final shown = _expanded
            ? full
            : forms.firstWhere(fits, orElse: () => forms.last);
        final Widget line = _expanded || fits(shown)
            ? Text(shown, style: style, key: const ValueKey('banner-text'))
            // Even the shortest form is wider than the line: it is drawn
            // smaller rather than cut.
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  shown,
                  style: style,
                  maxLines: 1,
                  softWrap: false,
                  key: const ValueKey('banner-text'),
                ),
              );
        final banner = Container(
          key: const ValueKey('build-profile-banner'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.science_outlined,
                size: 16,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(child: line),
              if (!wholeFits) ...[
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: scheme.onTertiaryContainer,
                ),
              ],
            ],
          ),
        );
        return Semantics(
          container: true,
          label: full,
          child: ExcludeSemantics(
            child: wholeFits
                ? banner
                : Tooltip(
                    message: full,
                    excludeFromSemantics: true,
                    child: GestureDetector(
                      key: const ValueKey('build-profile-banner-toggle'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: banner,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
