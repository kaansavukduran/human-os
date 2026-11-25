// Q005: the screen matrix found "kilo" on Turkish screens after U041 made
// "ağırlık" the one word for body weight (L001; the card is "Vücut
// ağırlığı", its field "Ağırlık (kg)"): first run's welcome said
// "kilo, tansiyon" and Settings said "Ölçümler kilo kartından önce".
// Both now say "ağırlık". Checked in EN and TR at 320 dp with 2× text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart'
    show MemoryAppearanceStore;
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f007_measurements_test.dart' show tapKey;
import 'u014_first_run_test.dart' show launchReal;
import 'u035_text_fit_test.dart' show mainScroll, small, sweep;

/// "kilo" as a word of its own or a stem ("kilonu"), not "kilogram".
final RegExp _kilo = RegExp(
  r'(?<!\p{L})kilo(?!gram)\p{L}*',
  caseSensitive: false,
  unicode: true,
);

void main() {
  test('tr: first run and Settings name body weight "ağırlık"', () {
    const s = S(AppLang.tr);
    expect(s.firstWelcomeBody, contains('ağırlık, tansiyon'));
    expect(s.settingsMeasurementsFirst, 'Ölçümler ağırlık kartından önce');
    for (final t in [s.firstWelcomeBody, s.settingsMeasurementsFirst]) {
      expect(_kilo.hasMatch(t), isFalse, reason: t);
    }
    // The card the Settings line refers to says the same word.
    expect(s.weightTitle, contains('ağırlığı'));
  });

  test('tr: no area text names body weight "kilo"', () {
    for (final d in [...destinations, ...plannedDestinations]) {
      for (final t in [
        d.tr,
        d.purposeTr,
        d.principleTr,
        d.canDoTr,
        d.emptyStateTr ?? '',
      ]) {
        expect(_kilo.hasMatch(t), isFalse, reason: t);
      }
    }
    final today = destinations.firstWhere((d) => d.id == DestinationId.today);
    expect(today.canDoTr, startsWith('Ağırlığını, '));
  });

  test('en: the same two texts are unchanged', () {
    const s = S(AppLang.en);
    expect(
      s.firstWelcomeBody,
      startsWith(
        'A place for your own health '
        'numbers: weight, blood pressure',
      ),
    );
    expect(s.settingsMeasurementsFirst, 'Measurements before the weight card');
  });

  for (final (locale, word) in [
    (const Locale('en', 'US'), 'weight, blood pressure'),
    (const Locale('tr', 'TR'), 'ağırlık, tansiyon'),
  ]) {
    testWidgets('first run, ${locale.languageCode}, 320 dp, 2× text: the '
        'welcome says $word and cuts nothing', (tester) async {
      await launchReal(tester, MemoryAppearanceStore());
      tester.view.physicalSize = small;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.localesTestValue = [locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpAndSettle();
      final body = find.textContaining(word);
      await tester.scrollUntilVisible(
        body,
        100,
        scrollable: mainScroll('screen-first-run'),
      );
      expect(body, findsOneWidget);
      expect(find.textContaining(_kilo), findsNothing);
      tester
          .state<ScrollableState>(mainScroll('screen-first-run'))
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final cut = await sweep(tester, mainScroll('screen-first-run'));
      expect(cut, isEmpty, reason: '$cut');
      // The second step does not bring the word back either.
      await tapKey(tester, 'first-next');
      expect(find.textContaining(_kilo), findsNothing);
    });
  }
}
