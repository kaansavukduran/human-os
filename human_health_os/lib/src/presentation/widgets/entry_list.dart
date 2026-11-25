import 'package:flutter/widgets.dart';

import '../theme/spacing.dart';

/// An area screen's scroll view (U031-S4): its introduction and controls
/// first, then its entries, built only as they scroll into view, so a long
/// history costs no more to open than a short one.
class EntryList extends StatelessWidget {
  const EntryList({
    super.key,
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = kPagePadding,
  });

  /// The introduction, controls and any note above the entries.
  final List<Widget> header;

  /// The number of entries; zero while loading, after a failed read and
  /// when there are none (the header then says which).
  final int itemCount;

  final IndexedWidgetBuilder itemBuilder;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Full width, so it scrolls wherever the pointer is; the reading column
    // is its padding (U039).
    final padding = readingPadding(context, this.padding);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding.copyWith(bottom: 0),
          sliver: SliverList.list(children: header),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 0),
          sliver: SliverList.builder(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}
