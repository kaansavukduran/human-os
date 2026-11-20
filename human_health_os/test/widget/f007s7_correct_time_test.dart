// F007-S7 (G-48, D-047) on screen: the Timeline correction opens with the
// stored value and time, a new time moves the reading there with the
// earlier version kept and "time corrected from … to …" in its versions
// (EN and TR); a future time is refused; "I did not measure this" on Today
// is saved as "Not measured", never a number and never zero; 320 dp at 2x
// text in both languages.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/features/timeline/timeline_screen.dart'
    show fmtWhen;
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/presentation/widgets/sheet_parts.dart';

import 'f004_labs_test.dart' show interpretive, judged;
import 'f007_measurements_test.dart'
    show
        fill,
        latestOf,
        launch,
        measurementJudged,
        openSheet,
        openTimeline,
        saveScalar,
        settle,
        tapKey,
        textsUnder;

Future<List<HealthRecord>> _records(WidgetTester tester, AppServices s) async =>
    (await tester.runAsync(() => s.heartbeat.repository.records(s.self.id)))!;

Future<HealthRecord> _head(
  WidgetTester tester,
  AppServices s,
  RecordKind kind,
  String text,
) async {
  final entries = (await tester.runAsync(
    () => s.heartbeat.measurementTimeline(s.self.id, kind),
  ))!;
  return entries.firstWhere((e) => e.shown.originalText == text).shown;
}

String _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

void main() {
  for (final lang in [AppLang.en, AppLang.tr]) {
    testWidgets('${lang.name}: a correction opens with the value and time; a '
        'new time moves the reading there, keeps the earlier version and says '
        '"time corrected from … to …"', (tester) async {
      final s = await launch(tester, locale: Locale(lang.name));
      final strings = S(lang);
      await saveScalar(
        tester,
        RecordKind.restingHeartRate,
        '61',
        when: '2026-10-01 07:00Z',
      );
      await saveScalar(
        tester,
        RecordKind.restingHeartRate,
        '62',
        when: '2026-10-03 07:00Z',
      );
      final original = await _head(
        tester,
        s,
        RecordKind.restingHeartRate,
        '61',
      );
      final originalJson = original.toJson();
      final unit = lang == AppLang.tr ? 'atım/dk' : 'bpm';
      await openTimeline(tester);
      expect(
        tester.getTopLeft(find.text('62 $unit')).dy,
        lessThan(tester.getTopLeft(find.text('61 $unit')).dy),
      );
      await tester.tap(find.text('61 $unit'));
      await settle(tester);
      await tapKey(tester, 'action-correct-${original.id}');
      expect(_field(tester, 'correct-input'), '61', reason: 'as typed');
      expect(
        _field(tester, 'correct-input-when'),
        typedLocal(original.observedAt),
      );
      await fill(tester, 'correct-input-when', '2026-10-04 07:00Z');
      await tapKey(tester, 'correct-save');

      final all = await _records(tester, s);
      expect(all, hasLength(3));
      final fixed = all.firstWhere((r) => r.supersedesId == original.id);
      expect(fixed.observedAt, DateTime.utc(2026, 10, 4, 7));
      expect(fixed.quantity, original.quantity);
      expect(
        all.firstWhere((r) => r.id == original.id).toJson(),
        originalJson,
        reason: 'the earlier version is never rewritten',
      );
      expect(
        tester.getTopLeft(find.text('61 $unit')).dy,
        lessThan(tester.getTopLeft(find.text('62 $unit')).dy),
        reason: 'the Timeline places it at its new time',
      );
      await tester.tap(find.text('61 $unit'));
      await settle(tester);
      final versions = textsUnder(
        tester,
        find.byKey(const ValueKey('timeline-detail')),
      ).join('\n');
      final line = strings.timeCorrected(
        fmtWhen(original.observedAt),
        fmtWhen(fixed.observedAt),
      );
      expect(versions, contains(line));
      expect(
        line,
        lang == AppLang.tr
            ? startsWith('ölçüm zamanı ')
            : startsWith('time corrected from '),
      );
    });
  }

  testWidgets('a future time in a correction is refused on the When field and '
      'nothing is written; the quick picks fill the field, "Keep this time" '
      'restores it', (tester) async {
    final s = await launch(tester);
    await saveScalar(
      tester,
      RecordKind.bodyTemperature,
      '36,9',
      when: '2026-10-01 07:00Z',
    );
    final head = await _head(tester, s, RecordKind.bodyTemperature, '36,9');
    await openTimeline(tester);
    await tester.tap(find.text('36.9 °C'));
    await settle(tester);
    await tapKey(tester, 'action-correct-${head.id}');
    await tapKey(tester, 'correct-when-pick-1 hour ago');
    expect(
      _field(tester, 'correct-input-when'),
      isNot(typedLocal(head.observedAt)),
    );
    await tapKey(tester, 'correct-when-pick-Keep this time');
    expect(_field(tester, 'correct-input-when'), typedLocal(head.observedAt));
    await fill(tester, 'correct-input-when', '2099-01-01 00:00Z');
    await tapKey(tester, 'correct-save');
    expect(find.text('This date is in the future.'), findsOneWidget);
    expect(await _records(tester, s), hasLength(1));
    await fill(tester, 'correct-input-when', typedLocal(head.observedAt));
    await tapKey(tester, 'correct-save');
    expect(find.text('Nothing to change.'), findsOneWidget);
    expect(await _records(tester, s), hasLength(1));
  });

  testWidgets('"I did not measure this": the numbers are hidden, the save is '
      '"Not measured" with no number, never 0; Latest keeps the last value '
      'and says the missed one in words; not offered for waist', (
    tester,
  ) async {
    final s = await launch(tester);
    await openSheet(tester, RecordKind.waistCircumference);
    expect(find.byKey(const ValueKey('measure-not-measured')), findsNothing);
    await tapKey(tester, 'measure-cancel');

    await openSheet(tester, RecordKind.bloodPressure);
    await fill(tester, 'measure-systolic', '120');
    await tapKey(tester, 'measure-not-measured');
    expect(find.byKey(const ValueKey('measure-systolic')), findsNothing);
    expect(find.byKey(const ValueKey('measure-diastolic')), findsNothing);
    expect(find.text(S(AppLang.en).notMeasuredHelp), findsOneWidget);
    await tapKey(tester, 'measure-save');
    final all = await _records(tester, s);
    final none = all.singleWhere((r) => r.kind == RecordKind.bloodPressure);
    expect(none.valueStatus, ValueStatus.notMeasured);
    expect(none.quantity, isNull);
    expect(none.details, isNull, reason: 'the typed 120 was not sent');
    expect(latestOf(tester, RecordKind.bloodPressure), 'Not recorded yet');
    final missed = tester
        .widget<Text>(
          find.byKey(
            const ValueKey('measure-not-measured-vital.blood_pressure'),
          ),
        )
        .data!;
    expect(missed, 'Not measured ${fmtWhen(none.observedAt)}');
    await openTimeline(tester);
    final rows = textsUnder(
      tester,
      find.byKey(ValueKey('timeline-entry-${none.id}')),
    ).join(' ');
    expect(rows, contains('Not measured'));
    expect(rows, isNot(contains(' 0 ')));
    expect(rows, isNot(contains('mmHg')), reason: 'no number, no unit');
  });

  testWidgets('Turkish: "Bunu ölçmedim" saves "Ölçülmedi"', (tester) async {
    final s = await launch(tester, locale: const Locale('tr'));
    await openSheet(tester, RecordKind.restingHeartRate);
    expect(find.text('Bunu ölçmedim'), findsOneWidget);
    await tapKey(tester, 'measure-not-measured');
    await tapKey(tester, 'measure-save');
    final none = (await _records(tester, s)).single;
    expect(none.valueStatus, ValueStatus.notMeasured);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('measure-not-measured-vital.resting_heart_rate'),
            ),
          )
          .data,
      'Ölçülmedi: ${fmtWhen(none.observedAt)}',
    );
  });

  test('the new strings judge nothing in either language and differ by '
      'language', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      for (final t in [
        s.timeCorrected('a', 'b'),
        s.correctWhenField,
        s.correctWhenHint,
        s.presetKeepTime,
        s.notMeasuredToggle,
        s.notMeasuredHelp,
        s.notMeasuredOn('a'),
        s.inputError('NOT_MEASURED_WITH_VALUE'),
        s.inputError('NOT_MEASURED_NOT_OFFERED'),
      ]) {
        expect(interpretive.hasMatch(t), isFalse, reason: t);
        expect(judged.hasMatch(t), isFalse, reason: t);
        expect(measurementJudged.hasMatch(t), isFalse, reason: t);
        expect(RegExp(r'\b0\b').hasMatch(t), isFalse, reason: t);
      }
    }
    expect(S(AppLang.en).notMeasuredHelp, isNot(S(AppLang.tr).notMeasuredHelp));
  });

  testWidgets('320 dp at 2x text: the not-measured sheet and the correction '
      'with its time fit (EN and TR)', (tester) async {
    for (final locale in [const Locale('en'), const Locale('tr')]) {
      final s = await launch(
        tester,
        locale: locale,
        size: const Size(320, 4000),
        textScale: 2.0,
      );
      await openSheet(tester, RecordKind.bloodPressure);
      await tapKey(tester, 'measure-not-measured');
      expect(tester.takeException(), isNull, reason: '$locale sheet');
      await tapKey(tester, 'measure-save');
      await saveScalar(
        tester,
        RecordKind.restingHeartRate,
        '57',
        when: '2026-10-01 07:00Z',
      );
      final head = await _head(tester, s, RecordKind.restingHeartRate, '57');
      // No navigation rail at 320 dp: the save message leads there.
      await tapKey(tester, 'measure-show-timeline');
      await tapKey(tester, 'timeline-entry-${head.id}');
      await tapKey(tester, 'action-correct-${head.id}');
      await fill(tester, 'correct-input-when', '2026-10-02 07:00Z');
      await tapKey(tester, 'correct-save');
      expect(tester.takeException(), isNull, reason: '$locale correction');
      expect((await _records(tester, s)), hasLength(3));
    }
  });
}
