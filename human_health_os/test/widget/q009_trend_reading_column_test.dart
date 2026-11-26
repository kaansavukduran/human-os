// Q009 (full screen matrix after U045), by eye: on a 1440 dp desktop the
// weight's "over time" page ran from the window's left edge (its range
// chips and "Nothing saved in this period." at x 16), while every other
// page, the lab group's "over time" included, sits in the centred reading
// column (U036, at most 840 dp). The trend page uses the reading column
// too; on a phone nothing moves.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/presentation/theme/spacing.dart';

import 'f007_measurements_test.dart' show launch, tapKey;

void main() {
  for (final locale in const [Locale('en', 'US'), Locale('tr', 'TR')]) {
    for (final size in const [Size(1440, 900), Size(320, 640)]) {
      testWidgets('weight over time sits in the reading column, '
          '${locale.languageCode}, ${size.width.toInt()} dp', (tester) async {
        await launch(tester, locale: locale, size: size);
        await tapKey(tester, 'weight-trend');
        expect(find.byKey(const ValueKey('screen-trend')), findsOneWidget);
        final side = size.width > kReadingWidth
            ? (size.width - kReadingWidth) / 2
            : 0.0;
        final chip = tester.getRect(
          find.byKey(const ValueKey('trend-range-days30')),
        );
        expect(chip.left, closeTo(side + 16, 0.5));
        // Nothing of the page reaches past the reading column.
        final view = tester.getRect(find.byKey(const ValueKey('screen-trend')));
        expect(view.width, size.width);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
