// F004-S2 (G-26, D-043): lab results below or above a limit ("< 5") and
// results printed as text ("Pozitif"), kept exactly as printed and never
// read as numbers. Parsing and validation of each kind, the record rules of
// schema 14, persistence, the old and new fixtures, backup and restore, and
// the one door through which a calculation may read a lab value.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/core/ids.dart';
import 'package:human_health_os/src/data/backup/backup_bundle.dart';
import 'package:human_health_os/src/data/backup/data_files.dart';
import 'package:human_health_os/src/data/backup/data_files_io.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/data/local/storage_io.dart';
import 'package:human_health_os/src/data/local/vault_log.dart';
import 'package:human_health_os/src/domain/derived/derived_from_records.dart';
import 'package:human_health_os/src/domain/engines/calc_result.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

const fixture3 = 'test/fixtures/vault/v1_f004_schema3.hhoslog.jsonl';
const fixture14 = 'test/fixtures/vault/v1_f004s2_schema14.hhoslog.jsonl';
final t0 = DateTime.utc(2026, 11, 19, 9);

class _At implements Clock {
  @override
  DateTime nowUtc() => t0;
}

Matcher input(String code) => throwsA(
  isA<InputError>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.field, 'field', 'value'),
);

Matcher rule(String code) =>
    throwsA(isA<RecordValidationError>().having((e) => e.code, 'code', code));

LabInput li(
  String value, {
  LabValueKind kind = LabValueKind.number,
  String unit = 'mg/dL',
  bool notReported = false,
}) => LabInput(
  analyte: 'CRP',
  value: value,
  notReported: notReported,
  unit: unit,
  sampleDate: '2026-11-02',
  kind: kind,
);

HealthRecord rec({
  LabPrintedResult? printed = const LabPrintedResult.censored(
    comparator: LabComparator.lessThan,
    limitText: '5',
    unit: 'mg/L',
  ),
  Quantity? q,
  ValueStatus status = ValueStatus.present,
  int schema = 14,
}) => HealthRecord(
  id: 'l1',
  profileId: 'p',
  kind: RecordKind.labResult,
  state: RecordState.reported,
  valueStatus: status,
  quantity: q,
  originalText: '< 5',
  provenance: const Provenance.manual(),
  observedAt: DateTime.utc(2026, 11, 2),
  recordedAt: DateTime.utc(2026, 11, 3),
  lab: LabDetails(analyteLabel: 'CRP', result: printed),
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

void main() {
  group('censored: a comparator and a number, the number as typed', () {
    test('accepted forms, the comparator stored as one symbol', () {
      for (final (typed, c, limit) in [
        ('< 5', LabComparator.lessThan, '5'),
        ('<5,4', LabComparator.lessThan, '5,4'),
        ('<=0.1', LabComparator.lessOrEqual, '0.1'),
        ('=<0,1', LabComparator.lessOrEqual, '0,1'),
        ('≤ 0,5', LabComparator.lessOrEqual, '0,5'),
        ('> 1000', LabComparator.greaterThan, '1000'),
        ('>=7', LabComparator.greaterOrEqual, '7'),
        ('=> 7', LabComparator.greaterOrEqual, '7'),
        ('≥ 90', LabComparator.greaterOrEqual, '90'),
        ('  ≥90  ', LabComparator.greaterOrEqual, '90'),
      ]) {
        final p = parseCensoredLab(typed);
        expect(p.comparator, c, reason: typed);
        expect(p.limitText, limit, reason: 'kept as typed: $typed');
      }
    });

    test('refused inputs each name the value field and say why', () {
      for (final (typed, code) in [
        ('', 'EMPTY'),
        ('   ', 'EMPTY'),
        ('<', 'CENSORED_NEEDS_NUMBER'),
        ('< ', 'CENSORED_NEEDS_NUMBER'),
        ('≥', 'CENSORED_NEEDS_NUMBER'),
        ('5', 'CENSORED_NEEDS_COMPARATOR'),
        ('Pozitif', 'CENSORED_NEEDS_COMPARATOR'),
        ('=5', 'COMPARATOR_UNCLEAR'),
        ('<< 5', 'COMPARATOR_UNCLEAR'),
        ('< =5', 'COMPARATOR_UNCLEAR'),
        ('<>5', 'COMPARATOR_UNCLEAR'),
        ('< 5 mg/dL', 'UNIT_IN_VALUE'),
        ('<5mg', 'UNIT_IN_VALUE'),
        ('> 90 %', 'UNIT_IN_VALUE'),
        ('< 1,000', 'AMBIGUOUS_SEPARATOR'),
        ('< abc', 'NOT_A_NUMBER'),
        ('< -5', 'NOT_A_NUMBER'),
        ('< 5,', 'NOT_A_NUMBER'),
      ]) {
        expect(() => parseCensoredLab(typed), input(code), reason: typed);
      }
    });
  });

  group('number: hints when the value is not a plain number', () {
    test('accepted as before; a sign or a unit in the field is named', () {
      expect(parseLabNumber('5,4'), 5.4);
      expect(parseLabNumber(' 91 '), 91);
      for (final (typed, code) in [
        ('', 'EMPTY'),
        ('<5', 'VALUE_HAS_COMPARATOR'),
        ('≥ 90', 'VALUE_HAS_COMPARATOR'),
        ('5 mg/dL', 'UNIT_IN_VALUE'),
        ('37mmol/mol', 'UNIT_IN_VALUE'),
        ('6 %', 'UNIT_IN_VALUE'),
        ('5,4 µg', 'UNIT_IN_VALUE'),
        ('pozitif', 'NOT_A_NUMBER'),
        ('1+', 'NOT_A_NUMBER'),
        ('150,000', 'AMBIGUOUS_SEPARATOR'),
      ]) {
        expect(() => parseLabNumber(typed), input(code), reason: typed);
      }
    });
  });

  group('text: verbatim, never mapped to a meaning', () {
    test('accepted as printed (surrounding spaces only are dropped)', () {
      for (final (typed, kept) in [
        ('Pozitif', 'Pozitif'),
        ('Negatif', 'Negatif'),
        ('Reaktif değil', 'Reaktif değil'),
        ('trace', 'trace'),
        ('1+', '1+'),
        ('  ++  ', '++'),
        ('Negatif (<10)', 'Negatif (<10)'),
      ]) {
        expect(parseLabText(typed), kept, reason: typed);
      }
      expect(parseLabText('🧪' * 300), hasLength(600), reason: 'code points');
    });

    test('a number or a censored value is refused: it has its own kind', () {
      for (final (typed, code) in [
        ('', 'EMPTY'),
        ('5,4', 'TEXT_IS_A_NUMBER'),
        ('-2', 'TEXT_IS_A_NUMBER'),
        ('1 000', 'TEXT_IS_A_NUMBER'),
        ('< 5', 'TEXT_IS_CENSORED'),
        ('≥90', 'TEXT_IS_CENSORED'),
        ('x' * 301, 'TEXT_TOO_LONG'),
      ]) {
        expect(() => parseLabText(typed), input(code), reason: typed);
      }
    });
  });

  group('record rules (schema 14)', () {
    test('a printed result is valid only at schema 14, present, with no '
        'number', () {
      rec().validate();
      rec(printed: const LabPrintedResult.text(text: 'Pozitif')).validate();
      expect(
        () => rec(schema: 13).validate(),
        rule('FIELD_NEEDS_NEWER_SCHEMA'),
      );
      expect(() => rec(schema: 3).validate(), rule('FIELD_NEEDS_NEWER_SCHEMA'));
      expect(
        () => rec(q: const Quantity(5, 'mg/L')).validate(),
        rule('LAB_VALUE_TWICE'),
        reason: 'a "< 5" is never also stored as 5',
      );
      expect(
        () => rec(status: ValueStatus.notReported).validate(),
        rule('LAB_RESULT_NEEDS_PRESENT'),
      );
      expect(
        () => rec(
          printed: const LabPrintedResult.censored(
            comparator: LabComparator.lessThan,
            limitText: '5 mg',
          ),
        ).validate(),
        rule('LAB_LIMIT_NOT_A_NUMBER'),
      );
      expect(
        () => rec(printed: const LabPrintedResult.text(text: ' ')).validate(),
        rule('LAB_TEXT_EMPTY'),
      );
      expect(
        () => rec(
          printed: const LabPrintedResult.text(text: 'x', unit: ''),
        ).validate(),
        rule('LAB_UNIT_EMPTY'),
      );
      // A present plain number without a printed result still needs one.
      expect(
        () => rec(printed: null, schema: 3).validate(),
        rule('PRESENT_REQUIRES_QUANTITY'),
      );
    });

    test('JSON round trip keeps every field; the key is written only when '
        'present', () {
      for (final r in [
        rec(),
        rec(printed: const LabPrintedResult.text(text: 'Reaktif değil')),
      ]) {
        final back = HealthRecord.fromJson(
          (jsonDecode(jsonEncode(r.toJson())) as Map).cast<String, Object?>(),
        );
        expect(back.lab, r.lab);
        expect(jsonEncode(back.toJson()), jsonEncode(r.toJson()));
      }
      final plain = rec(printed: null, q: const Quantity(5, 'mg/L'), schema: 3);
      expect((plain.toJson()['lab']! as Map).containsKey('result'), isFalse);
    });
  });

  group('service: recordLab and correctLab for every kind', () {
    late HeartbeatService svc;
    late String me;
    setUp(() async {
      final repo = inMemoryRepository();
      await repo.open();
      svc = HeartbeatService(repo, clock: _At());
      me = (await svc.ensureSelfProfile()).id;
    });

    test(
      'censored: present, no quantity, the typed text kept, schema 14',
      () async {
        final r = await svc.recordLab(
          profileId: me,
          input: li('<=0,1', kind: LabValueKind.censored),
        );
        expect(r.valueStatus, ValueStatus.present);
        expect(r.quantity, isNull);
        expect(r.originalText, '<=0,1');
        expect(
          r.lab!.result,
          const LabPrintedResult.censored(
            comparator: LabComparator.lessOrEqual,
            limitText: '0,1',
            unit: 'mg/dL',
          ),
        );
        expect(r.schemaVersion, 14);
      },
    );

    test('text: verbatim, no unit when none is printed, schema 14', () async {
      final r = await svc.recordLab(
        profileId: me,
        input: li('Reaktif değil', kind: LabValueKind.text, unit: ''),
      );
      expect(r.lab!.result, const LabPrintedResult.text(text: 'Reaktif değil'));
      expect(r.quantity, isNull);
      expect(r.schemaVersion, 14);
    });

    test('a plain number and a value not reported stay at schema 3 with no '
        'printed result, whatever kind is chosen', () async {
      final n = await svc.recordLab(profileId: me, input: li('5,4'));
      expect(n.schemaVersion, 3);
      expect(n.lab!.result, isNull);
      expect(n.quantity, const Quantity(5.4, 'mg/dL'));
      final missing = await svc.recordLab(
        profileId: me,
        input: li('', kind: LabValueKind.censored, notReported: true),
      );
      expect(missing.valueStatus, ValueStatus.notReported);
      expect(missing.lab!.result, isNull);
      expect(missing.schemaVersion, 3);
    });

    test('refused values name the value field through the service', () async {
      await expectLater(
        svc.recordLab(
          profileId: me,
          input: li('<', kind: LabValueKind.censored),
        ),
        input('CENSORED_NEEDS_NUMBER'),
      );
      await expectLater(
        svc.recordLab(profileId: me, input: li('< 5')),
        input('VALUE_HAS_COMPARATOR'),
      );
      await expectLater(
        svc.recordLab(
          profileId: me,
          input: li('5', kind: LabValueKind.text),
        ),
        input('TEXT_IS_A_NUMBER'),
      );
      expect(await svc.labTimeline(me), isEmpty, reason: 'nothing saved');
    });

    test('corrections move between kinds; each version is kept', () async {
      final a = await svc.recordLab(
        profileId: me,
        input: li('trace', kind: LabValueKind.text),
      );
      final b = await svc.correctLab(
        profileId: me,
        targetId: a.id,
        input: li('< 15', kind: LabValueKind.censored),
      );
      final c = await svc.correctLab(
        profileId: me,
        targetId: b.id,
        input: li('12'),
      );
      final d = await svc.correctLab(
        profileId: me,
        targetId: c.id,
        input: li('Negatif', kind: LabValueKind.text),
      );
      final entry = (await svc.labTimeline(me)).single;
      expect(entry.heads.single.id, d.id);
      expect(entry.versions.map((v) => v.id), containsAll([a.id, b.id, c.id]));
      expect([b.schemaVersion, c.schemaVersion, d.schemaVersion], [14, 3, 14]);
    });
  });

  group('persistence, fixtures and backup', () {
    late Directory tmp;
    late File vaultFile;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('hhos-f004s2-');
      vaultFile = File('${tmp.path}/$vaultFileName');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('every kind survives close and reopen; the first schema 14 record '
        'makes the one upgrade checkpoint', () async {
      final repo = fileRepo(vaultFile);
      await repo.open();
      final svc = HeartbeatService(repo, clock: _At());
      final me = (await svc.ensureSelfProfile()).id;
      var checkpoints = 0;
      repo.beforeSchemaUpgrade = () async => checkpoints++;
      await svc.recordLab(profileId: me, input: li('91'));
      expect(checkpoints, 0);
      await svc.recordLab(
        profileId: me,
        input: li('> 1000', kind: LabValueKind.censored, unit: 'ng/mL'),
      );
      expect(checkpoints, 1);
      await svc.recordLab(
        profileId: me,
        input: li('Pozitif', kind: LabValueKind.text, unit: ''),
      );
      expect(checkpoints, 1, reason: 'the store is already at 14');
      final before = jsonOf(await repo.records(me));

      final reopened = fileRepo(vaultFile);
      final report = await reopened.open();
      expect(report.warnings, isEmpty);
      final after = await reopened.records(me);
      expect(jsonOf(after), before);
      expect(
        after.map((r) => r.lab!.valueKind),
        containsAll(LabValueKind.values),
      );
    });

    test('the F004 schema 3 fixture loads unchanged: every lab value is a '
        'number or not reported, and re-encodes byte for byte', () {
      final text = File(fixture3).readAsStringSync();
      final state = parseVaultLog(text);
      expect(state.warnings, isEmpty);
      final lines = text.trimRight().split('\n').skip(2).toList();
      final labs = state.records.values.where(
        (r) => r.kind == RecordKind.labResult,
      );
      expect(labs, isNotEmpty);
      for (final r in labs) {
        expect(r.lab!.result, isNull);
        expect(r.lab!.valueKind, LabValueKind.number);
      }
      for (final l in lines) {
        final data = ((jsonDecode(l) as Map)['data']! as Map)
            .cast<String, Object?>();
        final r = HealthRecord.fromJson(data);
        expect(encodeOp('record.append', r.toJson()), l);
      }
    });

    test('the F004-S2 schema 14 fixture replays cleanly and re-encodes byte '
        'for byte', () {
      final text = File(fixture14).readAsStringSync();
      expect(text.startsWith(File(fixture3).readAsStringSync()), isTrue);
      final state = parseVaultLog(text);
      expect(state.warnings, isEmpty);
      String id(int n) =>
          '00000000-0000-4000-8000-0000000002${n.toRadixString(16).padLeft(2, '0')}';
      final crp = state.records[id(0)]!;
      expect(crp.schemaVersion, 14);
      expect(crp.originalText, '< 5');
      expect(crp.lab!.result!.comparator, LabComparator.lessThan);
      expect(crp.lab!.result!.limitText, '5');
      expect(crp.quantity, isNull);
      expect(state.records[id(1)]!.lab!.result!.limitText, '0,01');
      expect(state.records[id(5)]!.lab!.result!.text, 'Reaktif değil');
      expect(state.records[id(9)]!.schemaVersion, 3);
      final glucose = buildTimeline(
        state.records.values.where((r) => r.kind == RecordKind.labResult),
      ).singleWhere((e) => e.rootId == id(7));
      expect(glucose.heads.single.id, id(8));
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
      'a backup round-trips schema 14 lab results into a fresh store',
      () async {
        final log = File(fixture14).readAsStringSync();
        vaultFile.writeAsStringSync(log);
        final repo = fileRepo(vaultFile);
        expect((await repo.open()).warnings, isEmpty);
        const me = '00000000-0000-4000-8000-0000000000a1';
        final before = jsonOf(await repo.records(me));
        final files = FileDataFiles(dataDir: tmp, vault: vaultFile);
        final bundle = createBackupBundle(
          vaultLogText: log,
          appVersion: '0.1.0+1',
          sourceRevision: 'f004s2',
          createdAt: t0,
        );
        final manifest = ((jsonDecode(bundle) as Map)['manifest']! as Map)
            .cast<String, Object?>();
        expect(manifest['record_schema_versions'], contains(14));
        await files.save(
          DataFileKind.backup,
          backupFileName('f004s2', t0),
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

    test('a store with a record newer than schema 14 is refused whole (an '
        'F004-S1 build, at 13, refuses a schema 14 store the same way)', () {
      final log = File(fixture14).readAsStringSync();
      final newer = log.replaceFirst(
        '"schema_version":14,',
        '"schema_version":15,',
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
      // A printed result smuggled under an older schema is never read.
      final older = log.replaceFirst(
        '"schema_version":14,',
        '"schema_version":13,',
      );
      final state = parseVaultLog(older);
      expect(state.warnings, isNotEmpty);
      expect(
        state.records.values.where((r) => r.originalText == '< 5'),
        isEmpty,
      );
    });
  });

  group('calculations never take a censored or text value as a number', () {
    final text = File(fixture14).readAsStringSync();
    final records = parseVaultLog(text).records.values.toList();

    test('labNumberFor gives a number only for a present plain value, and '
        'a reason otherwise', () {
      final byText = {for (final r in records) r.originalText: r};
      expect(labNumberFor(byText['2,1']!).value, 2.1);
      expect(labNumberFor(byText['2,1']!).unit, 'mIU/L');
      for (final t in ['< 5', '<=0,01', '> 1000', '≥ 90', '< 15']) {
        final n = labNumberFor(byText[t]!);
        expect(n.usable, isFalse, reason: t);
        expect(n.value, isNull, reason: t);
        expect(n.notUsableReason, 'LAB_VALUE_CENSORED', reason: t);
      }
      for (final t in ['Negatif', 'Reaktif değil', '1+', 'trace']) {
        expect(labNumberFor(byText[t]!).notUsableReason, 'LAB_VALUE_TEXT');
      }
      final notReported = records.firstWhere(
        (r) =>
            r.kind == RecordKind.labResult &&
            r.valueStatus == ValueStatus.notReported,
      );
      expect(labNumberFor(notReported).notUsableReason, 'LAB_VALUE_MISSING');
      final weight = records.firstWhere((r) => r.kind == RecordKind.bodyWeight);
      expect(labNumberFor(weight).notUsableReason, 'NOT_A_LAB_RESULT');
    });

    test('the derived engines ignore a censored lab value even in a unit '
        'they take: the input stays missing, never the limit', () {
      HealthRecord censoredKg(String id) => HealthRecord(
        id: id,
        profileId: 'p',
        kind: RecordKind.labResult,
        state: RecordState.reported,
        valueStatus: ValueStatus.present,
        quantity: null,
        originalText: '> 70',
        provenance: const Provenance.manual(),
        observedAt: DateTime.utc(2026, 11, 2),
        recordedAt: DateTime.utc(2026, 11, 2),
        lab: const LabDetails(
          analyteLabel: 'synthetic',
          result: LabPrintedResult.censored(
            comparator: LabComparator.greaterThan,
            limitText: '70',
            unit: 'kg',
          ),
        ),
        schemaVersion: 14,
      );
      final rows = derivedFromRecords(
        weights: buildTimeline([censoredKg('a')]),
        heights: buildTimeline([
          for (final r in records)
            if (r.kind == RecordKind.labResult && r.lab!.result != null) r,
        ]),
        waists: const [],
      );
      final bmi = rows.first;
      expect(bmi.computed, isFalse);
      expect(bmi.result.status, isNot(CalcStatus.ok));
      expect(bmi.used, isEmpty, reason: 'no censored or text value used');
      expect(
        bmi.needs,
        containsAll([RecordKind.bodyWeight, RecordKind.height]),
      );
    });
  });

  // Review R017: what the input cannot keep as printed is refused at the
  // field with a message; negative numbers are taken; text keeps no hidden
  // direction marks.
  group('R017 review fixes', () {
    late HeartbeatService svc;
    late String me;
    setUp(() async {
      final repo = inMemoryRepository();
      await repo.open();
      svc = HeartbeatService(repo, clock: _At());
      me = (await svc.ensureSelfProfile()).id;
    });

    test('a limit with spaces inside ("< 1 000", "< 5 ,4") is refused at the '
        'field, never thrown as a record error', () async {
      for (final typed in ['< 1 000', '< 5 ,4', '<5, 4', '> 1 0']) {
        expect(
          () => parseCensoredLab(typed),
          input('LIMIT_HAS_SPACE'),
          reason: typed,
        );
        await expectLater(
          svc.recordLab(
            profileId: me,
            input: li(typed, kind: LabValueKind.censored),
          ),
          input('LIMIT_HAS_SPACE'),
          reason: typed,
        );
      }
      expect(await svc.labTimeline(me), isEmpty);
      // Spaces around the sign and the number are still fine.
      expect(parseCensoredLab('  <  1000 ').limitText, '1000');
    });

    test('the limit is capped like the text field', () {
      expect(() => parseCensoredLab('< ${'1' * 400}'), input('TEXT_TOO_LONG'));
      expect(
        LabPrintedResult.censored(
          comparator: LabComparator.lessThan,
          limitText: '1' * 301,
        ).problem(),
        'LAB_LIMIT_TOO_LONG',
      );
    });

    test(
      'a lab number may be negative: "-", "\u2212" (U+2212) and a space after '
      'the sign',
      () {
        for (final (typed, v) in [
          ('-2', -2.0),
          ('\u22122', -2.0),
          ('-0,5', -0.5),
          ('\u2212 0.5', -0.5),
          ('- 2', -2.0),
          (' -12,25 ', -12.25),
        ]) {
          expect(parseLabNumber(typed), v, reason: typed);
        }
        final zero = parseLabNumber('-0');
        expect(zero, 0);
        expect(zero.isNegative, isFalse, reason: '-0 is stored as 0');
        for (final (typed, code) in [
          ('-', 'NOT_A_NUMBER'),
          ('--2', 'NOT_A_NUMBER'),
          ('-\u22122', 'NOT_A_NUMBER'),
          ('+2', 'NOT_A_NUMBER'),
          ('-2 mmol/L', 'UNIT_IN_VALUE'),
          ('-1,000', 'AMBIGUOUS_SEPARATOR'),
          ('-<2', 'NOT_A_NUMBER'),
        ]) {
          expect(() => parseLabNumber(typed), input(code), reason: typed);
        }
      },
    );

    test('a negative lab result is saved as a number, the typed text kept '
        'exactly', () async {
      final r = await svc.recordLab(
        profileId: me,
        input: li('\u22122', unit: 'mmol/L'),
      );
      expect(r.quantity, const Quantity(-2, 'mmol/L'));
      expect(r.originalText, '\u22122', reason: 'as typed');
      expect(r.schemaVersion, 3);
      r.validate();
      final back = (await svc.labTimeline(me)).single.shown;
      expect(back.quantity!.value, -2);
      expect(labNumberFor(back).value, -2);
    });

    test(
      'weight and the other measurements still refuse a negative number',
      () async {
        await expectLater(
          svc.recordWeightKg(profileId: me, input: '-2'),
          throwsA(isA<InputError>()),
        );
        await expectLater(
          svc.recordWeightKg(profileId: me, input: '\u221270'),
          throwsA(isA<InputError>()),
        );
        expect(await svc.currentWeights(me), isEmpty);
      },
    );

    test('text refuses a signed number, a number with a unit, and a sign '
        'with a number', () {
      for (final (typed, code) in [
        ('\u22122', 'TEXT_IS_A_NUMBER'),
        ('\u2212 2', 'TEXT_IS_A_NUMBER'),
        ('- 2', 'TEXT_IS_A_NUMBER'),
        ('5 mg/dL', 'UNIT_IN_VALUE'),
        ('6 %', 'UNIT_IN_VALUE'),
        ('37mmol/mol', 'UNIT_IN_VALUE'),
        ('-2 mmol/L', 'UNIT_IN_VALUE'),
        ('<5 mg/dL', 'TEXT_IS_CENSORED'),
        ('< 5 mg/dL', 'TEXT_IS_CENSORED'),
        ('≥ 90 %', 'TEXT_IS_CENSORED'),
        ('< 1 000', 'TEXT_IS_CENSORED'),
      ]) {
        expect(() => parseLabText(typed), input(code), reason: typed);
      }
    });

    test('real text, including titres such as "1/160", is kept as printed', () {
      for (final typed in [
        '1+',
        'trace',
        'Pozitif',
        'Reaktif değil',
        '++',
        '1/160',
        '1:80',
        '<1/10',
        'Negatif (<10)',
      ]) {
        expect(parseLabText(typed), typed, reason: typed);
      }
    });

    test('direction overrides and control characters never reach the stored '
        'text or its original text', () async {
      expect(parseLabText('Pozitif\u202E'), 'Pozitif');
      expect(parseLabText('\u202EfitizoP\u202C'), 'fitizoP');
      expect(parseLabText('\u2066Reaktif\u2069 değil\u200F'), 'Reaktif değil');
      expect(parseLabText('Reaktif\ndeğil\t'), 'Reaktif değil');
      expect(() => parseLabText('\u202E\u2067'), input('EMPTY'));
      expect(() => parseLabText('\u202E5,4'), input('TEXT_IS_A_NUMBER'));
      final r = await svc.recordLab(
        profileId: me,
        input: li('Pozitif\u202E', kind: LabValueKind.text, unit: ''),
      );
      expect(r.lab!.result!.text, 'Pozitif');
      expect(r.originalText, 'Pozitif');
      final hidden = RegExp(r'[\u202A-\u202E\u2066-\u2069\x00-\x1F]');
      expect(jsonEncode(r.toJson()), isNot(contains('\u202E')));
      expect(hidden.hasMatch(r.originalText!), isFalse);
    });
  });
}
