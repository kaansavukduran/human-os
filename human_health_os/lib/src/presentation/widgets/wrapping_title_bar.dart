import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'whole_words.dart';

/// An app bar whose title keeps the person's text size (U041): a long
/// title wraps onto more lines and the bar grows to hold them, instead of
/// being drawn smaller or cut. It wraps only between words (U042): when one
/// word alone is wider than the bar, the title is drawn just small enough
/// for that word to fit ([WholeWordText]), never broken inside it.
class WrappingTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const WrappingTitleBar({super.key, required this.title, this.height});

  final String title;

  /// The bar's height; [WrappingTitleBar.of] measures it.
  final double? height;

  /// Measures [title] at the app bar's title style and the text size of
  /// [context], for a bar as wide as the window with a back button.
  static WrappingTitleBar of(BuildContext context, String title) {
    final theme = Theme.of(context);
    final style =
        theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
    // The back button (56) and the title spacing on both sides (16 each).
    final width = math.max(
      48.0,
      MediaQuery.sizeOf(context).width -
          kToolbarHeight -
          2 * NavigationToolbar.kMiddleSpacing,
    );
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: direction,
      locale: locale,
      textScaler: wholeWordScaler(
        text: title,
        style: style,
        base: MediaQuery.textScalerOf(context),
        maxWidth: width,
        textDirection: direction,
        locale: locale,
      ),
    )..layout(maxWidth: width);
    final height = math.max(kToolbarHeight, painter.height + 16);
    painter.dispose();
    return WrappingTitleBar(title: title, height: height);
  }

  @override
  Size get preferredSize => Size.fromHeight(height ?? kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // AppBar caps its title's text size at 1.34×; this title keeps the
    // person's own size, and wraps between words instead of AppBar's one
    // line with an ellipsis.
    final scaler = MediaQuery.textScalerOf(context);
    return AppBar(
      toolbarHeight: preferredSize.height,
      title: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: WholeWordText(title),
        ),
      ),
    );
  }
}
