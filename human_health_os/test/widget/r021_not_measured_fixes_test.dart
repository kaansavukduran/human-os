// R021 (F007-S7 review, D-047): a "not measured" entry can be moved to its
// true time and stays "not measured" when no number is typed (a typed
// number still turns it into a reading); its time field says when the miss
// was noted (EN and TR); in the doctor summary "not measured" entries are
// counted in one line and never take a reading's place in the list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/application/measured_at.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/features/report/doctor_summary.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import '../data/f007s7_time_correction_test.dart' show berlin, fresh, refused;
import 'f004_labs_test.dart' show interpretive, judged;
import 'f007_measurements_test.dart'
    show fill, launch, measurementJudged, openTimeline, settle, tapKey;

Future<List<HealthRecord>> _records(WidgetTester tester, AppServices s) async =>
    (await tester.runAsync(() => s.heartbeat.repository.records(s.self.id)))!;

InputDecoration _decoration(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).decoration!;

void main() {
  group('correcting a "not measured" entry (R021)', () {
    test('a time-only correction stays "not measured": no number, new time, '
        'lineage kept, the earlier version untouched', () async {
      final (repo, sink, svc, me) = await fresh();
      final none = await svc.recordMeasurement(
        profileId: me,
        kind: RecordKind.bloodPressure,
        input: const MeasurementInput(
          notMeasured: true,
          when: '2026-11-20 08:00',
          context: 'cuff at work',
        ),
        zone: berlin,
      );
      final noneJson = none.toJson();
      final fixed = await svc.correctMeasurement(
        profileId: me,
        targetId: none.id,
        input: const MeasurementInput(
          when: '2026-11-19 21:30',
          context: 'cuff at work',
        ),
        zone: berlin,
      );
      expect(fixed.valueStatus, ValueStatus.notMeasured);
      expect(fixed.quantity, isNull);
      expect(fixed.details, isNull);
      expect(fixed.originalText, isNull);
      expect(fixed.observedAt, DateTime.utc(2026, 11, 19, 20, 30));
      expect(fixed.supersedesId, none.id);
      expect(fixed.amendReason, AmendReason.correction);
      expect(fixed.context, 'cuff at work');
      fixed.validate();
      final all = await repo.records(me);
      expect(all.firstWhere((r) => r.id == none.id).toJson(), noneJson);
      final entries = await svc.measurementTimeline(
        me,
        RecordKind.bloodPressure,
      );
      expect(entries.single.shown.id, fixed.id);

      // The same time and note again changes nothing: refused, nothing written.
      final before = sink.text;
      await expectLater(
        svc.correctMeasurement(
          profileId: me,
          targetId: fixed.id,
          input: MeasurementInput(
            when: typedInZone(fixed.observedAt, berlin),
            context: 'cuff at work',
          ),
          zone: berlin,
        ),
        refused('NO_CHANGE'),
      );
      expect(sink.text, before);
      // Saying "not measured" again on it is the same thing, not a refusal.
      final noted = await svc.correctMeasurement(
        profileId: me,
        targetId: fixed.id,
        input: const MeasurementInput(notMeasured: true, context: 'forgot'),
        zone: berlin,
      );
      expect(noted.valueStatus, ValueStatus.notMeasured);
      expect(noted.observedAt, fixed.observedAt);
    });

    test('a typed number turns it into a reading; a reading still cannot '
        'become "not measured"', () async {
      final (_, sink, svc, me) = await fresh();
      final none = await svc.recordMeasurement(
        profileId: me,
        kind: RecordKind.restingHeartRate,
        input: const MeasurementInput(
          notMeasured: true,
          when: '2026-11-20 08:00',
        ),
        zone: berlin,
      );
      final fixed = await svc.correctMeasurement(
        profileId: me,
        targetId: none.id,
        input: const MeasurementInput(value: '58'),
        zone: berlin,
      );
      expect(fixed.valueStatus, ValueStatus.present);
      expect(fixed.quantity?.value, 58);
      expect(fixed.observedAt, none.observedAt);
      expect(fixed.supersedesId, none.id);
      final before = sink.text;
      await expectLater(
        svc.correctMeasurement(
          profileId: me,
          targetId: fixed.id,
          input: const MeasurementInput(notMeasured: true),
          zone: berlin,
        ),
        refused('NOT_MEASURED_NOT_OFFERED'),
      );
      expect(sink.text, before);
    });
  });

  for (final lang in [AppLang.en, AppLang.tr]) {
    testWidgets('${lang.name}: the time field of a "not measured" entry says '
        'when the miss was noted; saving a new time alone keeps it "not '
        'measured"', (tester) async {
      final s = await launch(tester, locale: Locale(lang.name));
      final strings = S(lang);
      final none = (await tester.runAsync(
        () => s.heartbeat.recordMeasurement(
          profileId: s.self.id,
          kind: RecordKind.bloodPressure,
          input: const MeasurementInput(
            notMeasured: true,
            when: '2026-10-01 07:00Z',
          ),
        ),
      ))!;
      await openTimeline(tester);
      await tapKey(tester, 'timeline-entry-${none.id}');
      await tapKey(tester, 'action-correct-${none.id}');
      final when = _decoration(tester, 'correct-input-when');
      expect(when.labelText, strings.correctWhenNotMeasuredField);
      expect(when.helperText, strings.correctWhenNotMeasuredHint);
      expect(
        _decoration(tester, 'correct-input-systolic').helperText,
        strings.correctNotMeasuredValueHint,
      );
      expect(find.text(strings.correctWhenField), findsNothing);
      await fill(tester, 'correct-input-when', '2026-09-30 19:00Z');
      await tapKey(tester, 'correct-save');
      await settle(tester);
      final all = await _records(tester, s);
      expect(all, hasLength(2));
      final fixed = all.firstWhere((r) => r.supersedesId == none.id);
      expect(fixed.valueStatus, ValueStatus.notMeasured);
      expect(fixed.details, isNull);
      expect(fixed.observedAt, DateTime.utc(2026, 9, 30, 19));
    });
  }

  test('the new strings judge nothing and differ by language', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      for (final t in [
        s.correctWhenNotMeasuredField,
        s.correctWhenNotMeasuredHint,
        s.correctNotMeasuredValueHint,
        s.summaryNotMeasured(1, '2026-11-20 08:00'),
        s.summaryNotMeasured(10, '2026-11-20 08:00'),
      ]) {
        expect(interpretive.hasMatch(t), isFalse, reason: t);
        expect(judged.hasMatch(t), isFalse, reason: t);
        expect(measurementJudged.hasMatch(t), isFalse, reason: t);
      }
    }
    expect(
      S(AppLang.en).correctWhenNotMeasuredField,
      'When you noted it was not measured',
    );
    expect(
      S(AppLang.tr).correctWhenNotMeasuredField,
      'Ölçülmediğini not ettiğin zaman',
    );
    expect(
      S(AppLang.en).summaryNotMeasured(10, 'x'),
      isNot(S(AppLang.tr).summaryNotMeasured(10, 'x')),
    );
  });

  for (final lang in [AppLang.en, AppLang.tr]) {
    testWidgets('${lang.name}: doctor summary with 25 readings and 10 "not '
        'measured" entries lists the newest 20 readings, says 20 of 25, and '
        'counts the 10 in one line', (tester) async {
      final s = await launch(tester);
      final strings = S(lang);
      await tester.runAsync(() async {
        // Readings on 1–25 September; the misses are the newest entries.
        for (var d = 1; d <= 25; d++) {
          await s.heartbeat.recordMeasurement(
            profileId: s.self.id,
            kind: RecordKind.restingHeartRate,
            input: MeasurementInput(
              value: '${50 + d}',
              when: '2026-09-${d.toString().padLeft(2, '0')} 07:00Z',
            ),
          );
        }
        for (var d = 1; d <= 10; d++) {
          await s.heartbeat.recordMeasurement(
            profileId: s.self.id,
            kind: RecordKind.restingHeartRate,
            input: MeasurementInput(
              notMeasured: true,
              when: '2026-10-${d.toString().padLeft(2, '0')} 07:00Z',
            ),
          );
        }
      });
      final summary = (await tester.runAsync(
        () => DoctorSummary.collect(s, strings),
      ))!;
      final sec = summary.sections.singleWhere(
        (x) => x.title == strings.recordKind(RecordKind.restingHeartRate),
      );
      expect(sec.rows, hasLength(rowsPerSection));
      expect(sec.total, 25);
      expect(sec.partNote, strings.summaryMore(20, 25));
      final notMeasured = strings.valueStatus(ValueStatus.notMeasured);
      expect(sec.rows.where((r) => r.value.contains(notMeasured)), isEmpty);
      expect(sec.rows.first.value, contains('75'));
      expect(sec.rows.last.value, contains('56'));
      expect(
        sec.missNote,
        strings.summaryNotMeasured(10, isoWhen(DateTime.utc(2026, 10, 10, 7))),
      );
      final html = summary.toHtml(lang.name);
      expect(html, contains(sec.missNote.replaceAll('"', '&quot;')));
      expect(RegExp('<tr>').allMatches(html), hasLength(rowsPerSection));
    });
  }
}
