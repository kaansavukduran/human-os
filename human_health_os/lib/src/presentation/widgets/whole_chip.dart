import 'package:flutter/foundation.dart' show kIsWeb;
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
/// [WholeChip.action] for an action chip. A label that does nothing is
/// not a chip: it is drawn as plain text, so it never looks tappable
/// (U046).
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
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tap = _tap;
    final enabled = tap != null;
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
    // The theme's density (Settings, "Compact") moves the drawn chip as it
    // moves Material's: compact takes 4 dp off each side's padding, so a
    // one-line chip is drawn 24 dp tall instead of 32 (U044). Whatever is
    // drawn, the target stays at least 48 dp: the space above and below
    // grows by what the drawn chip lost.
    final density = theme.visualDensity.baseSizeAdjustment;
    final drawnMin = (32 + density.dy).clamp(20.0, 48.0);
    final padY = (6 + density.dy / 2).clamp(0.0, 14.0);
    final padX = (16 + density.dx / 2).clamp(8.0, 24.0);
    final targetPad = (48 - drawnMin) / 2;
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
              constraints: BoxConstraints(minHeight: drawnMin, minWidth: 48),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: on ? padX / 2 : padX,
                  end: padX,
                  top: padY,
                  bottom: padY,
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
      button: true,
      enabled: enabled,
      // As Material's chip: on the web aria-selected is ignored on a button,
      // so a selected chip is announced as checked there (a checkbox).
      selected: _kind == _Kind.choice && !kIsWeb ? selected : null,
      checked: _kind == _Kind.choice && kIsWeb ? selected : null,
      label: semanticsLabel ?? label,
      // The space above and below the drawn chip (8 dp, 12 dp when
      // compact) is part of its target, so a one-line chip is 48 dp tall,
      // like Material's.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: tap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: targetPad),
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

enum _Kind { choice, action }
