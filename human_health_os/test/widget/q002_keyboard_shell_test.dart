// Q002: at 320x640 with 2× text, the on-screen keyboard open over a
// measurement entry sheet left the app shell behind it too short for the
// build profile banner, and its column overflowed (EN and TR).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

import 'f007_measurements_test.dart' show launch, openSheet, settle;

void main() {
  for (final locale in [const Locale('en', 'US'), const Locale('tr', 'TR')]) {
    testWidgets('${locale.languageCode}: 320x640, 2× text, keyboard open over '
        'an entry sheet: the shell behind it does not overflow', (
      tester,
    ) async {
      await launch(
        tester,
        locale: locale,
        size: const Size(320, 640),
        textScale: 2.0,
      );
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('measure-tile-${RecordKind.bloodPressure.code}')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('screen-today')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await openSheet(tester, RecordKind.bloodPressure);
      expect(
        find.byKey(ValueKey('measure-sheet-${RecordKind.bloodPressure.code}')),
        findsOneWidget,
      );
      // The keyboard opens: the window's bottom inset grows.
      tester.view.viewInsets = const FakeViewPadding(bottom: 420);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
