// F007-S8 (part of G-42, D-048) on screen: blood glucose with the unit the
// meter shows (chosen, never guessed or converted) and an optional meal
// timing; body fat as the device showed it. Errors land on their field;
// the unit of the newest reading is offered next time; the Timeline shows
// and corrects them; the doctor summary lists them; "not measured" for
// glucose only; no judgement words (EN and TR); 320 dp at 2x text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/presentation/widgets/whole_chip.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/features/report/doctor_summary.dart';
import 'package:human_health_os/src/features/trends/trend_screen.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import 'f004_labs_test.dart' show interpretive, judged;
import 'f007_measurements_test.dart'
    show
        fill,
        latestOf,
        launch,
        measurementJudged,
        openSheet,
        openTimeline,
        settle,
        showAllMeasurements,
        tapKey,
        textsUnder;

const g = RecordKind.capillaryGlucose;
const fat = RecordKind.bodyFatPercentage;

Future<List<HealthRecord>> _records(WidgetTester tester, AppServices s) async =>
    (await tester.runAsync(() => s.heartbeat.repository.records(s.self.id)))!;

bool _chosen(WidgetTester tester, String key) =>
    tester.widget<WholeChip>(find.byKey(ValueKey(key))).selected;

/// Saves a glucose from Today: the value, then the unit and timing chips.
Future<void> saveGlucose(
  WidgetTester tester,
  String value, {
  String? unit,
  GlucoseTiming? timing,
}) async {
  await openSheet(tester, g);
  await fill(tester, 'measure-value', value);
  if (unit != null) await tapKey(tester, 'measure-unit-$unit');
  if (timing != null) await tapKey(tester, 'measure-timing-${timing.code}');
  await tapKey(tester, 'measure-save');
}

void _noJudgement(List<String> texts) {
  for (final t in texts) {
    expect(judged.hasMatch(t), isFalse, reason: t);
    expect(interpretive.hasMatch(t), isFalse, reason: t);
    expect(measurementJudged.hasMatch(t), isFalse, reason: t);
    expect(
      RegExp(
        r'diabet|hypo|hyper|şeker hastal',
        caseSensitive: false,
      ).hasMatch(t),
      isFalse,
      reason: t,
    );
  }
}

void main() {
  for (final lang in [AppLang.en, AppLang.tr]) {
    testWidgets('${lang.name}: glucose needs a unit (the error is on the '
        'unit, which takes focus); saved as typed with its timing; the unit '
        'is offered next time; no judgement', (tester) async {
      final s = await launch(tester, locale: Locale(lang.name));
      final strings = S(lang);
      await showAllMeasurements(tester);
      expect(latestOf(tester, g), strings.measurementNotYet);
      await openSheet(tester, g);
      expect(
        find.byKey(const ValueKey('measure-not-measured')),
        findsOneWidget,
      );
      expect(_chosen(tester, 'measure-unit-mg/dL'), isFalse);
      expect(_chosen(tester, 'measure-unit-mmol/L'), isFalse);
      expect(find.text(strings.measurementHint(g)!), findsOneWidget);
      final sheet = textsUnder(
        tester,
        find.byKey(const ValueKey('measure-sheet-glucose.capillary')),
      );
      _noJudgement(sheet);
      await fill(tester, 'measure-value', '5,3');
      await tapKey(tester, 'measure-save');
      expect(
        find.text(strings.inputError('UNIT_CHOICE_REQUIRED')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('measure-unit-error')), findsOneWidget);
      final chip = find.descendant(
        of: find.byKey(const ValueKey('measure-unit-mg/dL')),
        matching: find.byType(Focus),
      );
      expect(
        tester
            .widgetList<Focus>(chip)
            .any((f) => f.focusNode?.hasFocus ?? false),
        isTrue,
        reason: 'the unit choice takes focus',
      );
      expect(await _records(tester, s), isEmpty, reason: 'nothing saved');
      await tapKey(tester, 'measure-unit-mmol/L');
      await tapKey(tester, 'measure-timing-fasting');
      await tapKey(tester, 'measure-save');
      final shown = latestOf(tester, g);
      expect(
        shown,
        lang == AppLang.tr ? '5,3 mmol/L · Aç karnına' : '5.3 mmol/L · Fasting',
      );
      _noJudgement([shown]);
      final r = (await _records(tester, s)).single;
      expect(r.quantity, const Quantity(5.3, 'mmol/L'));
      expect(r.originalText, '5,3');
      expect(r.details, const GlucoseTimingDetails(GlucoseTiming.fasting));

      // Next time the meter's unit is already chosen; the timing is not.
      await openSheet(tester, g);
      expect(_chosen(tester, 'measure-unit-mmol/L'), isTrue);
      expect(_chosen(tester, 'measure-timing-fasting'), isFalse);
      await tapKey(tester, 'measure-cancel');
    });
  }

  testWidgets('body fat: named as the device showed it, saved as reported, '
      'above 100 refused on the value field; no "not measured"', (
    tester,
  ) async {
    final s = await launch(tester);
    await openSheet(tester, fat);
    expect(find.byKey(const ValueKey('measure-not-measured')), findsNothing);
    expect(find.byKey(const ValueKey('measure-unit-%')), findsNothing);
    expect(find.text(S(AppLang.en).measurementHint(fat)!), findsOneWidget);
    await fill(tester, 'measure-value', '101');
    await tapKey(tester, 'measure-save');
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('measure-value')),
    );
    expect(
      field.decoration!.errorText,
      S(AppLang.en).inputError('OUT_OF_DEFINITION'),
    );
    expect(field.focusNode!.hasFocus, isTrue, reason: 'the error takes focus');
    await fill(tester, 'measure-value', '24,5');
    await tapKey(tester, 'measure-save');
    expect(latestOf(tester, fat), '24.5 %');
    expect(find.text('Body fat, as the device showed'), findsWidgets);
    final r = (await _records(tester, s)).single;
    expect(r.state, RecordState.reported);
  });

  testWidgets('Timeline: rows as typed; a glucose correction opens with its '
      'unit and timing; a new timing is a new version; "not measured" glucose '
      'reads "Not measured"', (tester) async {
    final s = await launch(tester);
    await saveGlucose(
      tester,
      '7,8',
      unit: 'mmol/L',
      timing: GlucoseTiming.afterMeal,
    );
    await openSheet(tester, g);
    await tapKey(tester, 'measure-not-measured');
    expect(find.byKey(const ValueKey('measure-unit-mmol/L')), findsNothing);
    expect(find.byKey(const ValueKey('measure-timing-fasting')), findsNothing);
    await tapKey(tester, 'measure-save');
    final reading = (await _records(
      tester,
      s,
    )).firstWhere((r) => r.valueStatus == ValueStatus.present);
    final miss = (await _records(
      tester,
      s,
    )).firstWhere((r) => r.valueStatus == ValueStatus.notMeasured);
    expect(latestOf(tester, g), '7.8 mmol/L · After a meal');

    await openTimeline(tester);
    final row = textsUnder(
      tester,
      find.byKey(ValueKey('timeline-entry-${reading.id}')),
    ).join(' ');
    expect(row, contains('7.8 mmol/L · After a meal'));
    expect(row, contains('Blood glucose'));
    final missRow = textsUnder(
      tester,
      find.byKey(ValueKey('timeline-entry-${miss.id}')),
    ).join(' ');
    expect(missRow, contains('Not measured'));
    expect(missRow, isNot(contains('mmol')));

    await tapKey(tester, 'timeline-entry-${reading.id}');
    await tapKey(tester, 'action-correct-${reading.id}');
    expect(_chosen(tester, 'correct-unit-mmol/L'), isTrue);
    expect(_chosen(tester, 'correct-timing-after_meal'), isTrue);
    await fill(tester, 'correct-input', '6,8');
    await tapKey(tester, 'correct-timing-fasting');
    await tapKey(tester, 'correct-save');
    final all = await _records(tester, s);
    final fixed = all.singleWhere((r) => r.supersedesId == reading.id);
    expect(fixed.quantity, const Quantity(6.8, 'mmol/L'));
    expect(fixed.details, const GlucoseTimingDetails(GlucoseTiming.fasting));
    expect(fixed.observedAt, reading.observedAt);
    expect(find.text('6.8 mmol/L · Fasting'), findsWidgets);
  });

  for (final lang in [AppLang.en, AppLang.tr]) {
    testWidgets('${lang.name}: doctor summary rows for glucose and body fat, '
        'as typed with the timing and note; misses counted in one line', (
      tester,
    ) async {
      final s = await launch(tester);
      final strings = S(lang);
      await tester.runAsync(() async {
        await s.heartbeat.recordMeasurement(
          profileId: s.self.id,
          kind: g,
          input: const MeasurementInput(
            value: '95',
            unit: 'mg/dL',
            glucoseTiming: GlucoseTiming.fasting,
            context: 'before breakfast',
            when: '2026-11-01 07:00Z',
          ),
        );
        await s.heartbeat.recordMeasurement(
          profileId: s.self.id,
          kind: g,
          input: const MeasurementInput(
            notMeasured: true,
            when: '2026-11-02 07:00Z',
          ),
        );
        await s.heartbeat.recordMeasurement(
          profileId: s.self.id,
          kind: fat,
          input: const MeasurementInput(
            value: '24,5',
            when: '2026-11-01 07:05Z',
          ),
        );
      });
      final summary = (await tester.runAsync(
        () => DoctorSummary.collect(s, strings),
      ))!;
      final gs = summary.sections.singleWhere(
        (x) => x.title == strings.recordKind(g),
      );
      expect(
        gs.rows.single.value,
        '95 mg/dL · ${strings.glucoseTiming(GlucoseTiming.fasting)}',
      );
      expect(gs.rows.single.note, 'before breakfast');
      expect(gs.total, 1);
      expect(gs.missNote, isNotEmpty);
      final fs = summary.sections.singleWhere(
        (x) => x.title == strings.recordKind(fat),
      );
      expect(fs.rows.single.value, lang == AppLang.tr ? '24,5 %' : '24.5 %');
      _noJudgement([
        gs.title,
        fs.title,
        for (final r in [...gs.rows, ...fs.rows]) r.value,
        gs.missNote,
      ]);
    });
  }

  testWidgets('trend: glucose in two units draws the newest unit only and '
      'says the rest are listed, never converted', (tester) async {
    final s = await launch(tester);
    await tester.runAsync(() async {
      for (final (v, u, d) in [
        ('100', 'mg/dL', '01'),
        ('5,5', 'mmol/L', '02'),
        ('6', 'mmol/L', '03'),
      ]) {
        await s.heartbeat.recordMeasurement(
          profileId: s.self.id,
          kind: g,
          input: MeasurementInput(value: v, unit: u, when: '2026-11-$d 07:00Z'),
        );
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: TrendScreen(services: s, kind: g),
      ),
    );
    await settle(tester);
    expect(
      find.text(S(AppLang.en).trendOtherUnits('mmol/L', 1)),
      findsOneWidget,
    );
    expect(find.textContaining('100 mg/dL'), findsOneWidget);
    expect(minSpanFor(g, 'mmol/L'), 1);
    expect(minSpanFor(g, 'mg/dL'), 20);
    expect(minSpanFor(fat), 5);
  });

  testWidgets('320 dp at 2x text: both sheets, the unit error and a glucose '
      'correction fit (EN and TR)', (tester) async {
    for (final locale in [const Locale('en'), const Locale('tr')]) {
      final s = await launch(
        tester,
        locale: locale,
        size: const Size(320, 5000),
        textScale: 2.0,
      );
      await openSheet(tester, g);
      await fill(tester, 'measure-value', '95');
      await tapKey(tester, 'measure-save');
      expect(tester.takeException(), isNull, reason: '$locale unit error');
      await tapKey(tester, 'measure-unit-mg/dL');
      await tapKey(tester, 'measure-timing-after_meal');
      expect(tester.takeException(), isNull, reason: '$locale glucose sheet');
      await tapKey(tester, 'measure-save');
      await openSheet(tester, fat);
      expect(tester.takeException(), isNull, reason: '$locale body fat sheet');
      await fill(tester, 'measure-value', '24,5');
      await tapKey(tester, 'measure-save');
      final head = (await _records(tester, s)).firstWhere((r) => r.kind == g);
      await tapKey(tester, 'measure-show-timeline');
      await tapKey(tester, 'timeline-entry-${head.id}');
      await tapKey(tester, 'action-correct-${head.id}');
      expect(tester.takeException(), isNull, reason: '$locale correction');
      await tapKey(tester, 'correct-unit-mmol/L');
      await fill(tester, 'correct-input', '5,3');
      await tapKey(tester, 'correct-save');
      expect(tester.takeException(), isNull, reason: '$locale saved');
      expect(await _records(tester, s), hasLength(3));
    }
  });
}
