import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The one spacing scale (U036): 4 / 8 / 12 / 16 / 24 / 32 dp. Sections are
/// 24–32 apart, cards have 16–20 inside, list items 8–12 between them.
abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Between two sections of a screen.
  static const double section = xxl;

  /// Inside a card.
  static const double card = 20;

  /// Between two items of a list or a grid.
  static const double item = m;
}

/// The widest a reading column grows on a wide window (U036): lines of
/// text stay comfortable to read and the column is centred, instead of
/// running from edge to edge.
const double kReadingWidth = 840;

/// The padding around a screen's scrolling content: 16 at the sides, a
/// little more above the title and room at the end.
const EdgeInsets kPagePadding = EdgeInsets.fromLTRB(
  Space.l,
  Space.xl,
  Space.l,
  Space.xxl,
);

/// A screen's reading column (U036, U039): the scroll view under it spans
/// the whole width it is given, so the mouse wheel, a trackpad and a drag
/// scroll the page wherever the pointer is and the scrollbar sits at the
/// window edge; the content inside it stays a centred column of at most
/// [kReadingWidth], through [readingPadding].
class ReadingWidth extends StatelessWidget {
  const ReadingWidth({super.key, required Widget this.child}) : builder = null;

  /// For a screen whose own build context is above the wrapper: [builder]
  /// gets a context under it, for [readingPadding].
  const ReadingWidth.builder({super.key, required WidgetBuilder this.builder})
    : child = null;

  final Widget? child;
  final WidgetBuilder? builder;

  /// How far the reading column sits in from each side of the scroll view:
  /// half of what is left beside [kReadingWidth], 0 on a narrow window and
  /// outside a [ReadingWidth].
  static double sideOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReadingSide>()?.side ?? 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _ReadingSide(
      side: box.maxWidth.isFinite
          ? math.max(0.0, (box.maxWidth - kReadingWidth) / 2)
          : 0.0,
      child: KeyedSubtree(
        key: const ValueKey('reading-width'),
        child: child ?? Builder(builder: builder!),
      ),
    ),
  );
}

class _ReadingSide extends InheritedWidget {
  const _ReadingSide({required this.side, required super.child});

  final double side;

  @override
  bool updateShouldNotify(_ReadingSide oldWidget) => side != oldWidget.side;
}

/// [base] (the page padding by default) with the reading column's side
/// added left and right: the padding of a scroll view under a
/// [ReadingWidth], which keeps its content centred and at most
/// [kReadingWidth] wide, padding included.
EdgeInsets readingPadding(
  BuildContext context, [
  EdgeInsets base = kPagePadding,
]) {
  final side = ReadingWidth.sideOf(context);
  return base.copyWith(left: base.left + side, right: base.right + side);
}
