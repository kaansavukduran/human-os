// F004-S2 (G-26, D-043) Labs sheet: "Kind of result" chips (Number, below
// or above a limit, text as printed), the value field changing with them,
// errors focusing the value field, rows and the Timeline showing the value
// exactly as printed without judgement (EN and TR), corrections for every
// kind, and the sheet at 320 dp with 2x text.
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

/// [judged] without the words that only restate the printed sign of a
/// censored value ("below 5" for "< 5"): those describe how the report
/// printed it, not a comparison with a range. Every other judging word is
/// still refused.
final RegExp judgedBeyondSign = RegExp(
  r'(?<!\p{L})(high|low|outside|within|in range|out of range|'
  r'elevated|raised|optimal|good|bad|critical|ok|yüksek|düşük|üstünde|altında|'
  r'aralık dışı|aralıkta|iyi|kötü|kritik)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

bool selected(WidgetTester tester, LabValueKind k) => tester
    .widget<ChoiceChip>(find.byKey(ValueKey('lab-kind-${k.code}')))
    .selected;

bool valueFocused(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('lab-value')))
    .focusNode!
    .hasFocus;

Future<void> pick(WidgetTester tester, LabValueKind k) async {
  final f = find.byKey(ValueKey('lab-kind-${k.code}'));
  await reveal(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

String helperOfValue(WidgetTester tester) =>
    tester
        .widget<TextField>(find.byKey(const ValueKey('lab-value')))
        .decoration!
        .helperText ??
    '';

String labelOfValue(WidgetTester tester) =>
    tester
        .widget<TextField>(find.byKey(const ValueKey('lab-value')))
        .decoration!
        .labelText ??
    '';

void main() {
  testWidgets('the kind starts at Number; choosing another changes the value '
      'field and its examples', (tester) async {
    final s = await start(tester);
    await go(tester, s, 'Labs');
    await tapKey(tester, 'lab-add');
    expect(selected(tester, LabValueKind.number), isTrue);
    expect(selected(tester, LabValueKind.censored), isFalse);
    expect(find.text('Kind of result'), findsOneWidget);
    expect(labelOfValue(tester), 'Value');

    await pick(tester, LabValueKind.censored);
    expect(selected(tester, LabValueKind.censored), isTrue);
    expect(selected(tester, LabValueKind.number), isFalse);
    expect(labelOfValue(tester), 'Sign and number as printed');
    expect(helperOfValue(tester), contains('< 5'));
    expect(helperOfValue(tester), contains('never as the number itself'));

    await pick(tester, LabValueKind.text);
    expect(labelOfValue(tester), 'Result as printed');
    expect(helperOfValue(tester), contains('Pozitif'));
    expect(helperOfValue(tester), contains('gives it no meaning'));
  });

  testWidgets('a censored result is saved and listed as printed: "below 5 '
      'mg/dL (as printed: < 5)", with no judgement', (tester) async {
    final s = await start(tester);
    await go(tester, s, 'Labs');
    await tapKey(tester, 'lab-add');
    await fill(tester, 'lab-analyte', 'CRP');
    await pick(tester, LabValueKind.censored);
    await fill(tester, 'lab-value', '< 5');
    await fill(tester, 'lab-unit', 'mg/dL');
    await fill(tester, 'lab-date', '2026-10-03');
    await fill(tester, 'lab-range', '0 - 5');
    await tapKey(tester, 'lab-save');
    expect(find.byKey(const ValueKey('lab-saved')), findsOneWidget);
    expect(find.text('below 5 mg/dL (as printed: < 5)'), findsOneWidget);
    final row = textsIn(tester, 'lab-row-');
    expect(row.where(judgedBeyondSign.hasMatch), isEmpty, reason: '$row');
    expect(screenTexts(tester).where(interpretive.hasMatch), isEmpty);
    final r = (await tester.runAsync(() => s.heartbeat.labTimeline(s.self.id)))!
        .single
        .shown;
    expect(r.quantity, isNull, reason: 'never stored as 5');
    expect(r.lab!.result!.limitText, '5');
  });

  testWidgets('a text result is listed verbatim with "(text as printed)"', (
    tester,
  ) async {
    final s = await start(tester);
    await go(tester, s, 'Labs');
    await tapKey(tester, 'lab-add');
    await fill(tester, 'lab-analyte', 'HBsAg');
    await pick(tester, LabValueKind.text);
    await fill(tester, 'lab-value', 'Reaktif değil');
    await fill(tester, 'lab-date', '2026-10-03');
    await tapKey(tester, 'lab-save');
    expect(find.text('Reaktif değil (text as printed)'), findsOneWidget);
    expect(find.textContaining('unit not given'), findsNothing);
    final row = textsIn(tester, 'lab-row-');
    expect(row.where(judged.hasMatch), isEmpty, reason: '$row');
  });

  testWidgets('a refused value names the problem and moves focus to the '
      'value field, for each kind', (tester) async {
    final s = await start(tester);
    await go(tester, s, 'Labs');
    await tapKey(tester, 'lab-add');
    await fill(tester, 'lab-analyte', 'CRP');
    await fill(tester, 'lab-date', '2026-10-03');
    for (final (kind, typed, message) in [
      (LabValueKind.number, '< 5', 'Choose "Below or above a limit" above.'),
      (LabValueKind.number, '5 mg/dL', 'unit in "Unit as printed"'),
      (LabValueKind.censored, '<', 'Add the number after the sign'),
      (LabValueKind.censored, '5', 'Start with the sign as printed'),
      (LabValueKind.text, '5,4', 'Choose "Number" above'),
      (LabValueKind.text, '', 'Empty is not saved as 0'),
    ]) {
      await pick(tester, kind);
      await fill(tester, 'lab-value', typed);
      // Focus elsewhere first, so the move to the value field is seen.
      await tester.tap(find.byKey(const ValueKey('lab-analyte')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'lab-save');
      final error = find.byKey(const ValueKey('lab-error'));
      expect(error, findsOneWidget, reason: typed);
      expect(
        tester.widget<Text>(error).data,
        contains(message),
        reason: '$kind "$typed"',
      );
      expect(valueFocused(tester), isTrue, reason: '$kind "$typed"');
    }
    final saved = await tester.runAsync(
      () => s.heartbeat.labTimeline(s.self.id),
    );
    expect(saved, isEmpty);
  });

  testWidgets('correcting opens with the stored kind and moves between '
      'kinds; the Timeline keeps the earlier version', (tester) async {
    final s = await start(tester);
    late HealthRecord first;
    await tester.runAsync(() async {
      first = await s.heartbeat.recordLab(
        profileId: s.self.id,
        input: const LabInput(
          analyte: 'Ferritin',
          value: '> 1000',
          notReported: false,
          unit: 'ng/mL',
          sampleDate: '2026-10-03',
          kind: LabValueKind.censored,
        ),
      );
    });
    await go(tester, s, 'Labs');
    expect(find.text('above 1000 ng/mL (as printed: > 1000)'), findsOneWidget);
    await tapKey(tester, 'lab-correct-${first.id}');
    expect(selected(tester, LabValueKind.censored), isTrue);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('lab-value')))
          .controller!
          .text,
      '> 1000',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('lab-unit')))
          .controller!
          .text,
      'ng/mL',
    );
    await fill(tester, 'lab-value', '>=1000');
    await tapKey(tester, 'lab-save');
    expect(
      find.text('at or above 1000 ng/mL (as printed: >=1000)'),
      findsOneWidget,
    );
    final second = (await tester.runAsync(
      () => s.heartbeat.labTimeline(s.self.id),
    ))!.single.shown;

    // Then to a plain number.
    await tapKey(tester, 'lab-correct-${second.id}');
    await pick(tester, LabValueKind.number);
    await fill(tester, 'lab-value', '1200');
    await tapKey(tester, 'lab-save');
    expect(find.text('1200 ng/mL'), findsOneWidget);
    // After a save the add form starts again at Number.
    await tapKey(tester, 'lab-add');
    expect(selected(tester, LabValueKind.number), isTrue);
    await tapKey(tester, 'lab-cancel');

    await go(tester, s, 'Timeline');
    await tester.tap(find.byKey(ValueKey('timeline-entry-${first.id}')));
    await settle(tester);
    final detail = find.byKey(const ValueKey('timeline-detail'));
    expect(
      find.descendant(
        of: detail,
        matching: find.text('above 1000 ng/mL (as printed: > 1000)'),
      ),
      findsOneWidget,
    );
  });

  for (final (locale, labs, timeline, censored, text) in [
    (
      const Locale('en'),
      'Labs',
      'Timeline',
      'at or below 0,1 (unit not given; as printed: <=0,1)',
      '1+ (text as printed)',
    ),
    (
      const Locale('tr'),
      'Lab',
      'Zaman çizelgesi',
      '0,1 ve altı (birim verilmedi; raporda: <=0,1)',
      '1+ (raporda yazan metin)',
    ),
  ]) {
    testWidgets('rows and the Timeline read as printed, no judgement '
        '($locale)', (tester) async {
      final s = await start(tester, locale: locale);
      await tester.runAsync(() async {
        await s.heartbeat.recordLab(
          profileId: s.self.id,
          input: const LabInput(
            analyte: 'Troponin',
            value: '<=0,1',
            notReported: false,
            unit: '',
            sampleDate: '2026-10-03',
            kind: LabValueKind.censored,
          ),
        );
        await s.heartbeat.recordLab(
          profileId: s.self.id,
          input: const LabInput(
            analyte: 'Protein (idrar)',
            value: '1+',
            notReported: false,
            unit: '',
            sampleDate: '2026-10-03',
            kind: LabValueKind.text,
          ),
        );
      });
      await go(tester, s, labs);
      expect(find.text(censored), findsOneWidget);
      expect(find.text(text), findsOneWidget);
      expect(screenTexts(tester).where(interpretive.hasMatch), isEmpty);
      final rows = textsIn(tester, 'lab-row-');
      expect(rows.where(judgedBeyondSign.hasMatch), isEmpty, reason: '$rows');
      await go(tester, s, timeline);
      expect(find.text(censored), findsOneWidget);
      expect(find.text(text), findsOneWidget);
      expect(screenTexts(tester).where(interpretive.hasMatch), isEmpty);
      final entries = textsIn(tester, 'timeline-entry-');
      expect(
        entries.where(judgedBeyondSign.hasMatch),
        isEmpty,
        reason: '$entries',
      );
    });
  }

  for (final (locale, labs) in [
    (const Locale('en'), 'Labs'),
    (const Locale('tr'), 'Lab'),
  ]) {
    testWidgets('the sheet fits 320 dp at 2x text with every kind ($locale)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final s = await start(tester, locale: locale, size: const Size(320, 640));
      await tester.pumpWidget(HumanOsApp(services: s));
      await settle(tester);
      await tester.tap(find.text(labs).last);
      await settle(tester);
      await tapKey(tester, 'lab-add');
      await fill(tester, 'lab-analyte', 'Hemoglobin A1c (IFCC)');
      for (final k in LabValueKind.values) {
        await pick(tester, k);
        expect(selected(tester, k), isTrue);
        expect(tester.takeException(), isNull, reason: '$k');
      }
      await fill(tester, 'lab-value', 'Reaktif değil');
      await fill(tester, 'lab-date', '2026-10-03');
      await tapKey(tester, 'lab-save');
      await reveal(tester, find.byKey(const ValueKey('lab-saved')));
      expect(find.byKey(const ValueKey('lab-saved')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
