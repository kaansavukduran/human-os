// Writes the record schema 14 fixture (F004-S2, D-043) with the app's own
// writer: the committed schema 1-3 fixture of F004, unchanged, followed by
// lab results that are not plain numbers, written the way the F004-S2 build
// writes them. Run from human_health_os/:
//   dart run tool/make_f004s2_fixture.dart \
//     test/fixtures/vault/v1_f004_schema3.hhoslog.jsonl \
//     test/fixtures/vault/v1_f004s2_schema14.hhoslog.jsonl
// Synthetic data only. A committed fixture is never regenerated or edited.
import 'dart:io';

import 'package:human_health_os/src/data/local/vault_log.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

const profileId = '00000000-0000-4000-8000-0000000000a1';
String id(int n) =>
    '00000000-0000-4000-8000-0000000002${n.toRadixString(16).padLeft(2, '0')}';
final sample = DateTime.utc(2026, 11, 2);
DateTime at(int minute) => DateTime.utc(2026, 11, 3, 9, minute);

HealthRecord lab(
  int n, {
  required String analyte,
  required String typed,
  LabPrintedResult? printed,
  Quantity? q,
  String? range,
  String? flag,
  String? supersedes,
}) => HealthRecord(
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
  lab: LabDetails(
    analyteLabel: analyte,
    referenceText: range,
    sourceFlag: flag,
    result: printed,
  ),
  schemaVersion: printed == null
      ? HealthRecord.writeSchemaFor(RecordKind.labResult)
      : HealthRecord.labPrintedResultSchema,
);

void main(List<String> args) {
  final base = File(args[0]).readAsStringSync();
  final records = <HealthRecord>[
    lab(
      0,
      analyte: 'CRP',
      typed: '< 5',
      printed: const LabPrintedResult.censored(
        comparator: LabComparator.lessThan,
        limitText: '5',
        unit: 'mg/L',
      ),
      range: '0 - 5',
    ),
    lab(
      1,
      analyte: 'Troponin I',
      typed: '<=0,01',
      printed: const LabPrintedResult.censored(
        comparator: LabComparator.lessOrEqual,
        limitText: '0,01',
        unit: 'ng/mL',
      ),
    ),
    lab(
      2,
      analyte: 'Ferritin',
      typed: '> 1000',
      printed: const LabPrintedResult.censored(
        comparator: LabComparator.greaterThan,
        limitText: '1000',
        unit: 'ng/mL',
      ),
      flag: 'H',
    ),
    lab(
      3,
      analyte: 'eGFR',
      typed: '≥ 90',
      printed: const LabPrintedResult.censored(
        comparator: LabComparator.greaterOrEqual,
        limitText: '90',
        unit: 'mL/min/1.73m²',
      ),
    ),
    lab(
      4,
      analyte: 'HBsAg',
      typed: 'Negatif',
      printed: const LabPrintedResult.text(text: 'Negatif'),
    ),
    lab(
      5,
      analyte: 'Anti-HCV',
      typed: 'Reaktif değil',
      printed: const LabPrintedResult.text(text: 'Reaktif değil'),
    ),
    lab(
      6,
      analyte: 'İdrar protein',
      typed: '1+',
      printed: const LabPrintedResult.text(text: '1+'),
    ),
    // A text result corrected to a censored one (same observation).
    lab(
      7,
      analyte: 'Glukoz (idrar)',
      typed: 'trace',
      printed: const LabPrintedResult.text(text: 'trace'),
    ),
    lab(
      8,
      analyte: 'Glukoz (idrar)',
      typed: '< 15',
      printed: const LabPrintedResult.censored(
        comparator: LabComparator.lessThan,
        limitText: '15',
        unit: 'mg/dL',
      ),
      supersedes: id(7),
    ),
    // A plain number written by the same build stays at schema 3.
    lab(9, analyte: 'TSH', typed: '2,1', q: const Quantity(2.1, 'mIU/L')),
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
