import 'package:flutter/material.dart';

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
  });

  /// The field's name.
  final String label;

  /// Builds the field; `labelText` is [label] when it fits in the field and
  /// null when it is drawn above instead.
  final Widget Function(String? labelText) field;

  /// Width the field's own decorations take beside the label (a suffix).
  final double reserve;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (labelFitsField(context, label, box.maxWidth - reserve)) {
        return field(label);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: 4),
          Semantics(label: label, child: field(null)),
        ],
      );
    },
  );
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
