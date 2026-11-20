// F004-S4 (A002): one lab test over time. Results are grouped only by the
// same name, unit and specimen as typed (names folded for case, with the
// Turkish i forms read as one letter; units compared exactly), only current
// versions count, entered-in-error and deleted results are left out, and
// only present plain numbers are drawn. A view: nothing is written.
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/config/app_config.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/labs/lab_groups.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/trends/trend.dart';

const dev = AppConfig(
  profile: BuildProfile.development,
  version: 't',
  sourceRevision: 't',
);

Future<AppServices> services() async {
  final repo = inMemoryRepository();
  await repo.open();
  return servicesFor(dev, HostPlatform.linux, repo);
}

LabInput lab(
  String analyte,
  String value, {
  String unit = '%',
  String date = '2026-10-03',
  String specimen = '',
  String laboratory = '',
  String range = '',
  LabValueKind kind = LabValueKind.number,
  bool notReported = false,
}) => LabInput(
  analyte: analyte,
  value: value,
  notReported: notReported,
  unit: unit,
  sampleDate: date,
  specimen: specimen,
  laboratory: laboratory,
  referenceText: range,
  kind: kind,
);

Future<List<LabGroup>> groupsOf(AppServices s) async {
  final entries = await s.heartbeat.labTimeline(s.self.id);
  return labGroups([
    for (final e in entries)
      for (final r in e.heads)
        (
          record: r,
          entryId: e.rootId,
          conflict: e.status == EntryStatus.conflict,
        ),
  ]);
}

void main() {
  test('the name fold: case-insensitive, Turkish i forms as one letter, '
      'nothing else changed', () {
    expect(foldLabName('  HbA1c '), foldLabName('hba1c'));
    expect(foldLabName('İnsülin'), foldLabName('insülin'));
    expect(foldLabName('INSÜLIN'), foldLabName('insülin'));
    expect(foldLabName('İNSÜLİN'), foldLabName('ınsülın'));
    expect(foldLabName('İnsülin'), foldLabName('insülin'));
    expect(foldLabName('Hb A1c'), isNot(foldLabName('HbA1c')));
    expect(foldLabName('Şeker'), isNot(foldLabName('Seker')));
    expect(foldLabName('Insulin'), isNot(foldLabName('İnsülin')));
  });

  test('same name, unit and specimen as typed share a group; a different '
      'name, unit or specimen never does', () async {
    final s = await services();
    final me = s.self.id;
    final h = s.heartbeat;
    await h.recordLab(
      profileId: me,
      input: lab('HbA1c', '5,4', date: '2026-10-03', specimen: 'Kan'),
    );
    await h.recordLab(
      profileId: me,
      input: lab('hba1c', '5,8', date: '2026-04-01', specimen: 'kan'),
    );
    await h.recordLab(
      profileId: me,
      input: lab('HbA1c', '36', unit: 'mmol/mol', specimen: 'Kan'),
    );
    await h.recordLab(
      profileId: me,
      input: lab('HbA1c', '5,6', specimen: 'Serum'),
    );
    await h.recordLab(profileId: me, input: lab('HbA1c', '5,5'));
    await h.recordLab(
      profileId: me,
      input: lab('Glikozile hemoglobin', '5,4', specimen: 'Kan'),
    );
    await h.recordLab(
      profileId: me,
      input: lab('TSH', '2', unit: 'mU/L', date: '2026-01-02'),
    );
    await h.recordLab(
      profileId: me,
      input: lab('TSH', '2', unit: 'MU/L', date: '2026-01-03'),
    );
    final groups = await groupsOf(s);
    expect(groups, hasLength(7));
    final kan = groups.singleWhere(
      (g) => g.key == const LabGroupKey('hba1c', '%', 'kan'),
    );
    expect(kan.length, 2);
    expect(kan.label, 'HbA1c', reason: 'the newest as typed');
    expect(kan.specimen, 'Kan');
    expect(
      groups.where((g) => g.key.name == 'hba1c'),
      hasLength(4),
      reason: 'another unit, another specimen and none stay apart',
    );
    expect(
      groups.where((g) => g.key.name == 'tsh'),
      hasLength(2),
      reason: 'units are compared exactly',
    );
    expect(
      groups.where((g) => g.label == 'Glikozile hemoglobin').single.length,
      1,
      reason: 'no synonym is guessed',
    );
  });

  test('Turkish names typed with either keyboard share a group', () async {
    final s = await services();
    final me = s.self.id;
    for (final (name, date) in [
      ('İnsülin', '2026-10-03'),
      ('insülin', '2026-09-03'),
      ('INSÜLIN', '2026-08-03'),
    ]) {
      await s.heartbeat.recordLab(
        profileId: me,
        input: lab(name, '8', unit: 'µIU/mL', date: date),
      );
    }
    final groups = await groupsOf(s);
    expect(groups.single.length, 3);
    expect(groups.single.label, 'İnsülin');
  });

  test('only the current version counts; entered-in-error and deleted '
      'results are left out; nothing is written', () async {
    final s = await services();
    final me = s.self.id;
    final h = s.heartbeat;
    final a = await h.recordLab(
      profileId: me,
      input: lab('LDL', '901', unit: 'mg/dL', date: '2026-10-03'),
    );
    await h.correctLab(
      profileId: me,
      targetId: a.id,
      input: lab('LDL', '91', unit: 'mg/dL', date: '2026-10-03'),
    );
    final b = await h.recordLab(
      profileId: me,
      input: lab('LDL', '120', unit: 'mg/dL', date: '2026-06-01'),
    );
    await h.amend(
      profileId: me,
      targetId: b.id,
      reason: AmendReason.enteredInError,
    );
    final c = await h.recordLab(
      profileId: me,
      input: lab('LDL', '140', unit: 'mg/dL', date: '2026-05-01'),
    );
    await h.amend(profileId: me, targetId: c.id, reason: AmendReason.deleted);
    await h.recordLab(
      profileId: me,
      input: lab('LDL', '110', unit: 'mg/dL', date: '2026-01-01'),
    );
    final before = (await s.heartbeat.repository.records(me)).length;
    final g = (await groupsOf(s)).single;
    expect([for (final r in g.rows) r.record.originalText], ['91', '110']);
    expect([for (final p in g.chartPoints) p.values.single], [110, 91]);
    expect((await s.heartbeat.repository.records(me)).length, before);
  });

  test('limits, text and missing values are listed, never drawn', () async {
    final s = await services();
    final me = s.self.id;
    final h = s.heartbeat;
    await h.recordLab(
      profileId: me,
      input: lab('CRP', '3', unit: 'mg/L', date: '2026-10-03'),
    );
    await h.recordLab(
      profileId: me,
      input: lab(
        'CRP',
        '< 5',
        unit: 'mg/L',
        date: '2026-09-03',
        kind: LabValueKind.censored,
      ),
    );
    await h.recordLab(
      profileId: me,
      input: lab(
        'CRP',
        'Hemolizli',
        unit: 'mg/L',
        date: '2026-08-03',
        kind: LabValueKind.text,
      ),
    );
    final g = (await groupsOf(s)).single;
    expect(g.length, 3);
    expect(g.chartPoints.single.values.single, 3);
    expect(g.notDrawn, {'LAB_VALUE_CENSORED': 1, 'LAB_VALUE_TEXT': 1});
  });

  test('two competing versions of one entry count as one result', () async {
    final s = await services();
    final me = s.self.id;
    final a = await s.heartbeat.recordLab(
      profileId: me,
      input: lab('LDL', '901', unit: 'mg/dL', date: '2026-10-03'),
    );
    HealthRecord fix(String id, double v) => HealthRecord(
      id: id,
      profileId: me,
      kind: RecordKind.labResult,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: Quantity(v, 'mg/dL'),
      originalText: '$v',
      provenance: const Provenance.manual(),
      observedAt: a.observedAt,
      recordedAt: a.recordedAt.add(const Duration(minutes: 1)),
      supersedesId: a.id,
      amendReason: AmendReason.correction,
      lab: a.lab,
      schemaVersion: a.schemaVersion,
    );
    await s.heartbeat.repository.appendRecord(fix('c1', 91));
    await s.heartbeat.repository.appendRecord(fix('c2', 92));
    var g = (await groupsOf(s)).single;
    expect(g.rows, hasLength(2), reason: 'both versions are listed');
    expect(g.length, 1, reason: 'one entry, so not a group of two');
    expect(g.chartPoints, isEmpty, reason: 'a conflict is not drawn');
    await s.heartbeat.recordLab(
      profileId: me,
      input: lab('LDL', '110', unit: 'mg/dL', date: '2026-01-01'),
    );
    g = (await groupsOf(s)).single;
    expect(g.length, 2);
  });

  test('results drawn on the same sample date are noticed', () async {
    final s = await services();
    final me = s.self.id;
    await s.heartbeat.recordLab(profileId: me, input: lab('K', '4,1'));
    expect((await groupsOf(s)).single.sameDayDrawn, isFalse);
    await s.heartbeat.recordLab(profileId: me, input: lab('K', '4,3'));
    expect((await groupsOf(s)).single.sameDayDrawn, isTrue);
  });

  test('axis labels: lab charts take the decimals the span needs; the '
      'measurement labels are unchanged', () {
    // Troponin 0.01 to 0.03 ng/mL: one decimal would read "0.0" thrice.
    final r = axisRange([0.01, 0.02, 0.03], 0.006);
    final lines = readingLines(r);
    expect({for (final v in lines) axisLabel(v, '.')}, {'0.0'});
    final d = axisDecimals(r);
    final labels = [for (final v in lines) axisLabel(v, '.', d)];
    expect(labels.toSet(), hasLength(3), reason: '$labels');
    expect(labels, ['0.01', '0.02', '0.03']);
    expect(axisLabel(0.02, ',', d), '0,02');
    // Measurement charts keep their output: one decimal under 100.
    expect(axisLabel(72.44, '.'), '72.4');
    expect(axisLabel(120.4, '.'), '120');
    expect(axisDecimals(axisRange([70, 72], 5)), 0);
    expect(axisDecimals(axisRange([5.4, 5.8], 1)), 1);
  });
}
