/// One lab test over time (F004-S4, A002): current lab results gathered by
/// the same test name, unit and specimen as typed. A view only: no record
/// is written, nothing is mapped to a code and no synonym is guessed. Two
/// names that mean the same test stay apart (same display name is not the
/// same measurand, and a different name is never assumed to be the same).
library;

import '../records/health_record.dart';
import '../trends/trend.dart';

/// A test name or specimen folded for grouping: trimmed, small letters,
/// with the Turkish i forms (I, İ, ı, i) read as one letter, so "İnsülin",
/// "insülin" and "INSÜLIN" match whatever the keyboard. Inner spaces and
/// every other mark stay as typed ("ş" is not "s", "HbA1c" is not
/// "Hb A1c").
String foldLabName(String text) => text
    .trim()
    .replaceAll('İ', 'i')
    .replaceAll(RegExp('[Iİı]'), 'i')
    .toLowerCase()
    .replaceAll('i̇', 'i');

/// The unit a lab result was typed with, trimmed; null when none was given.
/// Units are compared exactly (case matters: "mU/L" is not "MU/L").
String? labUnitOf(HealthRecord r) {
  final u = (r.quantity?.unit ?? r.lab?.result?.unit)?.trim();
  return u == null || u.isEmpty ? null : u;
}

String? _specimenOf(HealthRecord r) {
  final s = r.lab?.specimen?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// What two results must share to be shown as one test over time.
class LabGroupKey {
  const LabGroupKey(this.name, this.unit, this.specimen);

  factory LabGroupKey.of(HealthRecord r) => LabGroupKey(
    foldLabName(r.lab!.analyteLabel),
    labUnitOf(r),
    switch (_specimenOf(r)) {
      final s? => foldLabName(s),
      null => null,
    },
  );

  final String name;
  final String? unit;
  final String? specimen;

  @override
  bool operator ==(Object other) =>
      other is LabGroupKey &&
      other.name == name &&
      other.unit == unit &&
      other.specimen == specimen;

  @override
  int get hashCode => Object.hash(name, unit, specimen);
}

/// One shown lab result and whether it competes with another version of
/// the same entry (a conflict: both are listed, neither is chosen).
typedef LabRow = ({HealthRecord record, bool conflict});

/// Current results of one test, newest first, as the Labs list shows them.
class LabGroup {
  const LabGroup(this.key, this.rows);

  final LabGroupKey key;
  final List<LabRow> rows;

  /// The newest result's name, unit and specimen as typed (trimmed).
  String get label => rows.first.record.lab!.analyteLabel.trim();
  String? get unit => labUnitOf(rows.first.record);
  String? get specimen => _specimenOf(rows.first.record);

  int get length => rows.length;

  /// Results drawn on the chart, oldest first: present plain numbers
  /// ([labNumberFor] usable) that compete with no other version. The unit
  /// is the group's own, so one axis never mixes units.
  List<TrendPoint> get chartPoints {
    final out = <TrendPoint>[
      for (final row in rows)
        if (!row.conflict)
          if (labNumberFor(row.record) case LabNumber(:final value?))
            TrendPoint(
              at: row.record.observedAt,
              values: [value],
              record: row.record,
            ),
    ];
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// How many results are listed but not drawn, by reason (the
  /// `notUsableReason` of [labNumberFor], or `LAB_VERSION_CONFLICT`).
  Map<String, int> get notDrawn {
    final out = <String, int>{};
    for (final row in rows) {
      final reason = row.conflict
          ? 'LAB_VERSION_CONFLICT'
          : labNumberFor(row.record).notUsableReason;
      if (reason != null) out[reason] = (out[reason] ?? 0) + 1;
    }
    return out;
  }
}

/// Groups [rows] (current versions, newest first; entered-in-error and
/// deleted entries already left out by the timeline) by [LabGroupKey]. The
/// order is that of each group's newest result; rows keep their order.
List<LabGroup> labGroups(Iterable<LabRow> rows) {
  final byKey = <LabGroupKey, List<LabRow>>{};
  for (final row in rows) {
    if (row.record.lab == null) continue;
    byKey.putIfAbsent(LabGroupKey.of(row.record), () => []).add(row);
  }
  return [for (final e in byKey.entries) LabGroup(e.key, e.value)];
}
