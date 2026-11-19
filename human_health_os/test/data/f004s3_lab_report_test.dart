// F004-S3 (G-28, D-045): what else the lab report printed, kept as printed
// and apart from the result: the report time (separate from the sample
// date), the method, and the reference interval as the person typed it
// (low and/or high with their unit, the printed partition). Entry rules,
// the record rules of schema 15, persistence, the old and new fixtures,
// backup and restore, and that nothing relates the value to the interval.
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
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/features/report/doctor_summary.dart';
import 'package:human_health_os/src/l10n/strings.dart';

const fixture14 = 'test/fixtures/vault/v1_f004s2_schema14.hhoslog.jsonl';
const fixture15 = 'test/fixtures/vault/v1_f004s3_schema15.hhoslog.jsonl';
const me = '00000000-0000-4000-8000-0000000000a1';
final t0 = DateTime.utc(2026, 11, 19, 9);

class _At implements Clock {
  @override
  DateTime nowUtc() => t0;
}

Matcher input(String code, String field) => throwsA(
  isA<InputError>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.field, 'field', field),
);

Matcher rule(String code) =>
    throwsA(isA<RecordValidationError>().having((e) => e.code, 'code', code));

LabReferenceInterval? iv(
  String low,
  String high, {
  String unit = 'mg/dL',
  String partition = '',
}) => parseReferenceInterval(
  low: low,
  high: high,
  unit: unit,
  partition: partition,
);

LabInput li({
  String value = '91',
  String reportTime = '',
  String method = '',
  String low = '',
  String high = '',
  String refUnit = '',
  String partition = '',
  LabValueKind kind = LabValueKind.number,
}) => LabInput(
  analyte: 'Glukoz',
  value: value,
  notReported: false,
  unit: 'mg/dL',
  sampleDate: '2026-11-02',
  kind: kind,
  reportTime: reportTime,
  method: method,
  refLow: low,
  refHigh: high,
  refUnit: refUnit,
  refPartition: partition,
);

HealthRecord rec({
  DateTime? reportedAt,
  String? method,
  LabReferenceInterval? interval,
  int schema = 15,
}) => HealthRecord(
  id: 'l1',
  profileId: 'p',
  kind: RecordKind.labResult,
  state: RecordState.reported,
  valueStatus: ValueStatus.present,
  quantity: const Quantity(91, 'mg/dL'),
  originalText: '91',
  provenance: const Provenance.manual(),
  observedAt: DateTime.utc(2026, 11, 2),
  recordedAt: DateTime.utc(2026, 11, 3),
  lab: LabDetails(
    analyteLabel: 'Glukoz',
    reportedAt: reportedAt,
    method: method,
    referenceInterval: interval,
  ),
  schemaVersion: schema,
);

LogRepository fileRepo(File f) => LogRepository(
  sink: FileLogSink(f),
  durability: StorageDurability.localFile,
  location: f.path,
);

List<String> jsonOf(Iterable<HealthRecord> rs) => [
  for (final r in rs) jsonEncode(r.toJson()),
];

/// Words that would relate a value to its interval (G-28 brief).
final RegExp comparing = RegExp(
  r'(?<!\p{L})(within|inside|outside|normal|abnormal|in range|out of range|'
  r'aralıkta|dışında|aralık dışı|high|low|yüksek|düşük)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

void main() {
  group('reference interval entry', () {
    test('low and high as typed, the TR comma kept, negative lows allowed', () {
      final a = iv('4,0', '6,0', unit: '%', partition: ' Kadın 20-49 yaş ')!;
      expect(a.lowText, '4,0');
      expect(a.highText, '6,0');
      expect(a.unit, '%');
      expect(a.partition, 'Kadın 20-49 yaş');
      final b = iv('-2', '2', unit: 'mmol/L')!;
      expect(b.lowText, '-2');
      expect(iv('\u22123,5', '-1', unit: 'mmol/L')!.lowText, '\u22123,5');
      expect(iv('', '130')!.lowText, isNull);
      expect(iv('', '130')!.highText, '130');
      expect(iv('70', '')!.highText, isNull);
      expect(iv('5', '5')!.highText, '5', reason: 'equal bounds are kept');
      expect(
        iv('', '', unit: '', partition: '  '),
        isNull,
        reason: 'all blank: no interval',
      );
    });

    test(
      'low above high is refused with a clear message, on the low field',
      () {
        expect(
          () => iv('6,0', '4,0'),
          input('INTERVAL_LOW_ABOVE_HIGH', 'refLow'),
        );
        expect(() => iv('2', '-2'), input('INTERVAL_LOW_ABOVE_HIGH', 'refLow'));
        expect(
          const S(AppLang.en).inputError('INTERVAL_LOW_ABOVE_HIGH'),
          contains('low number is larger than the high number'),
        );
        expect(
          const S(AppLang.tr).inputError('INTERVAL_LOW_ABOVE_HIGH'),
          contains('Alt sayı üst sayıdan büyük'),
        );
      },
    );

    test('a unit is required when a low or high is given', () {
      expect(
        () => iv('70', '100', unit: ''),
        input('INTERVAL_UNIT_REQUIRED', 'refUnit'),
      );
      expect(
        () => iv('', '130', unit: '  '),
        input('INTERVAL_UNIT_REQUIRED', 'refUnit'),
      );
      // A unit or a group alone has no interval to describe.
      expect(
        () => iv('', '', unit: 'mg/dL'),
        input('INTERVAL_NEEDS_BOUND', 'refLow'),
      );
      expect(
        () => iv('', '', unit: '', partition: 'adult'),
        input('INTERVAL_NEEDS_BOUND', 'refLow'),
      );
    });

    test('a bound is a number as printed; anything else names its field', () {
      expect(() => iv('<70', ''), input('INTERVAL_BOUND_HAS_SIGN', 'refLow'));
      expect(
        () => iv('', '< 130'),
        input('INTERVAL_BOUND_HAS_SIGN', 'refHigh'),
      );
      expect(
        () => iv('70 mg/dL', ''),
        input('INTERVAL_BOUND_HAS_UNIT', 'refLow'),
      );
      expect(
        () => iv('', '1 000'),
        input('INTERVAL_BOUND_HAS_SPACE', 'refHigh'),
      );
      expect(() => iv('- 2', '2'), input('INTERVAL_BOUND_HAS_SPACE', 'refLow'));
      expect(() => iv('abc', ''), input('NOT_A_NUMBER', 'refLow'));
      expect(() => iv('-', '2'), input('NOT_A_NUMBER', 'refLow'));
      expect(() => iv('', '150,000'), input('AMBIGUOUS_SEPARATOR', 'refHigh'));
      expect(
        () => iv('1', '2', unit: 'x' * 301),
        input('TEXT_TOO_LONG', 'refUnit'),
      );
      expect(
        () => iv('1', '2', partition: 'x' * 301),
        input('TEXT_TOO_LONG', 'refPartition'),
      );
    });

    test('method and report time follow the existing rules, on their own '
        'fields', () {
      expect(parseLabMethod('  HPLC '), 'HPLC');
      expect(parseLabMethod(''), isNull);
      expect(parseLabMethod('enz\u202Eymatic'), 'enzymatic');
      expect(() => parseLabMethod('x' * 301), input('TEXT_TOO_LONG', 'method'));
      final zone = OffsetRuleZone((_) => const Duration(hours: 3));
      final sample = DateTime.utc(2026, 11, 2);
      expect(
        parseReportTime(
          '2026-11-03 14:20',
          nowUtc: t0,
          sampleDay: sample,
          zone: zone,
        ),
        DateTime.utc(2026, 11, 3, 11, 20),
      );
      expect(
        parseReportTime('', nowUtc: t0, sampleDay: sample, zone: zone),
        isNull,
      );
      for (final (typed, code) in [
        ('3 Nov', 'TIME_FORMAT'),
        ('2026-11-20 10:00', 'FUTURE_TIME'),
        ('2026-11-01 23:00', 'REPORT_BEFORE_SAMPLE'),
      ]) {
        expect(
          () =>
              parseReportTime(typed, nowUtc: t0, sampleDay: sample, zone: zone),
          input(code, 'reportTime'),
          reason: typed,
        );
      }
      // The sample day itself is fine, early in the morning local time.
      expect(
        parseReportTime(
          '2026-11-02 00:30',
          nowUtc: t0,
          sampleDay: sample,
          zone: zone,
        ),
        DateTime.utc(2026, 11, 1, 21, 30),
      );
    });
  });

  group('record rules (schema 15)', () {
    final good = const LabReferenceInterval(
      lowText: '70',
      highText: '100',
      unit: 'mg/dL',
      partition: 'adult',
    );

    test('report details are valid only at schema 15', () {
      rec(reportedAt: DateTime.utc(2026, 11, 3, 10)).validate();
      rec(method: 'HPLC').validate();
      rec(interval: good).validate();
      for (final r in [
        rec(method: 'HPLC', schema: 14),
        rec(interval: good, schema: 3),
        rec(reportedAt: DateTime.utc(2026, 11, 3), schema: 14),
      ]) {
        expect(r.validate, rule('FIELD_NEEDS_NEWER_SCHEMA'));
      }
    });

    test('broken stored shapes are refused with their own codes', () {
      expect(rec(method: ' ').validate, rule('LAB_METHOD_EMPTY'));
      expect(rec(method: 'x' * 301).validate, rule('LAB_METHOD_TOO_LONG'));
      expect(
        rec(reportedAt: DateTime(2026, 11, 3)).validate,
        rule('LAB_REPORTED_AT_NOT_UTC'),
      );
      for (final (bad, code) in [
        (const LabReferenceInterval(unit: 'mg/dL'), 'LAB_INTERVAL_NEEDS_BOUND'),
        (
          const LabReferenceInterval(lowText: '7 0', unit: 'mg/dL'),
          'LAB_INTERVAL_BOUND_NOT_A_NUMBER',
        ),
        (
          const LabReferenceInterval(highText: '130', unit: ''),
          'LAB_INTERVAL_UNIT_REQUIRED',
        ),
        (
          const LabReferenceInterval(highText: '1', unit: 'u', partition: ''),
          'LAB_INTERVAL_PARTITION_EMPTY',
        ),
        (
          const LabReferenceInterval(lowText: '6', highText: '4', unit: '%'),
          'LAB_INTERVAL_ORDER',
        ),
      ]) {
        expect(rec(interval: bad).validate, rule(code), reason: code);
      }
      // A negative low with the minus sign U+2212 is a number.
      rec(
        interval: const LabReferenceInterval(
          lowText: '\u22122',
          highText: '2',
          unit: 'mmol/L',
        ),
      ).validate();
    });

    test('JSON round trip keeps every field; keys are written only when '
        'present, so a schema 3 record keeps its exact bytes', () {
      final r = rec(
        reportedAt: DateTime.utc(2026, 11, 3, 14, 20),
        method: 'HPLC',
        interval: good,
      );
      final back = HealthRecord.fromJson(
        (jsonDecode(jsonEncode(r.toJson())) as Map).cast<String, Object?>(),
      );
      expect(back.lab, r.lab);
      expect(jsonEncode(back.toJson()), jsonEncode(r.toJson()));
      final lab = r.toJson()['lab']! as Map;
      expect(lab['reported_at'], '2026-11-03T14:20:00.000Z');
      expect(lab['reference_interval'], {
        'low_text': '70',
        'high_text': '100',
        'unit': 'mg/dL',
        'partition': 'adult',
      });
      final plain = (rec(schema: 3).toJson()['lab']! as Map).keys;
      expect(plain, isNot(contains('reported_at')));
      expect(plain, isNot(contains('method')));
      expect(plain, isNot(contains('reference_interval')));
      expect(
        HealthRecord.writeSchemaForLab(const LabDetails(analyteLabel: 'x')),
        3,
      );
      expect(
        HealthRecord.writeSchemaForLab(
          const LabDetails(
            analyteLabel: 'x',
            result: LabPrintedResult.text(text: 'Pozitif'),
          ),
        ),
        14,
      );
      expect(
        HealthRecord.writeSchemaForLab(
          const LabDetails(analyteLabel: 'x', method: 'HPLC'),
        ),
        15,
      );
    });
  });

  group('service: recordLab and correctLab', () {
    late HeartbeatService svc;
    late String profile;
    setUp(() async {
      final repo = inMemoryRepository();
      await repo.open();
      svc = HeartbeatService(repo, clock: _At());
      profile = (await svc.ensureSelfProfile()).id;
    });

    test('every new field is kept as typed; the printed range text is kept '
        'unchanged and nothing is derived from it', () async {
      final r = await svc.recordLab(
        profileId: profile,
        input: LabInput(
          analyte: 'HbA1c',
          value: '5,4',
          notReported: false,
          unit: '%',
          sampleDate: '2026-11-02',
          referenceText: '4,0 - 6,0',
          reportTime: '2026-11-03 14:20 Z',
          method: ' HPLC ',
          refLow: '4,0',
          refHigh: '6,0',
          refUnit: '%',
          refPartition: 'Kadın 20-49 yaş',
        ),
      );
      expect(r.schemaVersion, 15);
      expect(r.lab!.referenceText, '4,0 - 6,0');
      expect(r.lab!.reportedAt, DateTime.utc(2026, 11, 3, 14, 20));
      expect(r.lab!.method, 'HPLC');
      expect(
        r.lab!.referenceInterval,
        const LabReferenceInterval(
          lowText: '4,0',
          highText: '6,0',
          unit: '%',
          partition: 'Kadın 20-49 yaş',
        ),
      );
      expect(r.observedAt, DateTime.utc(2026, 11, 2), reason: 'sample date');
      // The printed range alone never becomes a structured interval.
      final onlyText = await svc.recordLab(
        profileId: profile,
        input: const LabInput(
          analyte: 'Glukoz',
          value: '91',
          notReported: false,
          unit: 'mg/dL',
          sampleDate: '2026-11-02',
          referenceText: '70 - 100',
        ),
      );
      expect(onlyText.lab!.referenceInterval, isNull);
      expect(onlyText.schemaVersion, 3);
    });

    test(
      'a censored or text result keeps its object next to the details',
      () async {
        final r = await svc.recordLab(
          profileId: profile,
          input: li(
            value: '< 5',
            kind: LabValueKind.censored,
            method: 'nefelometri',
          ),
        );
        expect(r.schemaVersion, 15);
        expect(r.lab!.result!.limitText, '5');
        expect(r.lab!.method, 'nefelometri');
        expect(labNumberFor(r).notUsableReason, 'LAB_VALUE_CENSORED');
      },
    );

    test('refusals name their field and save nothing', () async {
      for (final (lab, code, field) in [
        (
          li(low: '6', high: '4', refUnit: '%'),
          'INTERVAL_LOW_ABOVE_HIGH',
          'refLow',
        ),
        (li(low: '70'), 'INTERVAL_UNIT_REQUIRED', 'refUnit'),
        (li(refUnit: 'mg/dL'), 'INTERVAL_NEEDS_BOUND', 'refLow'),
        (li(reportTime: 'tomorrow'), 'TIME_FORMAT', 'reportTime'),
        (
          li(reportTime: '2026-11-01 08:00'),
          'REPORT_BEFORE_SAMPLE',
          'reportTime',
        ),
        (li(method: 'x' * 301), 'TEXT_TOO_LONG', 'method'),
      ]) {
        await expectLater(
          svc.recordLab(profileId: profile, input: lab),
          input(code, field),
        );
      }
      expect(await svc.labTimeline(profile), isEmpty);
    });

    test(
      'a correction can add or drop the details; each version is kept',
      () async {
        final first = await svc.recordLab(profileId: profile, input: li());
        expect(first.schemaVersion, 3);
        final second = await svc.correctLab(
          profileId: profile,
          targetId: first.id,
          input: li(
            low: '70',
            high: '100',
            refUnit: 'mg/dL',
            method: 'enzimatik',
          ),
        );
        expect(second.schemaVersion, 15);
        final third = await svc.correctLab(
          profileId: profile,
          targetId: second.id,
          input: li(),
        );
        expect(third.schemaVersion, 3);
        expect(third.lab!.hasReportDetails, isFalse);
        final e = (await svc.labTimeline(profile)).single;
        expect(e.versions.length, 3);
      },
    );
  });

  group('nothing relates the value to the interval', () {
    test('the doctor summary restates the details plainly, with no comparing '
        'word, in EN and TR', () {
      final state = parseVaultLog(File(fixture15).readAsStringSync());
      final hba1c = state.records['00000000-0000-4000-8000-000000000300']!;
      final ldl = state.records['00000000-0000-4000-8000-000000000301']!;
      for (final (s, interval, method, upper) in [
        (
          const S(AppLang.en),
          'Reference interval as printed: 4,0–6,0 % (Kadın 20-49 yaş)',
          'Method as printed: HPLC',
          'Reference interval as printed: upper bound 130 mg/dL',
        ),
        (
          const S(AppLang.tr),
          'Raporda yazan referans aralığı: 4,0–6,0 % (Kadın 20-49 yaş)',
          'Raporda yazan yöntem: HPLC',
          'Raporda yazan referans aralığı: üst sınır 130 mg/dL',
        ),
      ]) {
        String noteOf(HealthRecord r) {
          final row = DoctorSummary.labRow(s, r);
          return '${row.value} ${row.note}';
        }

        final a = noteOf(hba1c);
        expect(a, contains(interval));
        expect(a, contains(method));
        expect(a, contains(isoWhen(DateTime.utc(2026, 11, 4, 14, 20))));
        final b = noteOf(ldl);
        expect(b, contains(upper));
        // The LDL value (142) lies above its printed upper bound: no word
        // says so. Only the lab's own flag ("H") is shown.
        for (final t in [a, b]) {
          expect(
            comparing.hasMatch(t.replaceAll(s.labPrintedFlag('H'), '')),
            isFalse,
            reason: t,
          );
        }
        expect(b, contains(s.labPrintedFlag('H')));
      }
    });

    test('no app code compares a lab value with the structured interval', () {
      // Every read of the interval's bounds as numbers is the order check of
      // the two bounds; no file reads them next to a lab value.
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final f in files) {
        final text = f.readAsStringSync();
        if (!text.contains('boundValue(')) continue;
        expect(
          f.path.endsWith('lab_details.dart') ||
              f.path.endsWith('heartbeat_service.dart'),
          isTrue,
          reason: '${f.path} reads interval bounds as numbers',
        );
        expect(text.contains('labNumberFor('), isFalse, reason: f.path);
      }
    });
  });

  group('persistence, fixtures and backup', () {
    late Directory tmp;
    late File vaultFile;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('hhos-f004s3-');
      vaultFile = File('${tmp.path}/$vaultFileName');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('the details survive close and reopen; the first schema 15 record '
        'makes the one upgrade checkpoint', () async {
      vaultFile.writeAsStringSync(File(fixture14).readAsStringSync());
      final repo = fileRepo(vaultFile);
      expect((await repo.open()).warnings, isEmpty);
      final svc = HeartbeatService(repo, clock: _At());
      var checkpoints = 0;
      repo.beforeSchemaUpgrade = () async => checkpoints++;
      await svc.recordLab(profileId: me, input: li());
      await svc.recordLab(
        profileId: me,
        input: li(value: '< 5', kind: LabValueKind.censored),
      );
      expect(checkpoints, 0, reason: 'the store already holds 14');
      await svc.recordLab(
        profileId: me,
        input: li(
          reportTime: '2026-11-03 14:20',
          method: 'HPLC',
          low: '-2',
          high: '2',
          refUnit: 'mmol/L',
          partition: 'yetişkin',
        ),
      );
      expect(checkpoints, 1);
      await svc.recordLab(
        profileId: me,
        input: li(method: 'enzimatik'),
      );
      expect(checkpoints, 1, reason: 'the store is already at 15');
      final before = jsonOf(await repo.records(me));

      final reopened = fileRepo(vaultFile);
      expect((await reopened.open()).warnings, isEmpty);
      final after = await reopened.records(me);
      expect(jsonOf(after), before);
      expect(after.where((r) => r.schemaVersion == 15), hasLength(2));
    });

    test('the F004-S2 schema 14 fixture still loads unchanged', () {
      final text = File(fixture14).readAsStringSync();
      final state = parseVaultLog(text);
      expect(state.warnings, isEmpty);
      for (final r in state.records.values) {
        expect(r.lab?.hasReportDetails ?? false, isFalse);
      }
      for (final l in text.trimRight().split('\n').skip(2)) {
        final data = ((jsonDecode(l) as Map)['data']! as Map)
            .cast<String, Object?>();
        expect(
          encodeOp('record.append', HealthRecord.fromJson(data).toJson()),
          l,
        );
      }
    });

    test('the F004-S3 schema 15 fixture replays cleanly and re-encodes byte '
        'for byte', () {
      final text = File(fixture15).readAsStringSync();
      expect(text.startsWith(File(fixture14).readAsStringSync()), isTrue);
      final state = parseVaultLog(text);
      expect(state.warnings, isEmpty);
      String id(int n) => '00000000-0000-4000-8000-00000000030$n';
      final hba1c = state.records[id(0)]!;
      expect(hba1c.schemaVersion, 15);
      expect(hba1c.lab!.method, 'HPLC');
      expect(hba1c.lab!.reportedAt, DateTime.utc(2026, 11, 4, 14, 20));
      expect(hba1c.lab!.referenceInterval!.partition, 'Kadın 20-49 yaş');
      expect(hba1c.lab!.referenceText, '4,0 - 6,0');
      expect(hba1c.observedAt, DateTime.utc(2026, 11, 4));
      expect(state.records[id(1)]!.lab!.referenceInterval!.lowText, isNull);
      expect(state.records[id(2)]!.lab!.referenceInterval!.lowText, '-2');
      expect(state.records[id(4)]!.lab!.result!.limitText, '0,5');
      expect(state.records[id(6)]!.schemaVersion, 3);
      final glucose = buildTimeline(
        state.records.values.where((r) => r.kind == RecordKind.labResult),
      ).singleWhere((e) => e.rootId == id(3));
      expect(glucose.heads.single.id, id(5));
      for (final l in text.trimRight().split('\n').skip(2)) {
        final data = ((jsonDecode(l) as Map)['data']! as Map)
            .cast<String, Object?>();
        expect(
          encodeOp('record.append', HealthRecord.fromJson(data).toJson()),
          l,
        );
      }
    });

    test(
      'a backup round-trips schema 15 lab results into a fresh store',
      () async {
        final log = File(fixture15).readAsStringSync();
        vaultFile.writeAsStringSync(log);
        final repo = fileRepo(vaultFile);
        expect((await repo.open()).warnings, isEmpty);
        final before = jsonOf(await repo.records(me));
        final files = FileDataFiles(dataDir: tmp, vault: vaultFile);
        final bundle = createBackupBundle(
          vaultLogText: log,
          appVersion: '0.1.0+1',
          sourceRevision: 'f004s3',
          createdAt: t0,
        );
        final manifest = ((jsonDecode(bundle) as Map)['manifest']! as Map)
            .cast<String, Object?>();
        expect(manifest['record_schema_versions'], contains(15));
        await files.save(
          DataFileKind.backup,
          backupFileName('f004s3', t0),
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
      },
    );

    test('an older build (schema 14) refuses a schema 15 store whole; a '
        'newer one is refused here; details under an older label are never '
        'read', () {
      final log = File(fixture15).readAsStringSync();
      // This build stands in for a newer app with 16.
      final newer = log.replaceFirst(
        '"schema_version":15,',
        '"schema_version":16,',
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
      // A schema 14 app reads only up to 14: the first schema 15 line is
      // what makes it refuse (RECORD_SCHEMA_NEWER, as above for 16 here).
      expect(log.contains('"schema_version":15,'), isTrue);
      final older = log.replaceFirst(
        '"schema_version":15,',
        '"schema_version":14,',
      );
      final state = parseVaultLog(older);
      expect(state.warnings, isNotEmpty);
      expect(
        state.records.containsKey('00000000-0000-4000-8000-000000000300'),
        isFalse,
      );
    });
  });
}
