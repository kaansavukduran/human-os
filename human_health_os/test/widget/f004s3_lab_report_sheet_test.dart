// F004-S3 (G-28, D-045) Labs sheet: "More from the report" (report time,
// method, the reference interval as printed) collapsed by default, errors
// opening it and focusing the right field, rows and the Timeline restating
// the details plainly with no comparing word (EN and TR), corrections
// opening with the stored details, and the sheet at 320 dp with 2x text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

import 'f004_labs_test.dart'
    show
        fill,
        go,
        interpretive,
        judged,
        reveal,
        screenTexts,
        settle,
        start,
        tapKey,
        textsIn;

/// Words that would relate a value to its interval (G-28 brief).
final RegExp comparing = RegExp(
  r'(?<!\p{L})(within|inside|outside|normal|abnormal|in range|'
  r'out of range|aralıkta|dışında|aralık dışı)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

const moreFields = [
  'lab-report-time',
  'lab-method',
  'lab-ref-low',
  'lab-ref-high',
  'lab-ref-unit',
  'lab-ref-partition',
];

bool focused(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).focusNode!.hasFocus;

String textOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

Future<void> openMore(WidgetTester tester) async {
  if (find.byKey(const ValueKey('lab-report-time')).evaluate().isEmpty) {
    await tapKey(tester, 'lab-more');
  }
}

Future<void> fillBasics(WidgetTester tester) async {
  await fill(tester, 'lab-analyte', 'HbA1c');
  await fill(tester, 'lab-value', '5,4');
  await fill(tester, 'lab-unit', '%');
  await fill(tester, 'lab-date', '2026-10-03');
}

void main() {
  testWidgets('the section is collapsed by default; a tap opens it with the '
      'fields, the plain reference-interval note and its glossary link', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final s = await start(tester);
    await go(tester, s, 'Labs');
    await tapKey(tester, 'lab-add');
    expect(find.text('More from the report'), findsOneWidget);
    for (final k in moreFields) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    final toggle = find.byKey(const ValueKey('lab-more'));
    bool? expanded() =>
        tester.getSemantics(toggle).flagsCollection.isExpanded.toBoolOrNull();
    expect(expanded(), isFalse);
    await tapKey(tester, 'lab-more');
    for (final k in moreFields) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    expect(expanded(), isTrue);
    final form = find.byKey(const ValueKey('lab-form'));
    expect(
      find.descendant(
        of: form,
        matching: find.byKey(const ValueKey('term-reference_interval')),
      ),
      findsOneWidget,
    );
    final note = tester.widget<Text>(
      find.byKey(const ValueKey('lab-interval-explain')),
    );
    expect(note.data, contains('not a target and not a limit for decisions'));
    expect(note.data, contains('never compares your value with it'));
    // Collapsing hides the fields again; Save and Cancel never moved.
    await tapKey(tester, 'lab-more');
    expect(find.byKey(const ValueKey('lab-method')), findsNothing);
    expect(find.byKey(const ValueKey('lab-save')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('every detail is saved and the row restates it plainly, with no '
      'comparing word; the Timeline shows it too', (tester) async {
    final s = await start(tester);
    await go(tester, s, 'Labs');
    await tapKey(tester, 'lab-add');
    await fillBasics(tester);
    await fill(tester, 'lab-range', '4,0 - 6,0');
    await openMore(tester);
    await fill(tester, 'lab-report-time', '2026-10-04 14:20');
    await fill(tester, 'lab-method', 'HPLC');
    await fill(tester, 'lab-ref-low', '4,0');
    await fill(tester, 'lab-ref-high', '6,0');
    await fill(tester, 'lab-ref-unit', '%');
    await fill(tester, 'lab-ref-partition', 'Kadın 20-49 yaş');
    await tapKey(tester, 'lab-save');
    expect(find.byKey(const ValueKey('lab-saved')), findsOneWidget);
    final r = (await tester.runAsync(() => s.heartbeat.labTimeline(s.self.id)))!
        .single
        .shown;
    expect(r.schemaVersion, 15);
    expect(r.lab!.referenceText, '4,0 - 6,0');
    expect(r.lab!.method, 'HPLC');
    expect(r.lab!.referenceInterval!.partition, 'Kadın 20-49 yaş');
    expect(find.text('Method as printed: HPLC'), findsOneWidget);
    expect(
      find.text('Reference interval as printed: 4,0–6,0 % (Kadın 20-49 yaş)'),
      findsOneWidget,
    );
    expect(find.textContaining('Report time: '), findsOneWidget);
    expect(find.text('Lab\'s printed range: 4,0 - 6,0'), findsOneWidget);
    final row = textsIn(tester, 'lab-row-');
    expect(row.where(comparing.hasMatch), isEmpty, reason: '$row');
    expect(row.where(judged.hasMatch), isEmpty, reason: '$row');
    expect(screenTexts(tester).where(interpretive.hasMatch), isEmpty);

    await go(tester, s, 'Timeline');
    final line = find.byKey(ValueKey('timeline-lab-report-${r.id}'));
    expect(line, findsOneWidget);
    final t = tester.widget<Text>(line).data!;
    expect(t, contains('Method as printed: HPLC'));
    expect(t, contains('Reference interval as printed: 4,0–6,0 %'));
    expect(comparing.hasMatch(t), isFalse);
    expect(judged.hasMatch(t), isFalse);
  });

  testWidgets('a refused detail opens the collapsed section and focuses the '
      'field it is about', (tester) async {
    final s = await start(tester);
    await go(tester, s, 'Labs');
    await tapKey(tester, 'lab-add');
    await fillBasics(tester);
    for (final (fields, focus, message) in [
      (
        {'lab-ref-low': '6,0', 'lab-ref-high': '4,0', 'lab-ref-unit': '%'},
        'lab-ref-low',
        'low number is larger than the high number',
      ),
      (
        {'lab-ref-low': '4,0', 'lab-ref-high': '6,0', 'lab-ref-unit': ''},
        'lab-ref-unit',
        'Add the unit printed with the reference interval',
      ),
      (
        {'lab-ref-low': '', 'lab-ref-high': '< 130', 'lab-ref-unit': '%'},
        'lab-ref-high',
        'put 130 in High',
      ),
      (
        {'lab-ref-high': '', 'lab-ref-unit': '', 'lab-report-time': '4 Oct'},
        'lab-report-time',
        '24-hour clock',
      ),
      (
        {'lab-report-time': '2026-10-02 10:00'},
        'lab-report-time',
        'before the sample date',
      ),
    ]) {
      await openMore(tester);
      for (final e in fields.entries) {
        await fill(tester, e.key, e.value);
      }
      // Collapse the section, so the error has to open it again.
      await tapKey(tester, 'lab-more');
      expect(find.byKey(ValueKey(focus)), findsNothing);
      await tapKey(tester, 'lab-save');
      final error = find.byKey(const ValueKey('lab-error'));
      expect(error, findsOneWidget, reason: focus);
      expect(tester.widget<Text>(error).data, contains(message));
      expect(find.byKey(ValueKey(focus)), findsOneWidget, reason: message);
      expect(focused(tester, focus), isTrue, reason: message);
    }
    expect(
      await tester.runAsync(() => s.heartbeat.labTimeline(s.self.id)),
      isEmpty,
    );
  });

  testWidgets('a correction opens the section with the stored details; the '
      'report time stays for the next result of the same report', (
    tester,
  ) async {
    final s = await start(tester);
    late HealthRecord first;
    await tester.runAsync(() async {
      first = await s.heartbeat.recordLab(
        profileId: s.self.id,
        input: const LabInput(
          analyte: 'LDL',
          value: '142',
          notReported: false,
          unit: 'mg/dL',
          sampleDate: '2026-10-03',
          method: 'enzimatik',
          refHigh: '130',
          refUnit: 'mg/dL',
        ),
      );
    });
    await go(tester, s, 'Labs');
    expect(
      find.text('Reference interval as printed: upper bound 130 mg/dL'),
      findsOneWidget,
    );
    await tapKey(tester, 'lab-correct-${first.id}');
    expect(find.byKey(const ValueKey('lab-method')), findsOneWidget);
    expect(textOf(tester, 'lab-method'), 'enzimatik');
    expect(textOf(tester, 'lab-ref-high'), '130');
    expect(textOf(tester, 'lab-ref-low'), '');
    await fill(tester, 'lab-ref-low', '0');
    await tapKey(tester, 'lab-save');
    expect(
      find.text('Reference interval as printed: 0–130 mg/dL'),
      findsOneWidget,
    );

    // A new result: collapsed, empty.
    await tapKey(tester, 'lab-add');
    expect(find.byKey(const ValueKey('lab-method')), findsNothing);
    await openMore(tester);
    for (final k in moreFields) {
      expect(textOf(tester, k), '', reason: k);
    }
    await fill(tester, 'lab-analyte', 'HDL');
    await fill(tester, 'lab-value', '55');
    await fill(tester, 'lab-date', '2026-10-03');
    await fill(tester, 'lab-report-time', '2026-10-04 09:00');
    await tapKey(tester, 'lab-save');
    // The next result of the same report keeps the report time, and the
    // collapsed section says one field is filled.
    await tapKey(tester, 'lab-add');
    expect(find.byKey(const ValueKey('lab-report-time')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('lab-more-note'))).data,
      '1 field filled',
    );
    await openMore(tester);
    expect(textOf(tester, 'lab-report-time'), '2026-10-04 09:00');
  });

  for (final (locale, labs, timeline, interval, method) in [
    (
      const Locale('en'),
      'Labs',
      'Timeline',
      'Reference interval as printed: -2 – 2 mmol/L (adult)',
      'Method as printed: HPLC',
    ),
    (
      const Locale('tr'),
      'Lab',
      'Zaman çizelgesi',
      'Raporda yazan referans aralığı: -2 – 2 mmol/L (adult)',
      'Raporda yazan yöntem: HPLC',
    ),
  ]) {
    testWidgets('rows and the Timeline restate the details, no comparing word '
        '($locale)', (tester) async {
      final s = await start(tester, locale: locale);
      await tester.runAsync(() async {
        await s.heartbeat.recordLab(
          profileId: s.self.id,
          input: const LabInput(
            analyte: 'Base excess',
            value: '-3',
            notReported: false,
            unit: 'mmol/L',
            sampleDate: '2026-10-03',
            method: 'HPLC',
            refLow: '-2',
            refHigh: '2',
            refUnit: 'mmol/L',
            refPartition: 'adult',
          ),
        );
      });
      await go(tester, s, labs);
      expect(find.text(interval), findsOneWidget);
      expect(find.text(method), findsOneWidget);
      final rows = textsIn(tester, 'lab-row-');
      expect(rows.where(comparing.hasMatch), isEmpty, reason: '$rows');
      expect(rows.where(judged.hasMatch), isEmpty, reason: '$rows');
      expect(screenTexts(tester).where(interpretive.hasMatch), isEmpty);
      await go(tester, s, timeline);
      final entries = textsIn(tester, 'timeline-');
      expect(entries.any((t) => t.contains(interval)), isTrue);
      expect(entries.where(comparing.hasMatch), isEmpty, reason: '$entries');
    });

    testWidgets('the sheet with the section open fits 320 dp at 2x text '
        '($locale)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final s = await start(tester, locale: locale, size: const Size(320, 640));
      await tester.pumpWidget(HumanOsApp(services: s));
      await settle(tester);
      await tester.tap(find.text(labs).last);
      await settle(tester);
      await tapKey(tester, 'lab-add');
      expect(tester.takeException(), isNull);
      await fill(tester, 'lab-analyte', 'Hemoglobin A1c (IFCC)');
      await fill(tester, 'lab-value', '5,4');
      await fill(tester, 'lab-unit', '%');
      await fill(tester, 'lab-date', '2026-10-03');
      await openMore(tester);
      expect(tester.takeException(), isNull);
      await fill(tester, 'lab-report-time', '2026-10-04 14:20');
      await fill(tester, 'lab-method', 'Sıvı kromatografisi (HPLC), kolon B');
      await fill(tester, 'lab-ref-low', '4,0');
      await fill(tester, 'lab-ref-high', '6,0');
      await fill(tester, 'lab-ref-unit', '%');
      await fill(tester, 'lab-ref-partition', 'Kadın 20-49 yaş, gebe değil');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'lab-save');
      expect(find.byKey(const ValueKey('lab-error')), findsNothing);
      await reveal(tester, find.byKey(const ValueKey('lab-saved')));
      expect(find.byKey(const ValueKey('lab-saved')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
