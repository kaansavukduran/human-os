import 'package:flutter/material.dart';

/// The text scaler at which [text] in [style] never breaks inside a word
/// on a line [maxWidth] wide (U042).
///
/// [base], the person's own text size, when the longest word fits at it;
/// otherwise the largest size at which the longest word just fits. Only a
/// word that is wider than the whole line makes the text smaller, and
/// then only as much as that word needs; the words still wrap between
/// them.
TextScaler wholeWordScaler({
  required String text,
  required TextStyle? style,
  required TextScaler base,
  required double maxWidth,
  required TextDirection textDirection,
  Locale? locale,
}) {
  final words = text
      .split(RegExp(r'[ \t\n\r]+'))
      .where((w) => w.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty || !maxWidth.isFinite || maxWidth <= 0) return base;
  double widest(TextScaler scaler) {
    var most = 0.0;
    for (final w in words) {
      final painter = TextPainter(
        text: TextSpan(text: w, style: style),
        textDirection: textDirection,
        textScaler: scaler,
        locale: locale,
        maxLines: 1,
      )..layout();
      if (painter.width > most) most = painter.width;
      painter.dispose();
    }
    return most;
  }

  final width = widest(base);
  if (width <= maxWidth) return base;
  final size = style?.fontSize ?? 14.0;
  var factor = base.scale(size) / size * (maxWidth / width);
  // Glyph widths do not always scale exactly with the size (hinting,
  // rounding): step down a little until the longest word fits.
  for (var i = 0; i < 20; i++) {
    if (widest(TextScaler.linear(factor)) <= maxWidth) break;
    factor *= 0.99;
  }
  return TextScaler.linear(factor);
}

/// A [Text] that wraps between words and never inside one (U042): when a
/// single word is wider than the space, the whole text is drawn just small
/// enough for that word to fit; otherwise at the person's text size.
class WholeWordText extends StatelessWidget {
  const WholeWordText(this.data, {super.key, this.style, this.textAlign});

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = wholeWordScaler(
        text: data,
        style: DefaultTextStyle.of(context).style.merge(style),
        base: MediaQuery.textScalerOf(context),
        maxWidth: constraints.maxWidth,
        textDirection: Directionality.of(context),
        locale: Localizations.maybeLocaleOf(context),
      );
      return Text(
        data,
        style: style,
        textScaler: scaler,
        textAlign: textAlign,
        softWrap: true,
        overflow: TextOverflow.visible,
      );
    },
  );
}
