// F004-S4 (A002) one lab test over time: Labs offers each test with more
// than one current result as a group (same name, unit and specimen as
// typed), opened by mouse or keyboard; the group lists every result newest
// first exactly as printed with its own flag, laboratory and range, draws
// only plain numbers with a spoken summary of the dated values, says why
// limits and text are not drawn, never judges (EN and TR) and fits 320 dp
// at 2x text.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

import 'f004_labs_test.dart'
    show go, interpretive, reveal, screenTexts, settle, start, textsIn;
import 'f004s2_lab_kinds_test.dart' show judgedBeyondSign;

LabInput _lab(
  String analyte,
  String value, {
  String unit = '%',
  required String date,
  String specimen = 'Kan',
  String laboratory = '',
  String flag = '',
  String range = '',
  LabValueKind kind = LabValueKind.number,
}) => LabInput(
  analyte: analyte,
  value: value,
  notReported: false,
  unit: unit,
  sampleDate: date,
  specimen: specimen,
  laboratory: laboratory,
  sourceFlag: flag,
  referenceText: range,
  kind: kind,
);

/// Four HbA1c results in % from blood at two laboratories with different
/// printed ranges (one a limit, one text), one in another unit, and a
/// differently named test that may mean the same thing.
Future<Map<String, HealthRecord>> _seed(AppServices s) async {
  final out = <String, HealthRecord>{};
  await s.heartbeat.recordLab(
    profileId: s.self.id,
    input: _lab('HbA1c', '5,4', date: '2025-01-10', range: '4,0 - 6,0'),
  );
  final wrong = await s.heartbeat.recordLab(
    profileId: s.self.id,
    input: _lab(
      'hba1c',
      '58',
      date: '2025-07-02',
      laboratory: 'Lab A',
      flag: 'H',
      range: '4.0 - 5.6',
    ),
  );
  out['corrected'] = await s.heartbeat.correctLab(
    profileId: s.self.id,
    targetId: wrong.id,
    input: _lab(
      'hba1c',
      '5,8',
      date: '2025-07-02',
      laboratory: 'Lab A',
      flag: 'H',
      range: '4.0 - 5.6',
    ),
  );
  out['censored'] = await s.heartbeat.recordLab(
    profileId: s.self.id,
    input: _lab(
      'HbA1c',
      '< 4',
      date: '2026-01-15',
      laboratory: 'Lab B',
      kind: LabValueKind.censored,
    ),
  );
  out['text'] = await s.heartbeat.recordLab(
    profileId: s.self.id,
    input: _lab(
      'HbA1c',
      'Hemolizli',
      date: '2026-03-01',
      kind: LabValueKind.text,
    ),
  );
  final gone = await s.heartbeat.recordLab(
    profileId: s.self.id,
    input: _lab('HbA1c', '9,9', date: '2026-02-01'),
  );
  await s.heartbeat.amend(
    profileId: s.self.id,
    targetId: gone.id,
    reason: AmendReason.enteredInError,
  );
  out['newest'] = await s.heartbeat.recordLab(
    profileId: s.self.id,
    input: _lab('HbA1c', '5,6', date: '2026-10-03', laboratory: 'Lab B'),
  );
  await s.heartbeat.recordLab(
    profileId: s.self.id,
    input: _lab('HbA1c', '38', unit: 'mmol/mol', date: '2026-10-03'),
  );
  await s.heartbeat.recordLab(
    profileId: s.self.id,
    input: _lab('Glikozile hemoglobin', '5,5', date: '2026-09-01'),
  );
  return out;
}

Finder _group(HealthRecord newest) =>
    find.byKey(ValueKey('lab-group-${newest.id}'));

String _chartLabel(WidgetTester tester) => tester
    .widget<Semantics>(find.byKey(const ValueKey('lab-group-chart-summary')))
    .properties
    .label!;

void main() {
  testWidgets('Labs offers the group by its name, unit and specimen as typed; '
      'one-result tests and other units are not merged in', (tester) async {
    final s = await start(tester);
    late Map<String, HealthRecord> r;
    await tester.runAsync(() async => r = await _seed(s));
    await go(tester, s, 'Labs');
    expect(find.text('Same test over time'), findsOneWidget);
    expect(
      find.text(
        'Grouped only by the same test name, unit and specimen as typed. '
        'Human OS does not guess that two different names are the same test.',
      ),
      findsOneWidget,
    );
    expect(find.text('HbA1c · % · Kan: 5 results'), findsOneWidget);
    expect(find.textContaining('mmol/mol · Kan:'), findsNothing);
    expect(find.textContaining('Glikozile hemoglobin · '), findsNothing);
    expect(_group(r['newest']!), findsOneWidget);
  });

  testWidgets('the group lists each current result newest first, as printed, '
      'with its own flag, laboratory and range', (tester) async {
    final s = await start(tester);
    late Map<String, HealthRecord> r;
    await tester.runAsync(() async => r = await _seed(s));
    await go(tester, s, 'Labs');
    await tester.tap(_group(r['newest']!));
    await settle(tester);
    expect(find.byKey(const ValueKey('screen-lab-group')), findsOneWidget);
    expect(find.text('HbA1c over time'), findsOneWidget);
    expect(find.text('Unit as typed: %'), findsOneWidget);
    expect(find.text('Specimen as typed: Kan'), findsOneWidget);

    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('lab-group-row-'),
    );
    final ids = [
      for (final w in tester.widgetList(rows))
        (w.key! as ValueKey<String>).value.substring('lab-group-row-'.length),
    ];
    expect(ids, hasLength(5), reason: 'the withdrawn 9,9 is left out');
    expect(ids.first, r['newest']!.id);
    expect(ids.indexOf(r['text']!.id), 1);
    expect(ids.indexOf(r['censored']!.id), 2);
    expect(ids.indexOf(r['corrected']!.id), 3);
    expect(find.text('9,9 %'), findsNothing);
    expect(find.text('58 %'), findsNothing, reason: 'only the correction');
    expect(find.text('5,8 %'), findsOneWidget);
    expect(find.text('below 4 % (as printed: < 4)'), findsOneWidget);
    expect(find.text('Hemolizli % (text as printed)'), findsOneWidget);
    expect(find.text('Name as typed: hba1c'), findsOneWidget);
    expect(find.text('Lab flag: H'), findsOneWidget);
    expect(find.text('Laboratory: Lab A'), findsOneWidget);
    expect(find.text('Laboratory: Lab B'), findsNWidgets(2));
    // Each result keeps its own printed range; none is merged.
    expect(
      tester
          .widget<Text>(
            find.byKey(ValueKey('lab-group-range-${r['corrected']!.id}')),
          )
          .data,
      "Lab's printed range: 4.0 - 5.6",
    );
    expect(find.text("Lab's printed range: 4,0 - 6,0"), findsOneWidget);
    expect(find.text('No range printed'), findsNWidgets(3));
  });

  testWidgets('only plain numbers are drawn; the chart says each dated value '
      'and why limits and text are not drawn', (tester) async {
    final s = await start(tester);
    late Map<String, HealthRecord> r;
    await tester.runAsync(() async => r = await _seed(s));
    await go(tester, s, 'Labs');
    await tester.tap(_group(r['newest']!));
    await settle(tester);
    expect(find.text('Values in %'), findsOneWidget);
    expect(
      _chartLabel(tester),
      'Chart of 3 number results in percent, oldest first: '
      '2025-01-10: 5,4 %; 2025-07-02: 5,8 %; 2026-10-03: 5,6 %. '
      'Every result is listed after it.',
    );
    expect(
      find.byKey(const ValueKey('lab-group-not-drawn-LAB_VALUE_CENSORED')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Printed as text (1): listed, not drawn, because text is not a '
        'number.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('No range is drawn'), findsOneWidget);
  });

  testWidgets('a group of limits and text only has no chart and says why', (
    tester,
  ) async {
    final s = await start(tester);
    late HealthRecord newest;
    await tester.runAsync(() async {
      await s.heartbeat.recordLab(
        profileId: s.self.id,
        input: _lab(
          'HBsAg',
          'Negatif',
          unit: '',
          date: '2025-01-01',
          kind: LabValueKind.text,
        ),
      );
      newest = await s.heartbeat.recordLab(
        profileId: s.self.id,
        input: _lab(
          'hbsag',
          'Negatif',
          unit: '',
          date: '2026-01-01',
          kind: LabValueKind.text,
        ),
      );
    });
    await go(tester, s, 'Labs');
    expect(
      find.text('hbsag · unit not given · Kan: 2 results'),
      findsOneWidget,
    );
    await tester.tap(_group(newest));
    await settle(tester);
    expect(find.byKey(const ValueKey('lab-group-no-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-group-chart')), findsNothing);
    expect(find.text('Unit as typed: not given'), findsOneWidget);
  });

  testWidgets('keyboard: Tab reaches the group and Enter opens it', (
    tester,
  ) async {
    final s = await start(tester);
    late Map<String, HealthRecord> r;
    await tester.runAsync(() async => r = await _seed(s));
    await go(tester, s, 'Labs');
    final button = find.descendant(
      of: _group(r['newest']!),
      matching: find.byType(InkWell),
    );
    final target = tester.element(button);
    var reached = false;
    for (var i = 0; i < 80 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx == null) continue;
      if (ctx == target) {
        reached = true;
      } else {
        ctx.visitAncestorElements((e) {
          if (e == target) reached = true;
          return !reached;
        });
      }
    }
    expect(reached, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byKey(const ValueKey('screen-lab-group')), findsOneWidget);
  });

  for (final (locale, labs, back) in [
    (const Locale('en'), 'Labs', 'HbA1c · % · Kan: 5 results'),
    (const Locale('tr'), 'Tahliller', 'HbA1c · % · Kan: 5 sonuç'),
  ]) {
    testWidgets('no judgement and a fit at 320 dp with 2x text ($locale)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final s = await start(tester, locale: locale, size: const Size(320, 640));
      late Map<String, HealthRecord> r;
      await tester.runAsync(() async => r = await _seed(s));
      await tester.pumpWidget(HumanOsApp(services: s));
      await settle(tester);
      await tester.tap(find.text(labs).last);
      await settle(tester);
      final open = _group(r['newest']!);
      await reveal(tester, open);
      expect(find.text(back), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(open);
      await settle(tester);
      expect(tester.takeException(), isNull);
      final list = find.descendant(
        of: find.byKey(const ValueKey('screen-lab-group')),
        matching: find.byType(Scrollable),
      );
      final texts = <String>{...screenTexts(tester)};
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('lab-group-chart-summary')),
        150,
        scrollable: list.first,
      );
      final spoken = _chartLabel(tester);
      for (var i = 0; i < 40; i++) {
        texts
          ..addAll(screenTexts(tester))
          ..addAll(textsIn(tester, 'lab-group-row-'));
        await tester.drag(list.first, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(texts.length, greaterThan(15), reason: 'the rows were scanned');
      // The lab's own flag ("H") and printed range are source text; every
      // other line is the app's own.
      expect(texts.where(interpretive.hasMatch), isEmpty, reason: '$texts');
      expect(texts.where(judgedBeyondSign.hasMatch), isEmpty, reason: '$texts');
      expect(
        judgedBeyondSign.hasMatch(spoken),
        isFalse,
        reason: 'the spoken summary judges nothing',
      );
      if (locale.languageCode == 'tr') {
        expect(texts, contains('Tüm sonuçlar, yeniden eskiye'));
        expect(
          texts,
          contains(
            'Metin olarak yazılmış (1): listelenir, çizilmez; metin bir sayı '
            'değildir.',
          ),
        );
        expect(spoken, startsWith('yüzde cinsinden 3 sayısal'));
      }
    });
  }
}
