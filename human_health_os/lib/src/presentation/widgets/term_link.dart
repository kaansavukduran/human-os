import 'package:flutter/material.dart';

import '../../app/appearance_scope.dart';
import '../../domain/guide/body_guide.dart' show Bilingual;
import '../../domain/guide/glossary.dart';
import '../../domain/settings/appearance.dart';
import '../../features/guide/glossary_screen.dart';
import '../../l10n/strings.dart';

String _pick(S s, Bilingual b) => s.lang == AppLang.tr ? b.$2 : b.$1;

/// A word the glossary explains, shown inline (U031): underlined with a
/// small help icon, so the link is never told by the underline alone. A
/// tap opens a short sheet with the glossary's plain explanation and unit,
/// and "Open in glossary" for the whole entry. An id the glossary does not
/// have shows nothing: a link never leads to an empty page.
class TermLink extends StatelessWidget {
  const TermLink(this.id, {super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    final entry = glossaryById(id);
    if (entry == null) return const SizedBox.shrink();
    final s = S.of(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final term = _pick(s, entry.term);
    return Semantics(
      button: true,
      label: s.termWhat(term),
      child: InkWell(
        key: ValueKey('term-$id'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _open(context, entry),
        child: ConstrainedBox(
          // A comfortable touch target around a short word.
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            // The button is read by its question, not the bare word.
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      term,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        decoration: TextDecoration.underline,
                        decorationColor: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.help_outline, size: 16, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, GlossaryEntry entry) async {
    final nav = Navigator.of(context);
    final scope = AppearanceScope.read(context);
    final more = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _TermSheet(entry: entry),
    );
    if (more != true) return;
    final opened = nav.push(
      MaterialPageRoute<void>(
        builder: (_) => GlossaryEntryScreen(entry: entry),
      ),
    );
    await scope?.visit(DiscoveryStep.glossary);
    await opened;
  }
}

class _TermSheet extends StatelessWidget {
  const _TermSheet({required this.entry});

  final GlossaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final unit = entry.unit;
    return SafeArea(
      child: SingleChildScrollView(
        key: ValueKey('term-sheet-${entry.id}'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(_pick(s, entry.term), style: text.titleMedium),
            ),
            const SizedBox(height: 8),
            Text(_pick(s, entry.what), style: text.bodyMedium),
            if (unit != null) ...[
              const SizedBox(height: 12),
              Text(s.glossaryUnit, style: text.titleSmall),
              Text(_pick(s, unit), style: text.bodyMedium),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              key: ValueKey('term-open-${entry.id}'),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(s.termOpenGlossary),
            ),
          ],
        ),
      ),
    );
  }
}
