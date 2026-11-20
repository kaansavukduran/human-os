// F007-S8 (part of G-42, D-048): blood glucose from a finger-prick meter and
// body fat as a home scale showed it, typed by hand. Glucose is kept in the
// unit chosen (mg/dL or mmol/L), never converted; its meal timing is the
// person's label, never interpreted; body fat is the device's estimate
// (state reported). Entry rules per kind and unit, the record rules of
// schema 16, not measured, persistence with the upgrade checkpoint, the
// fixture, backup and restore, and that older builds refuse the new data.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/application/measured_at.dart';
import 'package:human_health_os/src/core/ids.dart';
import 'package:human_health_os/src/data/backup/backup_bundle.dart';
import 'package:human_health_os/src/data/backup/data_files.dart';
import 'package:human_health_os/src/data/backup/data_files_io.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/data/local/storage_io.dart';
import 'package:human_health_os/src/data/local/vault_log.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/profile/profile.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/trends/trend.dart';
import 'package:human_health_os/src/features/measurements/measurement_format.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import '../widget/f004_labs_test.dart' show interpretive, judged;

const fixture15 = 'test/fixtures/vault/v1_f004s3_schema15.hhoslog.jsonl';
const fixture16 = 'test/fixtures/vault/v1_f007s8_schema16.hhoslog.jsonl';
const me = '00000000-0000-4000-8000-0000000000a1';
final t0 = DateTime.utc(2026, 11, 20, 9);

class _At implements Clock {
  DateTime t = t0;
  @override
  DateTime nowUtc() => t = t.add(const Duration(seconds: 41));
}

final utc = OffsetRuleZone((_) => Duration.zero);

const g = RecordKind.capillaryGlucose;
const fat = RecordKind.bodyFatPercentage;

/// Words that would judge a glucose or body fat value, or name a diagnosis.
final RegExp diabetesWords = RegExp(
  r'(diabet\p{L}*|prediabet\p{L}*|hypo\p{L}*|hyper\p{L}*|insulin\p{L}*|'
  r'şeker hastal\p{L}*|obez\p{L}*|obes\p{L}*|overweight|fazla kilo|ideal|target|hedef)',
  caseSensitive: false,
  unicode: true,
);

Matcher input(String code, [String? field]) => throwsA(
  isA<InputError>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.field, 'field', field),
);

Matcher rule(String code) =>
    throwsA(isA<RecordValidationError>().having((e) => e.code, 'code', code));

LogRepository fileRepo(File f) => LogRepository(
  sink: FileLogSink(f),
  durability: StorageDurability.localFile,
  location: f.path,
);

List<String> jsonOf(Iterable<HealthRecord> rs) => [
  for (final r in rs) jsonEncode(r.toJson()),
];

Future<(LogRepository, MemoryLogSink, HeartbeatService)> fresh() async {
  final sink = MemoryLogSink();
  final repo = LogRepository(
    sink: sink,
    durability: StorageDurability.localFile,
    location: 'test',
  );
  await repo.open();
  final svc = HeartbeatService(repo, clock: _At());
  await repo.putProfile(Profile(id: me, type: ProfileType.self, createdAt: t0));
  return (repo, sink, svc);
}

HealthRecord stored(
  RecordKind kind, {
  Quantity? q,
  RecordDetails? details,
  int schema = 16,
  ValueStatus status = ValueStatus.present,
}) => HealthRecord(
  id: 'm1',
  profileId: 'p',
  kind: kind,
  state: RecordState.observed,
  valueStatus: status,
  quantity: q,
  originalText: q == null ? null : '${q.value}',
  provenance: const Provenance.manual(),
  observedAt: t0,
  recordedAt: t0,
  details: details,
  schemaVersion: schema,
);

void main() {
  group('kinds and units (D-048)', () {
    test('glucose takes mg/dL or mmol/L, body fat %; both new at 16', () {
      expect(g.code, 'glucose.capillary');
      expect(fat.code, 'body.fat_percentage');
      expect(g.units, ['mg/dL', 'mmol/L']);
      expect(g.unit, isNull, reason: 'no single canonical unit');
      expect(fat.units, ['%']);
      expect(RecordKind.height.units, ['cm']);
      expect(RecordKind.labResult.units, isEmpty);
      for (final k in [g, fat]) {
        expect(k.minSchema, 16);
        expect(k.isMeasurement, isTrue);
        expect(k.isStructured, isFalse);
        expect(HealthRecord.writeSchemaFor(k), 16);
      }
      expect(HealthRecord.currentSchemaVersion, 16);
      expect(fat.isDeviceEstimate, isTrue);
      expect(g.isDeviceEstimate, isFalse);
      expect(notMeasuredKinds, contains(g));
      expect(notMeasuredKinds, isNot(contains(fat)));
    });
  });

  group('entry: glucose', () {
    test('each unit is kept as chosen with the typed text; the TR comma '
        'works; nothing is converted', () async {
      final (_, _, svc) = await fresh();
      final a = await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(value: '95', unit: 'mg/dL'),
      );
      expect(a.quantity, const Quantity(95, 'mg/dL'));
      expect(a.originalText, '95');
      expect(a.state, RecordState.observed);
      expect(a.provenance.kind, ProvenanceKind.manual);
      expect(a.details, isNull, reason: 'no timing chosen, no details');
      expect(a.schemaVersion, 16);
      final b = await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(
          value: '5,3',
          unit: 'mmol/L',
          glucoseTiming: GlucoseTiming.fasting,
        ),
      );
      expect(b.quantity, const Quantity(5.3, 'mmol/L'));
      expect(b.originalText, '5,3');
      expect(b.details, const GlucoseTimingDetails(GlucoseTiming.fasting));
      expect(b.toJson()['details'], {
        'type': 'glucose_timing',
        'timing': 'fasting',
      });
      // A number that looks like the other unit is still kept as chosen:
      // the app never guesses a unit from the number.
      final c = await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(value: '95', unit: 'mmol/L'),
      );
      expect(c.quantity, const Quantity(95, 'mmol/L'));
    });

    test('refusals name their field and save nothing', () async {
      final (repo, sink, svc) = await fresh();
      final before = sink.text;
      Future<HealthRecord> save(MeasurementInput i) =>
          svc.recordMeasurement(profileId: me, kind: g, input: i);
      expect(
        () => save(const MeasurementInput(value: '95')),
        input('UNIT_CHOICE_REQUIRED', 'unit'),
      );
      expect(
        () => save(const MeasurementInput(value: '95', unit: 'mg/dl')),
        input('UNIT_NOT_SUPPORTED', 'unit'),
      );
      expect(
        () => save(const MeasurementInput(value: '5.3', unit: 'g/L')),
        input('UNIT_NOT_SUPPORTED', 'unit'),
      );
      expect(
        () => save(const MeasurementInput(unit: 'mg/dL')),
        input('EMPTY', 'value'),
      );
      expect(
        () => save(const MeasurementInput(value: '0', unit: 'mg/dL')),
        input('NOT_POSITIVE', 'value'),
      );
      expect(
        () => save(const MeasurementInput(value: '95 mg/dL', unit: 'mg/dL')),
        input('NOT_A_NUMBER', 'value'),
      );
      expect(
        () => save(const MeasurementInput(value: '1,234', unit: 'mg/dL')),
        input('AMBIGUOUS_SEPARATOR', 'value'),
      );
      expect(
        () => save(const MeasurementInput(value: '-5', unit: 'mmol/L')),
        input('NOT_A_NUMBER', 'value'),
      );
      expect(sink.text, before);
      expect(await repo.records(me, kind: g), isEmpty);
    });

    test('no plausibility bound: a large number in either unit is kept as '
        'typed (structural checks only)', () async {
      final (_, _, svc) = await fresh();
      final r = await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(value: '600', unit: 'mg/dL'),
      );
      expect(r.quantity!.value, 600);
      final s = await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(value: '1,5', unit: 'mmol/L'),
      );
      expect(s.quantity!.value, 1.5);
    });

    test('a timing for another kind is a programming error', () async {
      final (_, _, svc) = await fresh();
      expect(
        () => svc.recordMeasurement(
          profileId: me,
          kind: fat,
          input: const MeasurementInput(
            value: '20',
            glucoseTiming: GlucoseTiming.fasting,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('entry: body fat', () {
    test('kept as the device showed it: %, the typed text, state reported '
        '(an estimate, never an observed fact)', () async {
      final (_, _, svc) = await fresh();
      final r = await svc.recordMeasurement(
        profileId: me,
        kind: fat,
        input: const MeasurementInput(value: '24,5', unit: 'mg/dL'),
      );
      expect(r.quantity, const Quantity(24.5, '%'), reason: 'one unit only');
      expect(r.originalText, '24,5');
      expect(r.state, RecordState.reported);
      expect(r.provenance.kind, ProvenanceKind.manual);
      expect(r.schemaVersion, 16);
    });

    test('above 100 is refused at entry (definitional); a stored 101 loads '
        'and is never re-judged', () async {
      final (_, _, svc) = await fresh();
      expect(
        () => svc.recordMeasurement(
          profileId: me,
          kind: fat,
          input: const MeasurementInput(value: '100,5'),
        ),
        input('OUT_OF_DEFINITION', 'value'),
      );
      expect(
        (await svc.recordMeasurement(
          profileId: me,
          kind: fat,
          input: const MeasurementInput(value: '100'),
        )).quantity!.value,
        100,
      );
      final old = stored(fat, q: const Quantity(101, '%'));
      old.validate();
      expect(HealthRecord.fromJson(old.toJson()).quantity!.value, 101);
    });

    test('"not measured" is not offered for body fat', () async {
      final (_, _, svc) = await fresh();
      expect(
        () => svc.recordMeasurement(
          profileId: me,
          kind: fat,
          input: const MeasurementInput(notMeasured: true),
        ),
        input('NOT_MEASURED_NOT_OFFERED'),
      );
    });
  });

  group('not measured: glucose (D-047, D-048)', () {
    test('saved with no number, no unit and no timing; never zero', () async {
      final (_, _, svc) = await fresh();
      final r = await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(notMeasured: true),
      );
      expect(r.valueStatus, ValueStatus.notMeasured);
      expect(r.quantity, isNull);
      expect(r.details, isNull);
      expect(r.schemaVersion, 16);
      expect(
        () => svc.recordMeasurement(
          profileId: me,
          kind: g,
          input: const MeasurementInput(
            notMeasured: true,
            glucoseTiming: GlucoseTiming.fasting,
          ),
        ),
        input('NOT_MEASURED_WITH_VALUE', 'timing'),
      );
      expect(
        () => svc.recordMeasurement(
          profileId: me,
          kind: g,
          input: const MeasurementInput(
            notMeasured: true,
            value: '5',
            unit: 'mmol/L',
          ),
        ),
        input('NOT_MEASURED_WITH_VALUE', 'value'),
      );
      // Not a trend point and not the latest value.
      final entries = await svc.measurementTimeline(me, g);
      expect(trendPoints(entries), isEmpty);
      expect(latestWithValue(entries), isNull);
    });

    test('a "not measured" glucose corrected into a reading needs a unit; '
        'with no number typed it stays "not measured"', () async {
      final (_, _, svc) = await fresh();
      final miss = await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(notMeasured: true),
      );
      expect(
        () => svc.correctMeasurement(
          profileId: me,
          targetId: miss.id,
          input: const MeasurementInput(value: '6,1'),
        ),
        input('UNIT_CHOICE_REQUIRED', 'unit'),
      );
      final fixed = await svc.correctMeasurement(
        profileId: me,
        targetId: miss.id,
        input: const MeasurementInput(
          value: '6,1',
          unit: 'mmol/L',
          glucoseTiming: GlucoseTiming.afterMeal,
        ),
      );
      expect(fixed.valueStatus, ValueStatus.present);
      expect(fixed.quantity, const Quantity(6.1, 'mmol/L'));
      expect(fixed.supersedesId, miss.id);
    });
  });

  group('corrections', () {
    test(
      'a glucose correction keeps the stored unit unless another is '
      'chosen; a timing change alone is a change; no change is refused',
      () async {
        final (_, sink, svc) = await fresh();
        final a = await svc.recordMeasurement(
          profileId: me,
          kind: g,
          input: const MeasurementInput(
            value: '7,8',
            unit: 'mmol/L',
            glucoseTiming: GlucoseTiming.afterMeal,
          ),
        );
        final before = sink.text!;
        final b = await svc.correctMeasurement(
          profileId: me,
          targetId: a.id,
          input: const MeasurementInput(
            value: '6,8',
            glucoseTiming: GlucoseTiming.afterMeal,
          ),
        );
        expect(b.quantity, const Quantity(6.8, 'mmol/L'));
        expect(b.amendReason, AmendReason.correction);
        expect(b.observedAt, a.observedAt);
        expect(sink.text!.startsWith(before), isTrue, reason: 'append-only');
        final c = await svc.correctMeasurement(
          profileId: me,
          targetId: b.id,
          input: const MeasurementInput(
            value: '6,8',
            unit: 'mmol/L',
            glucoseTiming: GlucoseTiming.fasting,
          ),
        );
        expect(c.details, const GlucoseTimingDetails(GlucoseTiming.fasting));
        final d = await svc.correctMeasurement(
          profileId: me,
          targetId: c.id,
          input: const MeasurementInput(value: '6,8', unit: 'mmol/L'),
        );
        expect(d.details, isNull, reason: 'the timing was cleared');
        expect(
          () => svc.correctMeasurement(
            profileId: me,
            targetId: d.id,
            input: const MeasurementInput(value: '6,8', unit: 'mmol/L'),
          ),
          input('NO_CHANGE'),
        );
        // Choosing the other unit is a correction of what the meter showed,
        // never a conversion: the number stays as typed.
        final e = await svc.correctMeasurement(
          profileId: me,
          targetId: d.id,
          input: const MeasurementInput(value: '6,8', unit: 'mg/dL'),
        );
        expect(e.quantity, const Quantity(6.8, 'mg/dL'));
      },
    );

    test(
      'a body fat correction stays reported; its time can move (G-48)',
      () async {
        final (_, _, svc) = await fresh();
        final a = await svc.recordMeasurement(
          profileId: me,
          kind: fat,
          input: const MeasurementInput(
            value: '24,5',
            when: '2026-11-20 07:00',
          ),
          zone: utc,
        );
        final b = await svc.correctMeasurement(
          profileId: me,
          targetId: a.id,
          input: const MeasurementInput(
            value: '24,1',
            when: '2026-11-19 07:00',
          ),
          zone: utc,
        );
        expect(b.state, RecordState.reported);
        expect(b.observedAt, DateTime.utc(2026, 11, 19, 7));
        expect(b.quantity, const Quantity(24.1, '%'));
      },
    );
  });

  group('record rules (schema 16)', () {
    test('the new kinds and the timing details need schema 16', () {
      expect(
        () => stored(g, q: const Quantity(5, 'mmol/L'), schema: 15).validate(),
        rule('KIND_NEEDS_NEWER_SCHEMA'),
      );
      expect(
        () => stored(fat, q: const Quantity(20, '%'), schema: 15).validate(),
        rule('KIND_NEEDS_NEWER_SCHEMA'),
      );
    });

    test('broken stored shapes are refused with their own codes', () {
      expect(
        () => stored(g, q: const Quantity(5, 'g/L')).validate(),
        rule('UNIT_NOT_SUPPORTED'),
      );
      expect(
        () => stored(fat, q: const Quantity(20, 'mg/dL')).validate(),
        rule('UNIT_NOT_SUPPORTED'),
      );
      expect(
        () => stored(g, q: const Quantity(0, 'mg/dL')).validate(),
        rule('VALUE_NOT_POSITIVE'),
      );
      // Timing only on a present glucose; never on another kind.
      expect(
        () => stored(
          g,
          status: ValueStatus.notMeasured,
          details: const GlucoseTimingDetails(GlucoseTiming.fasting),
        ).validate(),
        rule('DETAILS_MISMATCH'),
      );
      expect(
        () => stored(
          fat,
          q: const Quantity(20, '%'),
          details: const GlucoseTimingDetails(GlucoseTiming.fasting),
        ).validate(),
        rule('DETAILS_MISMATCH'),
      );
      expect(
        () => stored(
          RecordKind.height,
          q: const Quantity(170, 'cm'),
          details: const GlucoseTimingDetails(GlucoseTiming.fasting),
        ).validate(),
        rule('DETAILS_MISMATCH'),
      );
      expect(
        () => stored(
          g,
          q: const Quantity(5, 'mmol/L'),
          details: const BloodPressureDetails(systolic: 120, diastolic: 80),
        ).validate(),
        rule('DETAILS_MISMATCH'),
      );
      // A glucose not measured carries no number (missing ≠ zero).
      expect(
        () => stored(
          g,
          status: ValueStatus.notMeasured,
          q: const Quantity(0, 'mmol/L'),
        ).validate(),
        rule('MISSING_HAS_NO_QUANTITY'),
      );
      expect(
        () => GlucoseTimingDetails.fromJson(const {
          'type': 'glucose_timing',
          'timing': 'bedtime',
        }),
        throwsFormatException,
      );
    });

    test('JSON round trip keeps every field', () {
      final r = stored(
        g,
        q: const Quantity(5.3, 'mmol/L'),
        details: const GlucoseTimingDetails(GlucoseTiming.afterMeal),
      )..validate();
      final back = HealthRecord.fromJson(r.toJson());
      expect(jsonEncode(back.toJson()), jsonEncode(r.toJson()));
      expect(back.details, r.details);
    });
  });

  group('display: as typed, never judged', () {
    test('value, unit and timing in EN and TR; spoken units; no judgement '
        'or diagnosis words', () async {
      final (_, _, svc) = await fresh();
      final a = await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(
          value: '5,30',
          unit: 'mmol/L',
          glucoseTiming: GlucoseTiming.fasting,
        ),
      );
      final b = await svc.recordMeasurement(
        profileId: me,
        kind: fat,
        input: const MeasurementInput(value: '24,5'),
      );
      final en = S(AppLang.en), tr = S(AppLang.tr);
      expect(measurementValue(en, a), '5.30 mmol/L · Fasting');
      expect(measurementValue(tr, a), '5,30 mmol/L · Aç karnına');
      expect(spokenMeasurement(en, a), '5.30 millimoles per litre · Fasting');
      expect(measurementValue(en, b), '24.5 %');
      expect(measurementValue(tr, b), '24,5 %');
      final texts = <String>[
        for (final s in [en, tr]) ...[
          measurementValue(s, a),
          measurementValue(s, b),
          s.recordKind(g),
          s.recordKind(fat),
          s.measurementField(g),
          s.measurementField(fat),
          s.measurementHint(g)!,
          s.measurementHint(fat)!,
          s.glucoseUnitLabel,
          s.glucoseUnitHelp,
          s.glucoseTimingLabel,
          for (final t in GlucoseTiming.values) s.glucoseTiming(t),
          s.inputError('UNIT_CHOICE_REQUIRED'),
          s.trendOtherUnits('mg/dL', 2),
          s.spokenUnit('mg/dL'),
          s.spokenUnit('mmol/L'),
        ],
      ];
      for (final t in texts) {
        expect(judged.hasMatch(t), isFalse, reason: t);
        expect(interpretive.hasMatch(t), isFalse, reason: t);
        expect(diabetesWords.hasMatch(t), isFalse, reason: t);
      }
      // The device estimate is said in the name itself.
      expect(en.recordKind(fat), contains('as the device showed'));
      expect(tr.recordKind(fat), contains('cihazın gösterdiği'));
      expect(en.measurementHint(fat), contains('estimate'));
      expect(tr.measurementHint(fat), contains('tahmin'));
    });

    test('a trend draws one unit only, the newest; the others are kept and '
        'never converted', () async {
      final (_, _, svc) = await fresh();
      for (final (v, u) in [
        ('100', 'mg/dL'),
        ('5,5', 'mmol/L'),
        ('6', 'mmol/L'),
      ]) {
        await svc.recordMeasurement(
          profileId: me,
          kind: g,
          input: MeasurementInput(value: v, unit: u),
        );
      }
      final points = trendPoints(await svc.measurementTimeline(me, g));
      expect(points, hasLength(3));
      final drawn = sameUnitAsNewest(points);
      expect([for (final p in drawn) p.values.single], [5.5, 6]);
      expect(drawn.map(unitOf).toSet(), {'mmol/L'});
      expect(points.first.values.single, 100, reason: 'never converted');
    });
  });

  group('persistence, fixture and backup', () {
    late Directory tmp;
    late File vaultFile;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('hhos-f007s8-');
      vaultFile = File('${tmp.path}/$vaultFileName');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('the readings survive close and reopen; the first schema 16 record '
        'makes the one upgrade checkpoint; old bytes unchanged', () async {
      final old = File(fixture15).readAsStringSync();
      vaultFile.writeAsStringSync(old);
      final repo = fileRepo(vaultFile);
      expect((await repo.open()).warnings, isEmpty);
      final svc = HeartbeatService(repo, clock: _At());
      var checkpoints = 0;
      repo.beforeSchemaUpgrade = () async => checkpoints++;
      await svc.recordWeightKg(profileId: me, input: '72,4');
      expect(checkpoints, 0, reason: 'a weight is still written at 3');
      await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(
          value: '95',
          unit: 'mg/dL',
          glucoseTiming: GlucoseTiming.fasting,
        ),
      );
      expect(checkpoints, 1);
      await svc.recordMeasurement(
        profileId: me,
        kind: fat,
        input: const MeasurementInput(value: '24,5'),
      );
      await svc.recordMeasurement(
        profileId: me,
        kind: g,
        input: const MeasurementInput(notMeasured: true),
      );
      expect(checkpoints, 1, reason: 'the store is already at 16');
      expect(vaultFile.readAsStringSync().startsWith(old), isTrue);
      final before = jsonOf(await repo.records(me));

      final reopened = fileRepo(vaultFile);
      expect((await reopened.open()).warnings, isEmpty);
      final after = await reopened.records(me);
      expect(jsonOf(after), before);
      expect(after.where((r) => r.schemaVersion == 16), hasLength(3));
      expect(
        after.where((r) => r.kind == RecordKind.bodyWeight).last.schemaVersion,
        3,
      );
    });

    test('the F007-S8 schema 16 fixture replays cleanly and re-encodes byte '
        'for byte', () {
      final text = File(fixture16).readAsStringSync();
      expect(text.startsWith(File(fixture15).readAsStringSync()), isTrue);
      final state = parseVaultLog(text);
      expect(state.warnings, isEmpty);
      String id(int n) => '00000000-0000-4000-8000-00000000040$n';
      final a = state.records[id(0)]!;
      expect(a.kind, g);
      expect(a.quantity, const Quantity(95, 'mg/dL'));
      expect(a.details, const GlucoseTimingDetails(GlucoseTiming.fasting));
      expect(state.records[id(1)]!.originalText, '7,8');
      expect(state.records[id(1)]!.context, 'yemekten 2 saat sonra');
      expect(state.records[id(2)]!.details, isNull);
      expect(state.records[id(4)]!.valueStatus, ValueStatus.notMeasured);
      expect(state.records[id(5)]!.state, RecordState.reported);
      final glucose = buildTimeline(
        state.records.values.where((r) => r.kind == g),
      ).singleWhere((e) => e.rootId == id(1));
      expect(glucose.heads.single.id, id(3));
      expect(glucose.heads.single.quantity, const Quantity(6.8, 'mmol/L'));
      final body = buildTimeline(
        state.records.values.where((r) => r.kind == fat),
      ).single;
      expect(body.heads.single.id, id(6));
      for (final l in text.trimRight().split('\n').skip(2)) {
        final data = ((jsonDecode(l) as Map)['data']! as Map)
            .cast<String, Object?>();
        expect(
          encodeOp('record.append', HealthRecord.fromJson(data).toJson()),
          l,
        );
      }
    });

    test('a backup round-trips schema 16 records into a fresh store', () async {
      final log = File(fixture16).readAsStringSync();
      vaultFile.writeAsStringSync(log);
      final repo = fileRepo(vaultFile);
      expect((await repo.open()).warnings, isEmpty);
      final before = jsonOf(await repo.records(me));
      final files = FileDataFiles(dataDir: tmp, vault: vaultFile);
      final bundle = createBackupBundle(
        vaultLogText: log,
        appVersion: '0.1.0+1',
        sourceRevision: 'f007s8',
        createdAt: t0,
      );
      final manifest = ((jsonDecode(bundle) as Map)['manifest']! as Map)
          .cast<String, Object?>();
      expect(manifest['record_schema_versions'], contains(16));
      await files.save(
        DataFileKind.backup,
        backupFileName('f007s8', t0),
        bundle,
      );
      vaultFile.deleteSync();
      final staged = stageRestore(
        await files.read((await files.backups()).single),
      );
      await files.restore(staged, now: t0);
      expect(vaultFile.readAsStringSync(), log);
      final restored = fileRepo(vaultFile);
      expect((await restored.open()).warnings, isEmpty);
      expect(jsonOf(await restored.records(me)), before);
    });

    test('an older build (15) refuses a schema 16 store whole; a newer one '
        'is refused here; a new kind under an older label is never read', () {
      final log = File(fixture16).readAsStringSync();
      final newer = log.replaceFirst(
        '"schema_version":16,',
        '"schema_version":17,',
      );
      expect(newer, isNot(log));
      expect(
        () => parseVaultLog(newer),
        throwsA(
          isA<VaultFormatError>().having(
            (e) => e.code,
            'code',
            'RECORD_SCHEMA_NEWER',
          ),
        ),
      );
      final older = log.replaceFirst(
        '"schema_version":16,',
        '"schema_version":15,',
      );
      final state = parseVaultLog(older);
      expect(state.warnings, isNotEmpty);
      expect(
        state.records.containsKey('00000000-0000-4000-8000-000000000400'),
        isFalse,
      );
    });
  });
}
