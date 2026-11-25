import 'package:flutter/material.dart';

import 'whole_words.dart';

/// A chip whose label is never cut and never broken inside a word (U043).
///
/// Material's chips draw their label on one line and fade it at the chip's
/// edge ("Same as this de…" at 320 dp with 2× text). This chip looks the
/// same at ordinary sizes, but when its label is wider than the line it
/// wraps between words onto more lines, at the person's text size; only
/// a single word wider than the whole line draws the label smaller
/// ([WholeWordText]). Its touch target is at least 48 × 48 dp, and a
/// screen reader reads the whole label once.
///
/// [WholeChip.choice] stands for a choice or filter chip (a tick when
/// selected; [onSelected] gets the new state, null disables it),
/// [WholeChip.action] for an action chip and [WholeChip.plain] for a
/// label that does nothing.
class WholeChip extends StatelessWidget {
  const WholeChip.choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.semanticsLabel,
    this.tooltip,
    this.focusNode,
  }) : onPressed = null,
       _kind = _Kind.choice;

  const WholeChip.action({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticsLabel,
    this.tooltip,
    this.focusNode,
  }) : selected = false,
       onSelected = null,
       _kind = _Kind.action;

  const WholeChip.plain({super.key, required this.label, this.semanticsLabel})
    : selected = false,
      onSelected = null,
      onPressed = null,
      tooltip = null,
      focusNode = null,
      _kind = _Kind.plain;

  /// What the chip says, drawn whole.
  final String label;

  /// What a screen reader says instead of [label], when it differs.
  final String? semanticsLabel;

  /// Whether a choice chip is chosen.
  final bool selected;

  /// A choice chip's tap, with the state it asks for; null disables it.
  final ValueChanged<bool>? onSelected;

  /// An action chip's tap; null disables it.
  final VoidCallback? onPressed;

  final String? tooltip;

  /// The focus node of a tappable chip (to move focus to it).
  final FocusNode? focusNode;

  final _Kind _kind;

  VoidCallback? get _tap => switch (_kind) {
    _Kind.choice => onSelected == null ? null : () => onSelected!(!selected),
    _Kind.action => onPressed,
    _Kind.plain => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tap = _tap;
    final enabled = _kind == _Kind.plain || tap != null;
    final on = _kind == _Kind.choice && selected;
    final ink = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : on
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final fill = on
        ? (enabled
              ? scheme.secondaryContainer
              : scheme.onSurface.withValues(alpha: 0.12))
        : Colors.transparent;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: on
          ? BorderSide.none
          : BorderSide(
              color: enabled
                  ? scheme.outlineVariant
                  : scheme.onSurface.withValues(alpha: 0.12),
            ),
    );
    final style = theme.textTheme.labelLarge?.copyWith(color: ink);
    // The tick grows with the text, as Material's does.
    final tick = MediaQuery.textScalerOf(context).scale(18);
    Widget chip = Material(
      type: MaterialType.canvas,
      color: fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tap,
        focusNode: focusNode,
        customBorder: shape,
        // A focus ring the reader can see from the keyboard (U043 review):
        // the ink overlay alone is faint, most of all in high contrast.
        child: Builder(
          builder: (context) => DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: _focusRing(context, scheme),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32, minWidth: 48),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: on ? 8 : 16,
                  end: 16,
                  top: 6,
                  bottom: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (on) ...[
                      Icon(Icons.check, size: tick, color: ink),
                      const SizedBox(width: 8),
                    ],
                    // Read once, by the chip's own node.
                    Flexible(
                      child: ExcludeSemantics(
                        child: WholeWordText(label, style: style),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) chip = Tooltip(message: tooltip, child: chip);
    return Semantics(
      container: true,
      button: _kind != _Kind.plain,
      enabled: _kind == _Kind.plain ? null : enabled,
      selected: _kind == _Kind.choice ? selected : null,
      label: semanticsLabel ?? label,
      // The 8 dp above and below the drawn chip are part of its target,
      // so a one-line chip is 48 dp tall, like Material's.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: chip,
        ),
      ),
    );
  }
}

/// A 2 dp ring in the primary colour while the chip holds keyboard focus.
Decoration _focusRing(BuildContext context, ColorScheme scheme) {
  final focused =
      Focus.of(context).hasPrimaryFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
  if (!focused) return const BoxDecoration();
  return ShapeDecoration(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: scheme.primary, width: 2),
    ),
  );
}

enum _Kind { choice, action, plain }
