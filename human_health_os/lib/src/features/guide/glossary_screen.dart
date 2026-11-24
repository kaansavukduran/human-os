import 'package:flutter/material.dart';

import '../../domain/guide/body_guide.dart' show Bilingual;
import '../../domain/guide/glossary.dart';
import '../../l10n/strings.dart';
import '../../app/appearance_scope.dart';
import '../../domain/settings/appearance.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/tool_row.dart';
import '../../presentation/widgets/whole_label_field.dart';

String _pick(S s, Bilingual b) => s.lang == AppLang.tr ? b.$2 : b.$1;

/// Lower case without Turkish dots and marks, so "NABIZ", "nabiz" and
/// "nabız" all find "nabız" (Dart's toLowerCase maps I to i, not ı).
String foldForSearch(String s) {
  const map = {
    'I': 'i',
    'İ': 'i',
    'ı': 'i',
    'Ş': 's',
    'ş': 's',
    'Ğ': 'g',
    'ğ': 'g',
    'Ü': 'u',
    'ü': 'u',
    'Ö': 'o',
    'ö': 'o',
    'Ç': 'c',
    'ç': 'c',
  };
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(map[ch] ?? ch.toLowerCase());
  }
  return b.toString();
}

/// Every term and measurement in plain words (U003), searchable.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final q = foldForSearch(_q.trim());
    final shown = [
      for (final e in glossary)
        if (q.isEmpty ||
            foldForSearch(e.term.$1).contains(q) ||
            foldForSearch(e.term.$2).contains(q))
          e,
    ];
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(s.glossaryTitle),
        ),
      ),
      // One centred reading column on a wide window (U038).
      body: ReadingWidth(
        child: ListView(
          key: const ValueKey('screen-glossary'),
          padding: kPagePadding,
          children: [
            WholeLabelField(
              label: s.glossarySearch,
              reserve: 48,
              field: (labelText) => TextField(
                key: const ValueKey('glossary-search'),
                decoration: InputDecoration(
                  labelText: labelText,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  s.glossaryNone,
                  key: const ValueKey('glossary-none'),
                ),
              ),
            // Plain rows (U038), as on Learn: the term, what it is, a chevron.
            for (final e in shown)
              ToolRow(
                key: ValueKey('glossary-${e.id}'),
                title: _pick(s, e.term),
                hint: _pick(s, e.what),
                onTap: () {
                  AppearanceScope.read(context)?.visit(DiscoveryStep.glossary);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GlossaryEntryScreen(entry: e),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Text(
              _pick(s, glossaryAuthorship),
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class GlossaryEntryScreen extends StatelessWidget {
  const GlossaryEntryScreen({super.key, required this.entry});

  final GlossaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final unit = entry.unit;
    final source = entry.source;
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(_pick(s, entry.term)),
        ),
      ),
      body: ReadingWidth(
        child: ListView(
          key: ValueKey('screen-glossary-${entry.id}'),
          padding: kPagePadding,
          children: [
            Text(_pick(s, entry.what), style: text.bodyLarge),
            if (unit != null) ...[
              const SizedBox(height: 16),
              Text(s.glossaryUnit, style: text.titleSmall),
              Text(_pick(s, unit), key: const ValueKey('glossary-unit')),
            ],
            if (entry.howToMeasure.isNotEmpty) ...[
              const SizedBox(height: 16),
              Semantics(
                container: true,
                header: true,
                child: Text(s.glossaryHow, style: text.titleMedium),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < entry.howToMeasure.length; i++)
                Padding(
                  key: ValueKey('glossary-step-${i + 1}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}',
                          style: text.titleSmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Expanded(child: Text(_pick(s, entry.howToMeasure[i]))),
                    ],
                  ),
                ),
            ],
            if (source != null) ...[
              const SizedBox(height: 12),
              Text(
                _pick(s, source),
                style: text.bodySmall?.copyWith(color: scheme.outline),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _pick(s, glossaryAuthorship),
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
