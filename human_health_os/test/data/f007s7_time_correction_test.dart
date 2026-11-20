// F007-S7 (G-48, D-047): a correction can move a measurement to its true
// time, with the earlier version kept byte for byte; clock-change rules
// apply to the new time; "I did not measure this" is kept as notMeasured,
// never as a number and never as zero.
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/application/measured_at.dart';
import 'package:human_health_os/src/core/ids.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

class FixedClock implements Clock {
  FixedClock(this.t);
  DateTime t;
  @override
  DateTime nowUtc() => t = t.add(const Duration(seconds: 37));
}

/// New York, 2026: summer time from 8 March 07:00Z to 1 November 06:00Z.
final newYork = OffsetRuleZone(
  (u) =>
      !u.isBefore(DateTime.utc(2026, 3, 8, 7)) &&
          u.isBefore(DateTime.utc(2026, 11, 1, 6))
      ? const Duration(hours: -4)
      : const Duration(hours: -5),
);

/// Berlin, 2026: summer time from 29 March 01:00Z to 25 October 01:00Z.
final berlin = OffsetRuleZone(
  (u) =>
      !u.isBefore(DateTime.utc(2026, 3, 29, 1)) &&
          u.isBefore(DateTime.utc(2026, 10, 25, 1))
      ? const Duration(hours: 2)
      : const Duration(hours: 1),
);

Future<(LogRepository, MemoryLogSink, HeartbeatService, String)> fresh() async {
  final sink = MemoryLogSink();
  final repo = LogRepository(
    sink: sink,
    durability: StorageDurability.localFile,
    location: 'test',
  );
  await repo.open();
  final svc = HeartbeatService(
    repo,
    clock: FixedClock(DateTime.utc(2026, 11, 20, 12)),
  );
  final me = (await svc.ensureSelfProfile()).id;
  return (repo, sink, svc, me);
}

Matcher refused(String code, [String? field]) => throwsA(
  isA<InputError>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.field, 'field', field),
);

void main() {
  group('a correction with a new time (G-48)', () {
    test('creates a new version at the new time: lineage kept, the earlier '
        'version untouched byte for byte, the Timeline reorders', () async {
      final (repo, sink, svc, me) = await fresh();
      Future<HealthRecord> at(String when, String v) => svc.recordMeasurement(
        profileId: me,
        kind: RecordKind.restingHeartRate,
        input: MeasurementInput(value: v, when: when),
        zone: berlin,
      );
      final a = await at('2026-11-10 07:00', '61');
      await at('2026-11-12 07:00', '62');
      await at('2026-11-14 07:00', '63');
      final before = sink.text!;
      final fixed = await svc.correctMeasurement(
        profileId: me,
        targetId: a.id,
        input: const MeasurementInput(value: '61', when: '2026-11-15 07:00'),
        zone: berlin,
      );
      expect(fixed.observedAt, DateTime.utc(2026, 11, 15, 6));
      expect(fixed.supersedesId, a.id);
      expect(fixed.amendReason, AmendReason.correction);
      expect(fixed.valueStatus, ValueStatus.present);
      expect(fixed.quantity, a.quantity);
      expect(sink.text!.startsWith(before), isTrue, reason: 'append only');
      final stored = (await repo.records(me)).firstWhere((r) => r.id == a.id);
      expect(stored.toJson(), a.toJson(), reason: 'history never rewritten');
      expect(stored.observedAt, DateTime.utc(2026, 11, 10, 6));
      final entries = await svc.measurementTimeline(
        me,
        RecordKind.restingHeartRate,
      );
      expect(
        [for (final e in entries) e.shown.originalText],
        ['61', '63', '62'],
        reason: 'the corrected reading sits at its new time',
      );
      expect(entries.first.versions.map((v) => v.id), [a.id, fixed.id]);
    });

    test('blank or the stored time as typed keeps the instant exactly, '
        'seconds included; a value-only change still works', () async {
      final (_, _, svc, me) = await fresh();
      final r = await svc.recordMeasurement(
        profileId: me,
        kind: RecordKind.bodyTemperature,
        input: const MeasurementInput(value: '36,9'),
        zone: berlin,
      );
      expect(
        r.observedAt.second,
        isNot(0),
        reason: 'the save time has seconds',
      );
      final same = await svc.correctMeasurement(
        profileId: me,
        targetId: r.id,
        input: MeasurementInput(
          value: '36,8',
          when: typedInZone(r.observedAt, berlin),
        ),
        zone: berlin,
      );
      expect(same.observedAt, r.observedAt);
      final blank = await svc.correctMeasurement(
        profileId: me,
        targetId: same.id,
        input: const MeasurementInput(value: '36,7'),
        zone: berlin,
      );
      expect(blank.observedAt, r.observedAt);
    });

    test('nothing changed is refused and writes nothing; a time-only change '
        'is a correction', () async {
      final (_, sink, svc, me) = await fresh();
      final r = await svc.recordMeasurement(
        profileId: me,
        kind: RecordKind.bloodPressure,
        input: const MeasurementInput(
          systolic: '118',
          diastolic: '76',
          when: '2026-11-19 08:00',
          context: 'sitting',
        ),
        zone: newYork,
      );
      final before = sink.text;
      await expectLater(
        svc.correctMeasurement(
          profileId: me,
          targetId: r.id,
          input: const MeasurementInput(
            systolic: '118',
            diastolic: '76',
            when: '2026-11-19 08:00',
            context: 'sitting',
          ),
          zone: newYork,
        ),
        refused('NO_CHANGE'),
      );
      expect(sink.text, before);
      final moved = await svc.correctMeasurement(
        profileId: me,
        targetId: r.id,
        input: const MeasurementInput(
          systolic: '118',
          diastolic: '76',
          when: '2026-11-18 21:00',
          context: 'sitting',
        ),
        zone: newYork,
      );
      expect(moved.observedAt, DateTime.utc(2026, 11, 19, 2));
      expect(moved.details, r.details);
      expect(moved.context, 'sitting');
    });

    test('a future time, a bad format and a too old time are refused on the '
        'When field and write nothing', () async {
      final (_, sink, svc, me) = await fresh();
      final r = await svc.recordMeasurement(
        profileId: me,
        kind: RecordKind.oxygenSaturation,
        input: const MeasurementInput(value: '97', when: '2026-11-19 08:00'),
        zone: berlin,
      );
      final before = sink.text;
      for (final (typed, code) in [
        ('2026-11-20 14:00', 'FUTURE_TIME'),
        ('2099-01-01 00:00Z', 'FUTURE_TIME'),
        ('1850-01-01 00:00Z', 'TIME_TOO_OLD'),
        ('yesterday', 'TIME_FORMAT'),
      ]) {
        await expectLater(
          svc.correctMeasurement(
            profileId: me,
            targetId: r.id,
            input: MeasurementInput(value: '96', when: typed),
            zone: berlin,
          ),
          refused(code, 'when'),
          reason: typed,
        );
      }
      expect(sink.text, before);
    });

    for (final (name, zone, repeated, offsetFirst, offsetSecond, skipped) in [
      (
        'New York',
        newYork,
        '2026-11-01 01:30',
        '-04:00',
        '-05:00',
        '2026-03-08 02:30',
      ),
      (
        'Berlin',
        berlin,
        '2026-10-25 02:30',
        '+02:00',
        '+01:00',
        '2026-03-29 02:30',
      ),
    ]) {
      test('$name clock changes: an original inside the repeated hour stays '
          'as it is when its time is left alone; a new time in the repeated '
          'hour needs an offset; a skipped time is refused', () async {
        final (_, sink, svc, me) = await fresh();
        // The second (standard time) 01:30 / 02:30, chosen with an offset.
        final r = await svc.recordMeasurement(
          profileId: me,
          kind: RecordKind.restingHeartRate,
          input: MeasurementInput(value: '60', when: '$repeated $offsetSecond'),
          zone: zone,
        );
        expect(typedInZone(r.observedAt, zone), repeated);
        final kept = await svc.correctMeasurement(
          profileId: me,
          targetId: r.id,
          input: MeasurementInput(value: '59', when: repeated),
          zone: zone,
        );
        expect(kept.observedAt, r.observedAt, reason: 'not re-judged');
        final before = sink.text;
        final other = repeated.replaceFirst(':30', ':45');
        await expectLater(
          svc.correctMeasurement(
            profileId: me,
            targetId: kept.id,
            input: MeasurementInput(value: '59', when: other),
            zone: zone,
          ),
          refused('TIME_AMBIGUOUS', 'when'),
        );
        await expectLater(
          svc.correctMeasurement(
            profileId: me,
            targetId: kept.id,
            input: MeasurementInput(value: '59', when: skipped),
            zone: zone,
          ),
          refused('TIME_DOES_NOT_EXIST', 'when'),
        );
        expect(sink.text, before);
        final first = await svc.correctMeasurement(
          profileId: me,
          targetId: kept.id,
          input: MeasurementInput(value: '59', when: '$other $offsetFirst'),
          zone: zone,
        );
        // The first 01:45 / 02:45 comes an hour of real time before the
        // second 01:30 / 02:30, less 15 minutes.
        expect(
          r.observedAt.difference(first.observedAt),
          const Duration(minutes: 45),
        );
        expect(first.supersedesId, kept.id);
      });
    }
  });

  group('"I did not measure this" (D-047)', () {
    test('saved as notMeasured with no number, no details, no typed text; '
        'never zero; the time and a note are kept', () async {
      final (_, _, svc, me) = await fresh();
      for (final kind in notMeasuredKinds) {
        final r = await svc.recordMeasurement(
          profileId: me,
          kind: kind,
          input: const MeasurementInput(
            notMeasured: true,
            when: '2026-11-20 08:00',
            context: 'cuff at work',
          ),
          zone: berlin,
        );
        expect(r.valueStatus, ValueStatus.notMeasured, reason: kind.code);
        expect(r.quantity, isNull);
        expect(r.details, isNull);
        expect(r.originalText, isNull);
        expect(r.observedAt, DateTime.utc(2026, 11, 20, 7));
        expect(r.context, 'cuff at work');
        expect(r.schemaVersion, HealthRecord.writeSchemaFor(kind));
        final json = r.toJson();
        expect(json['quantity'], isNull);
        expect(json['value_status'], 'notMeasured');
        r.validate();
      }
    });

    test(
      'offered only for the routine vital signs; a typed value with it, a '
      'future time and a correction to it are refused, nothing written',
      () async {
        final (_, sink, svc, me) = await fresh();
        final before = sink.text;
        for (final kind in [RecordKind.waistCircumference, RecordKind.height]) {
          await expectLater(
            svc.recordMeasurement(
              profileId: me,
              kind: kind,
              input: const MeasurementInput(notMeasured: true),
            ),
            refused('NOT_MEASURED_NOT_OFFERED'),
          );
        }
        await expectLater(
          svc.recordMeasurement(
            profileId: me,
            kind: RecordKind.restingHeartRate,
            input: const MeasurementInput(notMeasured: true, value: '0'),
          ),
          refused('NOT_MEASURED_WITH_VALUE', 'value'),
        );
        await expectLater(
          svc.recordMeasurement(
            profileId: me,
            kind: RecordKind.bloodPressure,
            input: const MeasurementInput(notMeasured: true, diastolic: '80'),
          ),
          refused('NOT_MEASURED_WITH_VALUE', 'systolic'),
        );
        await expectLater(
          svc.recordMeasurement(
            profileId: me,
            kind: RecordKind.bloodPressure,
            input: const MeasurementInput(
              notMeasured: true,
              when: '2026-11-21 08:00Z',
            ),
          ),
          refused('FUTURE_TIME', 'when'),
        );
        expect(sink.text, before);
        final r = await svc.recordMeasurement(
          profileId: me,
          kind: RecordKind.restingHeartRate,
          input: const MeasurementInput(value: '57'),
        );
        final mid = sink.text;
        await expectLater(
          svc.correctMeasurement(
            profileId: me,
            targetId: r.id,
            input: const MeasurementInput(notMeasured: true),
          ),
          refused('NOT_MEASURED_NOT_OFFERED'),
        );
        expect(sink.text, mid);
      },
    );

    test('a "not measured" entry is never the latest value and can be '
        'corrected into a reading at its true time', () async {
      final (_, _, svc, me) = await fresh();
      await svc.recordMeasurement(
        profileId: me,
        kind: RecordKind.bloodPressure,
        input: const MeasurementInput(
          systolic: '120',
          diastolic: '80',
          when: '2026-11-19 08:00',
        ),
        zone: berlin,
      );
      final none = await svc.recordMeasurement(
        profileId: me,
        kind: RecordKind.bloodPressure,
        input: const MeasurementInput(
          notMeasured: true,
          when: '2026-11-20 08:00',
        ),
        zone: berlin,
      );
      final entries = await svc.measurementTimeline(
        me,
        RecordKind.bloodPressure,
      );
      expect(entries.first.shown.id, none.id);
      final fixed = await svc.correctMeasurement(
        profileId: me,
        targetId: none.id,
        input: const MeasurementInput(
          systolic: '122',
          diastolic: '81',
          when: '2026-11-20 09:15',
        ),
        zone: berlin,
      );
      expect(fixed.valueStatus, ValueStatus.present);
      expect(fixed.observedAt, DateTime.utc(2026, 11, 20, 8, 15));
      expect(fixed.supersedesId, none.id);
    });
  });
}
