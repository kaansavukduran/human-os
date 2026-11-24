import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../theme/spacing.dart';

/// A bottom-sheet form whose fields scroll while its buttons stay in view
/// (G-74): Save and Cancel never scroll away under long forms, large text
/// or a narrow window. The keyboard, when open, lifts the whole sheet; the
/// system's bottom area is kept clear otherwise (never both).
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.fields, required this.actions});

  final List<Widget> fields;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = keyboard > 0
        ? keyboard
        : MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: fields,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: actions),
          ),
        ],
      ),
    );
  }
}

/// One focus node per text field of a form sheet, by the field name an
/// `InputError` carries (G-73). After a refused save the field the error is
/// about takes keyboard focus and is scrolled into view, so a keyboard or
/// screen-reader user lands on it. An error on no text field moves nothing.
class FieldFocus {
  final _nodes = <String, FocusNode>{};

  FocusNode operator [](String field) =>
      _nodes.putIfAbsent(field, () => FocusNode(debugLabel: field));

  /// After the next frame (the error is shown by then), if [state] is still
  /// mounted, focuses [field] and brings it into view.
  void focusAfterFrame(State state, String? field) {
    final node = field == null ? null : _nodes[field];
    if (node == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.mounted) return;
      node.requestFocus();
      final target = node.context;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.2,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
  }
}

/// An instant as it would be typed: local `YYYY-MM-DD HH:MM`.
String typedLocal(DateTime utc) => typedWall(utc.toLocal());

/// Local wall-clock fields as typed: `YYYY-MM-DD HH:MM`.
String typedWall(DateTime local) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

/// Quick picks that fill a time field, so a time can be given by clicking
/// (G-74). Each pick only writes text into the field; the usual rules check
/// it on Save. A pick in the future is shown disabled.
class TimePicks extends StatelessWidget {
  const TimePicks({
    super.key,
    required this.keyPrefix,
    required this.controller,
    required this.picks,
    this.onPicked,
  });

  final String keyPrefix;
  final TextEditingController controller;

  /// (label, text to write, enabled).
  final List<(String, String, bool)> picks;
  final VoidCallback? onPicked;

  /// Now, an hour ago, this morning 08:00, yesterday 20:00.
  static List<(String, String, bool)> recent(S s, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final today8 = DateTime(t.year, t.month, t.day, 8);
    return [
      (s.presetNow, '', true),
      (s.presetHourAgo, typedWall(t.subtract(const Duration(hours: 1))), true),
      (s.presetMorning, typedWall(today8), today8.isBefore(t)),
      (
        s.presetYesterdayEvening,
        typedWall(DateTime(t.year, t.month, t.day - 1, 20)),
        true,
      ),
    ];
  }

  /// Clock times only (`HH:MM`), for a time whose day the service works out
  /// (going to bed before waking).
  static List<(String, String, bool)> clock(List<String> times) => [
    for (final t in times) (t, t, true),
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        label: s.timePresetsLabel,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (label, value, enabled) in picks)
              ActionChip(
                key: ValueKey('$keyPrefix-pick-$label'),
                label: Text(label),
                onPressed: enabled
                    ? () {
                        controller.text = value;
                        onPicked?.call();
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// A small section label inside a form sheet (U037): it groups the fields
/// under it, so a sheet reads as two or three short parts instead of one
/// long column, and no paragraph is needed to say what a group is for.
class SheetSection extends StatelessWidget {
  const SheetSection(this.label, {super.key, this.first = false});

  final String label;

  /// The first section sits right under the sheet's title.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : Space.l, bottom: Space.s),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// "What to type here" under a field (U037): the field's helper stays one
/// short line; the longer explanation opens on demand, in place, and is
/// read by a screen reader once opened. Nothing moves until it is tapped.
/// Keys: `<id>-details` (the toggle) and `<id>-details-text`.
class FieldDetails extends StatefulWidget {
  const FieldDetails({
    super.key,
    required this.id,
    required this.text,
    required this.fieldLabel,
    this.showText,
    this.textKey,
  });

  final String id;
  final String text;

  /// The name of the field these details belong to. A screen reader hears
  /// it with the toggle, so several toggles on one sheet stay apart.
  final String fieldLabel;

  /// The closed toggle's words; "What to type here" by default.
  final String? showText;

  /// The key of the opened text; `<id>-details-text` by default.
  final Key? textKey;

  @override
  State<FieldDetails> createState() => _FieldDetailsState();
}

class _FieldDetailsState extends State<FieldDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final toggle = _open
        ? s.fieldDetailsHide
        : widget.showText ?? s.fieldDetailsShow;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          button: true,
          expanded: _open,
          label: s.fieldDetailsFor(toggle, widget.fieldLabel),
          child: InkWell(
            key: ValueKey('${widget.id}-details'),
            borderRadius: BorderRadius.circular(Space.s),
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        _open ? Icons.expand_less : Icons.help_outline,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    Flexible(
                      // Said once, with the field's name, by the Semantics
                      // above.
                      child: ExcludeSemantics(
                        child: Text(
                          toggle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s, 0, Space.s, Space.s),
            child: Text(
              widget.text,
              key: widget.textKey ?? ValueKey('${widget.id}-details-text'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// An error in plain words right under the field it is about (U037), read
/// out when it appears.
class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key, this.textKey});

  final String text;

  /// The key of the text itself (tests read it).
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, Space.s),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          key: textKey,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
