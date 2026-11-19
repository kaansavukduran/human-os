import 'package:flutter/material.dart';

import '../../app/appearance_scope.dart';
import '../../domain/guide/glossary.dart';
import '../../l10n/strings.dart';
import '../../navigation/destinations.dart';
import 'term_link.dart';

/// The top of every area (U031): its title, then three plain lines for
/// someone who has never seen the app: what this is, what you can do here
/// and what the app never does. Open at first; once closed it stays closed
/// (saved with the appearance settings) and one button opens it again.
/// [terms] are glossary ids shown as [TermLink]s under it, open or closed.
class AreaIntro extends StatefulWidget {
  const AreaIntro({
    super.key,
    required this.area,
    this.title,
    this.what,
    this.terms = const [],
  });

  final DestinationId area;

  /// The screen's own title; the area's label when null.
  final String? title;

  /// The screen's own fuller "what this is"; the area's purpose when null.
  final String? what;
  final List<String> terms;

  @override
  State<AreaIntro> createState() => _AreaIntroState();
}

class _AreaIntroState extends State<AreaIntro> {
  /// Used only where no settings are kept (a screen shown on its own).
  bool _closedHere = false;

  String get _id => widget.area.name;

  void _set(BuildContext context, {required bool closed}) {
    final scope = AppearanceScope.maybeOf(context);
    if (scope == null) {
      setState(() => _closedHere = closed);
      return;
    }
    scope.update(scope.value.explain(_id, closed: closed));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final d = destinationById(widget.area);
    final scope = AppearanceScope.maybeOf(context);
    final closed = scope == null
        ? _closedHere
        : scope.value.explainedAreas.contains(_id);
    final label = text.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget line(String key, String heading, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        key: ValueKey('area-$key-$_id'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: label),
          const SizedBox(height: 2),
          Text(body, style: text.bodyMedium),
        ],
      ),
    );

    final terms = [
      for (final t in widget.terms)
        if (glossaryById(t) != null) t,
    ];
    return Column(
      key: ValueKey('area-intro-$_id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.title ?? d.label(s.lang),
            style: text.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        if (closed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('area-intro-show-$_id'),
              onPressed: () => _set(context, closed: false),
              icon: const Icon(Icons.info_outline),
              label: Text(s.areaShow),
            ),
          )
        else ...[
          line('what', s.areaWhatThis, widget.what ?? d.purpose(s.lang)),
          line('can', s.areaCanDo, d.canDo(s.lang)),
          line('never', s.areaNever, d.principle(s.lang)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('area-intro-close-$_id'),
              onPressed: () => _set(context, closed: true),
              icon: const Icon(Icons.expand_less),
              label: Text(s.areaClose),
            ),
          ),
        ],
        if (terms.isNotEmpty)
          Wrap(
            key: ValueKey('area-terms-$_id'),
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(s.termsHere, style: label),
              for (final t in terms) TermLink(t),
            ],
          ),
      ],
    );
  }
}
