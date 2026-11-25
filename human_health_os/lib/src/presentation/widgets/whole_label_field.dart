import 'package:flutter/material.dart';

import 'whole_words.dart';

/// A text field whose label is never cut (U035). Material draws a field's
/// label on one line and ellipsizes it ("Ağırlı" at 320 dp, 2× text,
/// Turkish). When the label fits inside the field at the person's text
/// size it stays the field's own floating label; when it does not, it is
/// drawn whole above the field, wrapping between words, and the field keeps
/// it as its screen-reader name.
class WholeLabelField extends StatelessWidget {
  const WholeLabelField({
    super.key,
    required this.label,
    required this.field,
    this.reserve = 0,
    this.knownWidth,
  });

  /// The field's name.
  final String label;

  /// Builds the field; `labelText` is [label] when it fits in the field and
  /// null when it is drawn above instead.
  final Widget Function(String? labelText) field;

  /// Width the field's own decorations take beside the label (a suffix).
  final double reserve;

  /// A width the field is known to have at least, used instead of
  /// measuring it. Only for a place that sizes its content by intrinsic
  /// widths (an [AlertDialog]), where a [LayoutBuilder] cannot be used
  /// (U044). The label goes above the field unless it fits in this width.
  final double? knownWidth;

  Widget _build(BuildContext context, double width) {
    final above = !labelFitsField(context, label, width - reserve);
    final style = Theme.of(context).textTheme.bodyMedium;
    // One tree for both layouts (U044 review): the field keeps its element,
    // so a resize or rotation that moves the label does not drop focus.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (above) ...[
          // Wraps between words; a single word wider than the line draws
          // the label just small enough for it (U042), never broken inside.
          ExcludeSemantics(
            child: Text(
              label,
              style: style,
              textScaler: wholeWordScaler(
                text: label,
                style: DefaultTextStyle.of(context).style.merge(style),
                base: MediaQuery.textScalerOf(context),
                maxWidth: width,
                textDirection: Directionality.of(context),
                locale: Localizations.maybeLocaleOf(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        KeyedSubtree(
          key: const ValueKey('whole-label-field'),
          child: Semantics(
            label: above ? label : null,
            child: field(above ? null : label),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => switch (knownWidth) {
    final w? => _build(context, w),
    null => LayoutBuilder(
      builder: (context, box) => _build(context, box.maxWidth),
    ),
  };
}

/// The narrowest content width an [AlertDialog] with the default insets
/// (40 dp each side, at least 280 dp wide, 24 dp content padding) has in
/// this window: a lower bound for [WholeLabelField.knownWidth].
double dialogContentWidth(BuildContext context) {
  final window = MediaQuery.sizeOf(context).width - 80;
  return (window < 280 ? window : 280) - 48;
}

/// The width [text] takes on one line in [style] at the current text size.
double oneLineWidth(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final w = painter.width;
  painter.dispose();
  return w;
}

/// Whether a field [width] wide shows [label] whole as its resting (widest)
/// floating label: the label plus the field's 12 dp side paddings and a
/// little room so rounding never cuts the last letter.
bool labelFitsField(BuildContext context, String label, double width) {
  final theme = Theme.of(context);
  final style = (theme.textTheme.bodyLarge ?? const TextStyle()).merge(
    theme.inputDecorationTheme.labelStyle,
  );
  return oneLineWidth(context, label, style) + 32 <= width;
}
