// U036: breathing room and a clear first glance.
// 1. Today lists the first few measurement kinds and every kind with a
//    record; the rest sit under "More measurements" / "Diğer ölçümler",
//    whose state is remembered (an additive appearance setting). Tile keys
//    stay the same.
// 2. On a wide window the content is one centred reading column of at most
//    840 dp (Today, the area screens and Settings).
// 3. At 320 dp and 2× text, in English and Turkish, the changed screens
//    overflow nowhere and cut no text.
// 4. The expander moves nothing under reduced motion (no animation at all),
//    and its target is at least 48 dp tall.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/features/today/measurements_card.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f007_measurements_test.dart'
    show launch, saveScalar, settle, showAllMeasurements, tapKey;
import 'u005_settings_test.dart' show launchWith;
import 'u035_text_fit_test.dart' show cutTexts, mainScroll, sweep;
import 'u039_scroll_anywhere_test.dart' show expectReadingColumn;

const _kinds = MeasurementsCard.kinds;

Finder _tile(RecordKind k) => find.byKey(ValueKey('measure-tile-${k.code}'));
final _more = find.byKey(const ValueKey('measurements-more'));

String _moreLabel(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: _more, matching: find.byType(Text)))
    .first
    .data!;

void main() {
  test('split: kinds with a record first and never under More; the first '
      'glance is filled in the person\'s order', () {
    final none = MeasurementsCard.split(_kinds, {});
    expect(none.first, _kinds.take(MeasurementsCard.firstGlance).toList());
    expect(none.more, _kinds.skip(MeasurementsCard.firstGlance).toList());

    final some = MeasurementsCard.split(_kinds, {
      RecordKind.bodyFatPercentage,
      RecordKind.height,
    });
    expect(some.first, [
      RecordKind.bloodPressure,
      RecordKind.restingHeartRate,
      RecordKind.height,
      RecordKind.bodyFatPercentage,
    ]);
    expect(some.more, isNot(contains(RecordKind.height)));
    expect(some.more, isNot(contains(RecordKind.bodyFatPercentage)));

    // More records than the first glance holds: all of them are listed.
    final many = MeasurementsCard.split(_kinds, _kinds.toSet());
    expect(many.first, _kinds);
    expect(many.more, isEmpty);
  });

  test('the expander state is an additive setting: saved, read back, and '
      'absent in an older file reads as closed', () {
    const open = AppearanceSettings(moreMeasurementsOpen: true);
    expect(AppearanceSettings.fromJson(open.toJson()), open);
    expect(
      AppearanceSettings.fromJson(open.toJson()).moreMeasurementsOpen,
      isTrue,
    );
    final older = const AppearanceSettings().toJson()
      ..remove('moreMeasurementsOpen');
    expect(AppearanceSettings.fromJson(older).moreMeasurementsOpen, isFalse);
    expect(open == const AppearanceSettings(), isFalse);
  });

  testWidgets('first glance: four kinds and "More measurements (5)"; opening '
      'it shows every kind with its key, and the choice is remembered', (
    tester,
  ) async {
    final store = MemoryAppearanceStore();
    await launchWith(tester, store: store);
    for (final k in _kinds.take(4)) {
      expect(_tile(k), findsOneWidget, reason: k.code);
    }
    for (final k in _kinds.skip(4)) {
      expect(_tile(k), findsNothing, reason: k.code);
    }
    expect(_moreLabel(tester), 'More measurements (5)');
    // One short line for the section, not a sentence per tile.
    expect(find.byKey(const ValueKey('measurements-note')), findsOneWidget);

    await tapKey(tester, 'measurements-more');
    for (final k in _kinds) {
      expect(_tile(k), findsOneWidget, reason: k.code);
    }
    expect(_moreLabel(tester), 'Fewer measurements');
    expect(store.saved?.moreMeasurementsOpen, isTrue);

    // A new start with the saved settings opens it again.
    await launchWith(tester, store: store, initial: store.saved!);
    for (final k in _kinds) {
      expect(_tile(k), findsOneWidget, reason: k.code);
    }
    await tapKey(tester, 'measurements-more');
    expect(store.saved?.moreMeasurementsOpen, isFalse);
    expect(_tile(RecordKind.bodyFatPercentage), findsNothing);
  });

  testWidgets('a kind with a record is never hidden by the expander', (
    tester,
  ) async {
    final store = MemoryAppearanceStore();
    await launchWith(tester, store: store);
    await saveScalar(tester, RecordKind.bodyFatPercentage, '21.5');
    // Saving opened More; close it again.
    if (_moreLabel(tester) == 'Fewer measurements') {
      await tapKey(tester, 'measurements-more');
    }
    expect(store.saved?.moreMeasurementsOpen, isFalse);
    expect(_tile(RecordKind.bodyFatPercentage), findsOneWidget);
    expect(_tile(RecordKind.height), findsNothing);
    // It takes one of the four first-glance places.
    expect(_tile(RecordKind.oxygenSaturation), findsNothing);
    expect(_moreLabel(tester), 'More measurements (5)');
  });

  testWidgets('Turkish: "Diğer ölçümler"', (tester) async {
    await launchWith(
      tester,
      initial: const AppearanceSettings(language: LanguageChoice.tr),
    );
    expect(_moreLabel(tester), 'Diğer ölçümler (5)');
    await tapKey(tester, 'measurements-more');
    expect(_moreLabel(tester), S(AppLang.tr).fewerMeasurements);
  });

  testWidgets('reduced motion: the expander opens in one frame, nothing '
      'slides; its target is at least 48 dp tall', (tester) async {
    await launchWith(
      tester,
      initial: const AppearanceSettings(reduceMotion: true),
    );
    expect(tester.getSize(_more).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(_more);
    await tester.pumpAndSettle();
    await tester.tap(_more);
    await tester.pump();
    for (final k in _kinds) {
      expect(_tile(k), findsOneWidget, reason: k.code);
    }
    // Already where it stays: nothing grows or slides into place.
    final at = tester.getTopLeft(_more);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_more), at);
  });

  testWidgets('desktop: Today, the area screens and Settings are one centred '
      'column of at most 840 dp', (tester) async {
    await launch(tester, size: const Size(1440, 900));
    // Since U039 the scroll view spans the body and only its content is
    // the column: 840 dp with the page padding, centred beside the rail.
    void centredColumn(String key) {
      expect(
        find.ancestor(
          of: find.byKey(ValueKey(key)),
          matching: find.byKey(const ValueKey('reading-width')),
        ),
        findsOneWidget,
        reason: key,
      );
      expectReadingColumn(tester, key);
    }

    centredColumn('screen-today');
    for (final (label, key) in [
      ('Timeline', 'screen-timeline'),
      ('Labs', 'screen-labs'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('nav-rail')),
          matching: find.text(label),
        ),
      );
      await settle(tester);
      centredColumn(key);
    }
    await tapKey(tester, 'open-settings');
    centredColumn('screen-settings');
  });

  for (final (name, locale) in [
    ('en', const Locale('en', 'US')),
    ('tr', const Locale('tr', 'TR')),
  ]) {
    testWidgets('$name, 320 dp, 2× text: Today (More open), Timeline, Labs, '
        'Medications and Settings overflow nowhere and cut no text', (
      tester,
    ) async {
      await launch(
        tester,
        locale: locale,
        size: const Size(320, 640),
        textScale: 2.0,
      );
      await showAllMeasurements(tester);
      expect(await sweep(tester, mainScroll('screen-today')), isEmpty);
      for (final (id, key) in [
        (DestinationId.timeline, 'screen-timeline'),
        (DestinationId.labs, 'screen-labs'),
        (DestinationId.medications, null),
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('nav-bar')),
            matching: find.byIcon(destinationById(id).icon),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull, reason: id.name);
        if (key != null) {
          expect(await sweep(tester, mainScroll(key)), isEmpty);
        } else {
          expect(cutTexts(tester), isEmpty, reason: id.name);
        }
      }
      await tapKey(tester, 'open-settings');
      expect(await sweep(tester, mainScroll('screen-settings')), isEmpty);
    });
  }
}
