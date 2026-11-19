// Writes the record schema 15 fixture (F004-S3, D-045) with the app's own
// writer: the committed schema 14 fixture of F004-S2, unchanged, followed
// by lab results that keep what else the report printed (report time,
// method, the reference interval as printed), written the way the F004-S3
// build writes them. Run from human_health_os/:
//   dart run tool/make_f004s3_fixture.dart \
//     test/fixtures/vault/v1_f004s2_schema14.hhoslog.jsonl \
//     test/fixtures/vault/v1_f004s3_schema15.hhoslog.jsonl
// Synthetic data only. A committed fixture is never regenerated or edited.
import 'dart:io';

import 'package:human_health_os/src/data/local/vault_log.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

const profileId = '00000000-0000-4000-8000-0000000000a1';
String id(int n) =>
    '00000000-0000-4000-8000-0000000003${n.toRadixString(16).padLeft(2, '0')}';
final sample = DateTime.utc(2026, 11, 4);
DateTime at(int minute) => DateTime.utc(2026, 11, 5, 9, minute);
final reported = DateTime.utc(2026, 11, 4, 14, 20);

HealthRecord lab(
  int n, {
  required String analyte,
  required String typed,
  Quantity? q,
  LabPrintedResult? printed,
  String? range,
  String? flag,
  DateTime? reportedAt,
  String? method,
  LabReferenceInterval? interval,
  String? supersedes,
}) {
  final details = LabDetails(
    analyteLabel: analyte,
    referenceText: range,
    sourceFlag: flag,
    result: printed,
    reportedAt: reportedAt,
    method: method,
    referenceInterval: interval,
  );
  return HealthRecord(
    id: id(n),
    profileId: profileId,
    kind: RecordKind.labResult,
    state: RecordState.reported,
    valueStatus: ValueStatus.present,
    quantity: q,
    originalText: typed,
    provenance: const Provenance.manual(),
    observedAt: sample,
    recordedAt: at(n),
    supersedesId: supersedes,
    amendReason: supersedes == null ? null : AmendReason.correction,
    lab: details,
    schemaVersion: HealthRecord.writeSchemaForLab(details),
  );
}

void main(List<String> args) {
  final base = File(args[0]).readAsStringSync();
  final records = <HealthRecord>[
    // Everything: report time, method and both bounds with a partition.
    lab(
      0,
      analyte: 'HbA1c',
      typed: '5,4',
      q: const Quantity(5.4, '%'),
      range: '4,0 - 6,0',
      reportedAt: reported,
      method: 'HPLC',
      interval: const LabReferenceInterval(
        lowText: '4,0',
        highText: '6,0',
        unit: '%',
        partition: 'Kadın 20-49 yaş',
      ),
    ),
    // Only a high, as for a range printed "< 130".
    lab(
      1,
      analyte: 'LDL Kolesterol',
      typed: '142',
      q: const Quantity(142, 'mg/dL'),
      range: '< 130',
      flag: 'H',
      interval: const LabReferenceInterval(highText: '130', unit: 'mg/dL'),
    ),
    // A negative low.
    lab(
      2,
      analyte: 'Baz açığı',
      typed: '-1',
      q: const Quantity(-1, 'mmol/L'),
      interval: const LabReferenceInterval(
        lowText: '-2',
        highText: '2',
        unit: 'mmol/L',
      ),
    ),
    // The method alone.
    lab(
      3,
      analyte: 'Glukoz',
      typed: '91',
      q: const Quantity(91, 'mg/dL'),
      method: 'enzimatik',
    ),
    // A censored result with a report time (schema 15 holds 14's object).
    lab(
      4,
      analyte: 'CRP',
      typed: '< 0,5',
      printed: const LabPrintedResult.censored(
        comparator: LabComparator.lessThan,
        limitText: '0,5',
        unit: 'mg/L',
      ),
      reportedAt: reported,
    ),
    // A correction that adds the interval to the glucose result.
    lab(
      5,
      analyte: 'Glukoz',
      typed: '91',
      q: const Quantity(91, 'mg/dL'),
      method: 'enzimatik',
      interval: const LabReferenceInterval(
        lowText: '70',
        highText: '100',
        unit: 'mg/dL',
        partition: 'adult',
      ),
      supersedes: id(3),
    ),
    // A plain number by the same build stays at schema 3.
    lab(6, analyte: 'TSH', typed: '1,9', q: const Quantity(1.9, 'mIU/L')),
  ];
  final out = StringBuffer(base);
  for (final r in records) {
    r.validate();
    out.writeln(encodeOp('record.append', r.toJson()));
  }
  final state = parseVaultLog(out.toString());
  if (state.warnings.isNotEmpty) {
    throw StateError('fixture does not replay cleanly: ${state.warnings}');
  }
  File(args[1]).writeAsStringSync(out.toString());
  stdout.writeln('wrote ${args[1]} (${records.length} records added)');
}
