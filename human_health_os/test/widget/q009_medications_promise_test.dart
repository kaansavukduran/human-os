// Q009 (full screen matrix after U045), by eye: the Medications promise
// in Turkish read "Reçete ya da hatırlatma alım değildir." ("alım" alone
// reads as a purchase as much as an intake; the sentence did not say that
// a prescription or a reminder does not mean the medicine was taken).
// Planned ≠ taken is the invariant the promise states; it must be plain
// to a reader with no prior knowledge, in both languages.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/navigation/destination_switch.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f007_measurements_test.dart' show launch, settle;

const _en =
    'A prescription or reminder is not an intake. "No interaction found" '
    'is not "safe".';
const _tr =
    'Reçete ya da hatırlatma, ilacı aldığın anlamına gelmez. '
    '"Etkileşim bulunamadı", "güvenli" demek değildir.';

void main() {
  for (final (locale, promise) in const [
    (Locale('en', 'US'), _en),
    (Locale('tr', 'TR'), _tr),
  ]) {
    testWidgets('Medications promise says a plan is not a dose taken, '
        '${locale.languageCode}', (tester) async {
      await launch(tester, locale: locale, size: const Size(390, 1600));
      tester
          .widget<DestinationSwitch>(find.byType(DestinationSwitch).first)
          .go(DestinationId.medications);
      await settle(tester);
      expect(find.text(promise), findsOneWidget);
      expect(find.textContaining('hatırlatma alım'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
