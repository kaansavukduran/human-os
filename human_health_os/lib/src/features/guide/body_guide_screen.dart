import 'package:flutter/material.dart';

import '../../domain/guide/body_guide.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/tool_row.dart';

String _pick(S s, Bilingual b) => s.lang == AppLang.tr ? b.$2 : b.$1;

/// The body's systems as clickable tiles (U002). A tile opens what the
/// system does, its main parts, the specialties that care for it, and what
/// Human OS can record for it. Explanations only: nothing here reads or
/// judges the person's values.
class BodyGuideScreen extends StatelessWidget {
  const BodyGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(s.guideTitle),
        ),
      ),
      // One centred reading column on a wide window; the systems are
      // plain rows like Learn's, not a grid of cards (U038).
      body: ReadingWidth.builder(
        builder: (context) => ListView(
          key: const ValueKey('screen-guide'),
          padding: readingPadding(context),
          children: [
            Text(
              s.guideIntro,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Space.m),
            for (final b in bodySystems)
              ToolRow(
                key: ValueKey('guide-system-${b.id}'),
                title: _pick(s, b.name),
                hint: b.parts.map((p) => _pick(s, p)).join(' · '),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BodySystemScreen(system: b),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(s.guideSourcesTitle, style: text.titleSmall),
            ),
            const SizedBox(height: 4),
            for (final src in guideSources)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _pick(s, src),
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BodySystemScreen extends StatelessWidget {
  const BodySystemScreen({super.key, required this.system});

  final BodySystem system;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final kinds = [
      for (final code in system.measurements)
        for (final k in RecordKind.values)
          if (k.code == code) k,
    ];
    Widget heading(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Semantics(
        container: true,
        header: true,
        child: Text(t, style: text.titleMedium),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(_pick(s, system.name)),
        ),
      ),
      body: ReadingWidth.builder(
        builder: (context) => ListView(
          key: ValueKey('screen-guide-${system.id}'),
          padding: readingPadding(context),
          children: [
            Text(_pick(s, system.what), style: text.bodyLarge),
            heading(s.guideParts),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in system.parts) Chip(label: Text(_pick(s, p))),
              ],
            ),
            heading(s.guideWhoCares),
            for (final id in system.specialties)
              Container(
                key: ValueKey('guide-specialty-$id'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pick(s, specialtyById(id).name),
                      style: text.titleSmall,
                    ),
                    Text(
                      _pick(s, specialtyById(id).what),
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              s.guideFirstStop,
              key: const ValueKey('guide-first-stop'),
              style: text.bodyMedium,
            ),
            if (kinds.isNotEmpty) ...[
              heading(s.guideInHumanOs),
              Text(
                kinds.map(s.recordKind).join(' · '),
                key: const ValueKey('guide-measurements'),
                style: text.bodyMedium,
              ),
            ],
            const SizedBox(height: 20),
            Text(
              s.guideNotAdvice,
              key: const ValueKey('guide-not-advice'),
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
