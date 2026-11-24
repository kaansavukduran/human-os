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

/// Centres [child] and keeps it at most [kReadingWidth] wide.
class ReadingWidth extends StatelessWidget {
  const ReadingWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      key: const ValueKey('reading-width'),
      constraints: const BoxConstraints(maxWidth: kReadingWidth),
      child: child,
    ),
  );
}
