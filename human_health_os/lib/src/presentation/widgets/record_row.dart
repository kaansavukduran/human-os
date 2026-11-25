import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../theme/spacing.dart';

/// "Details" / "Ayrıntılar" (U038): a quiet toggle for a record's
/// machinery (where it came from, when it was saved, what else the report
/// printed). A 48 dp target, reached by Tab, and a button with an expanded
/// state for a screen reader, named with what it belongs to.
/// Key: `details-<id>`.
class DetailsToggle extends StatelessWidget {
  const DetailsToggle({
    super.key,
    required this.id,
    required this.open,
    required this.onToggle,
    required this.about,
    this.showText,
    this.hideText,
  });

  final String id;
  final bool open;
  final VoidCallback onToggle;

  /// What the details belong to, said with the toggle ("Details: HbA1c").
  final String about;

  /// The closed toggle's words; "Details" by default.
  final String? showText;

  /// The open toggle's words; "Hide details" by default. Give one with
  /// [showText], so the toggle closes in the words it opened with (R025).
  final String? hideText;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final words = open ? hideText ?? s.detailsHide : showText ?? s.detailsShow;
    return Semantics(
      container: true,
      button: true,
      expanded: open,
      label: s.fieldDetailsFor(words, about),
      child: InkWell(
        key: ValueKey('details-$id'),
        borderRadius: BorderRadius.circular(Space.s),
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: Space.xs),
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      words,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A [DetailsToggle] with its own open state and the lines it opens, in
/// place, below it. Closed by default; nothing moves until it is tapped.
/// Keys: `details-<id>` (the toggle) and `details-<id>-text` (the lines).
class DetailsDisclosure extends StatefulWidget {
  const DetailsDisclosure({
    super.key,
    required this.id,
    required this.about,
    required this.children,
    this.showText,
    this.hideText,
    this.trailing,
  });

  final String id;
  final String about;
  final List<Widget> children;
  final String? showText;
  final String? hideText;

  /// An action on the toggle's line, at its end (e.g. "Correct").
  final Widget? trailing;

  @override
  State<DetailsDisclosure> createState() => _DetailsDisclosureState();
}

class _DetailsDisclosureState extends State<DetailsDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final toggle = DetailsToggle(
      id: widget.id,
      open: _open,
      about: widget.about,
      showText: widget.showText,
      hideText: widget.hideText,
      onToggle: () => setState(() => _open = !_open),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.trailing case final t?)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [toggle, t],
          )
        else
          Align(alignment: AlignmentDirectional.centerStart, child: toggle),
        if (_open)
          Padding(
            key: ValueKey('details-${widget.id}-text'),
            padding: const EdgeInsetsDirectional.only(
              start: Space.xs,
              bottom: Space.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

/// A quiet line of a record's details (secondary colour, small).
class DetailLine extends StatelessWidget {
  const DetailLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One row pattern for the person's records (U038), on the Timeline, Labs
/// and "Same test over time": one clear primary line (what, and the value
/// as typed), a quieter line (when), then any chips and lines the record
/// needs, and its machinery behind [footer] (usually a [DetailsDisclosure]).
/// Rows are separated by a hairline, not a card.
class RecordRow extends StatelessWidget {
  const RecordRow({
    super.key,
    required this.title,
    required this.value,
    this.when,
    this.chips = const [],
    this.lines = const [],
    this.footer,
    this.onTap,
    this.valueKey,
  });

  final String title;
  final String value;

  /// The quieter line (usually when); none when the title says it.
  final String? when;
  final List<Widget> chips;
  final List<Widget> lines;
  final Widget? footer;

  /// Opens the record (the Timeline's versions sheet); null on Labs.
  final VoidCallback? onTap;

  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    final quiet = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    Widget main = Padding(
      padding: EdgeInsets.only(
        top: Space.m,
        bottom: footer == null ? Space.m : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // What and the value on one line; the value wraps under the
          // name when both do not fit (320 dp, 2× text).
          Wrap(
            spacing: Space.m,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(title, style: text.titleSmall),
              Text(
                value,
                key: valueKey,
                style: text.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (when case final w?) ...[
            const SizedBox(height: Space.xs),
            Text(w, style: quiet),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Wrap(spacing: Space.s, runSpacing: Space.xs, children: chips),
          ],
          if (lines.isNotEmpty) ...[const SizedBox(height: Space.xs), ...lines],
        ],
      ),
    );
    if (onTap != null) {
      // As the Card it replaces did (semanticContainer: false): the row's
      // words stay text nodes a screen reader and the browser can find.
      main = Semantics(
        explicitChildNodes: true,
        child: InkWell(onTap: onTap, child: main),
      );
    } else {
      // Its own node: the row's words are read (and found) together,
      // apart from the Details toggle and Correct below them.
      main = Semantics(container: true, child: main);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [main, ?footer],
      ),
    );
  }
}

/// A day header on the Timeline (U038): "Today", "Yesterday" or the date,
/// a heading a screen reader can jump between.
class DayHeader extends StatelessWidget {
  const DayHeader(this.label, {super.key, this.first = false});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: first ? Space.s : Space.xl),
      child: Semantics(
        header: true,
        container: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
