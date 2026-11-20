// R022 (review of F007-S8, D-048): the chosen glucose unit is shown inside
// the value field, so it is seen while typing at 2x text on a 320 dp phone
// with the keyboard open; every measurement save is read back with its
// unit; unit chips are spoken as words and grouped with their label (entry
// sheet and Timeline correction); the trend names its unit; the body fat
// glossary entry does not claim every device uses an electric current.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/domain/guide/glossary.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import 'f007_measurements_test.dart'
    show fill, launch, openSheet, openTimeline, saveBp, saveScalar, tapKey;

const g = RecordKind.capillaryGlucose;

Future<List<HealthRecord>> _records(WidgetTester tester, AppServices s) async =>
    (await tester.runAsync(() => s.heartbeat.repository.records(s.self.id)))!;

Future<void> _seedGlucose(
  WidgetTester tester,
  AppServices s,
  String value,
  String unit, {
  String when = '2026-11-01 07:00Z',
}) => tester.runAsync(
  () => s.heartbeat.recordMeasurement(
    profileId: s.self.id,
    kind: g,
    input: MeasurementInput(value: value, unit: unit, when: when),
  ),
);

String _savedText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('measure-saved'))).data!;

/// The unit text inside the value field [field].
Finder _unitIn(String field) => find.descendant(
  of: find.byKey(ValueKey(field)),
  matching: find.byKey(ValueKey('$field-unit')),
);

void main() {
  for (final lang in [AppLang.en, AppLang.tr]) {
    testWidgets('${lang.name}: 320 dp at 2x text, keyboard open: the '
        'preselected unit of the newest reading is inside the value field, '
        'and the save reads the value back with it', (tester) async {
      final strings = S(lang);
      final s = await launch(
        tester,
        locale: Locale(lang.name),
        size: const Size(320, 5000),
        textScale: 2.0,
      );
      await _seedGlucose(tester, s, '6', 'mmol/L');
      await openSheet(tester, g);
      // A 320 x 640 phone whose keyboard takes the lower half: the unit
      // chips are below it.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      // Behind the sheet, the app shell's development banner may overflow
      // the few pixels left above this keyboard (app_shell, outside R022);
      // the sheet itself scrolls.
      tester.takeException();
      await fill(tester, 'measure-value', '5,4');
      await tester.pumpAndSettle();
      final unit = _unitIn('measure-value');
      expect(unit, findsOneWidget);
      expect(tester.widget<Text>(unit).data, 'mmol/L');
      final fieldRect = tester.getRect(
        find.byKey(const ValueKey('measure-value')),
      );
      final unitRect = tester.getRect(unit);
      expect(fieldRect.contains(unitRect.center), isTrue);
      expect(
        unitRect.bottom,
        lessThanOrEqualTo(640 - 320),
        reason: 'seen above the keyboard',
      );
      tester.view.resetViewInsets();
      tester.view.physicalSize = const Size(320, 5000);
      await tester.pumpAndSettle();
      await tapKey(tester, 'measure-save');
      expect(
        _savedText(tester),
        lang == AppLang.tr ? 'Kaydedildi: 5,4 mmol/L' : 'Saved: 5.4 mmol/L',
      );
      expect(strings.savedValue('x'), startsWith(strings.saved));
      final r = (await _records(
        tester,
        s,
      )).singleWhere((r) => r.originalText == '5,4');
      expect(r.quantity, const Quantity(5.4, 'mmol/L'));
    });
  }

  testWidgets('no unit yet: the field says so; choosing one shows it in the '
      'field; the saved text names it, spoken in words', (tester) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    final en = S(AppLang.en);
    await openSheet(tester, g);
    expect(
      tester.widget<Text>(_unitIn('measure-value')).data,
      en.unitNotChosen,
    );
    await fill(tester, 'measure-value', '95');
    await tapKey(tester, 'measure-unit-mg/dL');
    expect(tester.widget<Text>(_unitIn('measure-value')).data, 'mg/dL');
    expect(
      tester.widget<Text>(_unitIn('measure-value')).semanticsLabel,
      'milligrams per decilitre',
    );
    await tapKey(tester, 'measure-save');
    expect(_savedText(tester), 'Saved: 95 mg/dL');
    expect(
      find.bySemanticsLabel('Saved: 95 milligrams per decilitre'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('every kind: the save confirmation reads the value back with '
      'its unit; kinds with one unit have no unit inside the field', (
    tester,
  ) async {
    await launch(tester);
    await openSheet(tester, RecordKind.bodyFatPercentage);
    expect(_unitIn('measure-value'), findsNothing);
    await tapKey(tester, 'measure-cancel');
    await saveScalar(tester, RecordKind.bodyFatPercentage, '24,5');
    expect(_savedText(tester), 'Saved: 24.5 %');
    await saveScalar(tester, RecordKind.restingHeartRate, '57');
    expect(_savedText(tester), 'Saved: 57 bpm');
    await saveScalar(tester, RecordKind.bodyTemperature, '36,8');
    expect(_savedText(tester), 'Saved: 36.8 °C');
    await saveBp(tester, '118', '76');
    expect(_savedText(tester), 'Saved: 118/76 mmHg');
    await openSheet(tester, g);
    await tapKey(tester, 'measure-not-measured');
    await tapKey(tester, 'measure-save');
    expect(_savedText(tester), 'Saved: Not measured');
  });

  testWidgets('unit chips are spoken as words and grouped with "Unit your '
      'meter shows", on the entry sheet and the Timeline correction', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final s = await launch(tester);
    final en = S(AppLang.en);
    await openSheet(tester, g);
    void checkGroup(String groupKey, String chipPrefix) {
      final group = tester.getSemantics(find.byKey(ValueKey(groupKey)));
      expect(group.label, en.glucoseUnitLabel);
      final labels = <String>[];
      void walk(SemanticsNode n) {
        labels.add(n.label);
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(group);
      expect(labels, contains(contains('millimoles per litre')));
      expect(labels, contains(contains('milligrams per decilitre')));
      expect(
        labels.where((l) => l == en.glucoseUnitLabel),
        hasLength(1),
        reason: 'the label is said once, by the group',
      );
      for (final u in ['mg/dL', 'mmol/L']) {
        final chip = tester.getSemantics(find.byKey(ValueKey('$chipPrefix$u')));
        expect(chip.label, isNot(contains(u)), reason: 'not letter by letter');
      }
    }

    checkGroup('measure-unit-group', 'measure-unit-');
    await fill(tester, 'measure-value', '5,3');
    await tapKey(tester, 'measure-unit-mmol/L');
    await tapKey(tester, 'measure-save');
    final head = (await _records(tester, s)).single;
    await openTimeline(tester);
    await tapKey(tester, 'timeline-entry-${head.id}');
    await tapKey(tester, 'action-correct-${head.id}');
    checkGroup('correct-unit-group', 'correct-unit-');
    semantics.dispose();
  });

  for (final lang in [AppLang.en, AppLang.tr]) {
    testWidgets('${lang.name}: the trend names its one unit over the chart '
        'and in the spoken summary', (tester) async {
      final semantics = tester.ensureSemantics();
      final strings = S(lang);
      final s = await launch(tester, locale: Locale(lang.name));
      await _seedGlucose(tester, s, '5,5', 'mmol/L');
      await _seedGlucose(tester, s, '6', 'mmol/L', when: '2026-11-02 07:00Z');
      await openSheet(tester, g);
      await tapKey(tester, 'measure-trend');
      final s2 = S.of(
        tester.element(find.byKey(const ValueKey('screen-trend'))),
      );
      expect(s2.lang, lang);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend-axis-unit'))).data,
        strings.trendAxisUnit('mmol/L'),
      );
      final summary = tester.getSemantics(
        find.byKey(const ValueKey('trend-chart-summary')),
      );
      expect(
        summary.label,
        strings.trendChartSpoken(2, unit: strings.spokenUnit('mmol/L')),
      );
      expect(
        summary.label,
        contains(
          lang == AppLang.tr ? 'litrede milimol' : 'millimoles per litre',
        ),
      );
      semantics.dispose();
    });
  }

  test('body fat glossary: many scales use a small current, not every '
      'device; natural EN and TR', () {
    final e = glossaryForKind(RecordKind.bodyFatPercentage.code)!;
    expect(
      e.what.$1,
      contains('Many scales estimate it from a small electric current'),
    );
    expect(e.what.$1, isNot(contains('The device calculates it from')));
    expect(e.what.$1, contains('other devices work differently'));
    expect(e.what.$2, contains('Birçok tartı bunu zayıf bir elektrik akımı'));
    expect(e.what.$2, isNot(contains('Cihaz bunu')));
  });
}
