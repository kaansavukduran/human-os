import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/capabilities.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/status_chip.dart';
import '../../presentation/widgets/whole_words.dart';

/// Settings → About Human OS (U032): the facts about this build (version,
/// source revision, Flutter and Dart, record schema, build profile and
/// platform) and what works on this device. They used to close Today; a
/// person with no prior knowledge does not need them there, support does.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      // Drawn smaller rather than ellipsized when the top bar is too narrow
      // for the title at the person's text size (Q003, matching U035).
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(s.aboutTitle),
        ),
      ),
      body: ReadingWidth.builder(
        builder: (context) => ListView(
          key: const ValueKey('screen-about'),
          padding: readingPadding(context, const EdgeInsets.all(16)),
          children: [
            _Section(
              key: const ValueKey('about-build'),
              title: s.thisBuild,
              child: Column(
                children: [
                  _KeyValue(s.profile, s.profileName(services.config.profile)),
                  _KeyValue(s.version, s.buildFact(services.config.version)),
                  _KeyValue(s.platform, services.registry.platform.name),
                  _KeyValue(
                    s.sourceRevision,
                    s.buildFact(services.config.shortRevision),
                  ),
                  _KeyValue(
                    s.flutterVersion,
                    s.buildFact(services.config.flutterVersion),
                  ),
                  _KeyValue(
                    s.dartVersion,
                    s.buildFact(services.config.dartVersion),
                  ),
                  _KeyValue(
                    s.recordSchema,
                    'v${HealthRecord.currentSchemaVersion}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              key: const ValueKey('about-capabilities'),
              title: s.capabilities,
              child: Column(
                children: [
                  for (final c in services.registry.capabilities)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.capText(c.label),
                                  style: text.titleMedium,
                                ),
                                Text(
                                  s.capText(c.detail),
                                  style: text.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // May wrap: at 320 dp with 2x text a fixed chip
                          // overflowed the row (found by the F007 layout test).
                          Flexible(
                            child: StatusChip(
                              label: switch (c.status) {
                                CapabilityStatus.available => s.available,
                                CapabilityStatus.notImplemented =>
                                  s.notImplemented,
                                CapabilityStatus.notRequired => s.notRequired,
                                CapabilityStatus.off => s.savingOff,
                                CapabilityStatus.unsupportedOnPlatform =>
                                  s.unsupported,
                              },
                              tone: switch (c.status) {
                                CapabilityStatus.available => StatusTone.ok,
                                CapabilityStatus.notImplemented =>
                                  StatusTone.muted,
                                CapabilityStatus.notRequired => StatusTone.ok,
                                CapabilityStatus.off => StatusTone.info,
                                CapabilityStatus.unsupportedOnPlatform =>
                                  StatusTone.info,
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      // Keep child semantics separate so headings are not merged with body text.
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      // Both sides may wrap: a long value (e.g. DEVELOPMENT at 2x text on a
      // 320 dp phone) overflowed a fixed-width value cell.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Never broken inside a word: a word wider than its half is drawn
          // just small enough to stay whole ("GELİŞTİRME" at 2× text on a
          // 320 dp phone broke as "GELİŞTİR / ME"; U046).
          Expanded(child: WholeWordText(k, style: text.bodyMedium)),
          const SizedBox(width: 8),
          Flexible(
            child: WholeWordText(
              v,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
