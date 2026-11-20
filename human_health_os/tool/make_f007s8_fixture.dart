// Writes the record schema 16 fixture (F007-S8, D-048) with the app's own
// writer: the committed schema 15 fixture of F004-S3, unchanged, followed
// by capillary glucose readings (mg/dL and mmol/L as chosen, never
// converted, with and without a meal timing), a not-measured glucose, body
// fat as a scale showed it (state reported) and a correction of each,
// written the way the F007-S8 build writes them. Run from human_health_os/:
//   dart run tool/make_f007s8_fixture.dart \
//     test/fixtures/vault/v1_f004s3_schema15.hhoslog.jsonl \
//     test/fixtures/vault/v1_f007s8_schema16.hhoslog.jsonl
// Synthetic data only. A committed fixture is never regenerated or edited.
import 'dart:io';

import 'package:human_health_os/src/data/local/vault_log.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

const profileId = '00000000-0000-4000-8000-0000000000a1';
String id(int n) =>
    '00000000-0000-4000-8000-0000000004${n.toRadixString(16).padLeft(2, '0')}';
DateTime at(int minute) => DateTime.utc(2026, 11, 20, 7, minute);

HealthRecord measure(
  int n,
  RecordKind kind, {
  String? typed,
  double? value,
  String? unit,
  GlucoseTiming? timing,
  String? note,
  String? supersedes,
  DateTime? observed,
}) {
  final present = typed != null;
  return HealthRecord(
    id: id(n),
    profileId: profileId,
    kind: kind,
    state: kind.isDeviceEstimate ? RecordState.reported : RecordState.observed,
    valueStatus: present ? ValueStatus.present : ValueStatus.notMeasured,
    quantity: present ? Quantity(value!, unit ?? kind.unit) : null,
    originalText: typed,
    provenance: const Provenance.manual(),
    observedAt: observed ?? at(n),
    recordedAt: at(n),
    supersedesId: supersedes,
    amendReason: supersedes == null ? null : AmendReason.correction,
    context: note,
    details: timing == null ? null : GlucoseTimingDetails(timing),
    schemaVersion: HealthRecord.writeSchemaFor(kind),
  );
}

void main(List<String> args) {
  final base = File(args[0]).readAsStringSync();
  const g = RecordKind.capillaryGlucose;
  const fat = RecordKind.bodyFatPercentage;
  final records = <HealthRecord>[
    // mg/dL, fasting.
    measure(
      0,
      g,
      typed: '95',
      value: 95,
      unit: 'mg/dL',
      timing: GlucoseTiming.fasting,
    ),
    // mmol/L with a Turkish comma, after a meal, with a note.
    measure(
      1,
      g,
      typed: '7,8',
      value: 7.8,
      unit: 'mmol/L',
      timing: GlucoseTiming.afterMeal,
      note: 'yemekten 2 saat sonra',
    ),
    // No timing given: no details at all.
    measure(2, g, typed: '112', value: 112, unit: 'mg/dL'),
    // A correction of the mmol/L reading: a better number, same unit and
    // timing, measured earlier than it was saved.
    measure(
      3,
      g,
      typed: '6,8',
      value: 6.8,
      unit: 'mmol/L',
      timing: GlucoseTiming.afterMeal,
      note: 'yemekten 2 saat sonra',
      supersedes: id(1),
      observed: at(1),
    ),
    // "I did not measure this": no number, no unit, no timing.
    measure(4, g),
    // Body fat as the scale showed it: reported, never observed.
    measure(5, fat, typed: '24,5', value: 24.5),
    // Its correction: the scale's other reading that morning.
    measure(
      6,
      fat,
      typed: '24,1',
      value: 24.1,
      supersedes: id(5),
      observed: at(5),
    ),
    // The timing "other", with a decimal mg/dL.
    measure(
      7,
      g,
      typed: '101.5',
      value: 101.5,
      unit: 'mg/dL',
      timing: GlucoseTiming.other,
    ),
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
