/// Record use cases: a local SELF profile, canonical body-weight observations
/// (F002) and their timeline with corrections, withdrawals and deletions
/// (F003), lab results as printed (F004) and measurements typed by hand
/// (F007), medicines (F008), daily domains (F007), conditions, preventive
/// items and documents (F009/F010), all through the [HealthRepository]
/// port. [HeartbeatService] is the one facade; each group of use cases is a
/// mixin in its own part file, and the typed-text parsers are in
/// heartbeat_parsing.dart.
library;

import '../core/ids.dart';
import 'input_error.dart';
import 'measured_at.dart';
import '../domain/ports/health_repository.dart';
import '../domain/profile/profile.dart';
import '../domain/records/health_record.dart';

export 'input_error.dart';

part 'heartbeat_daily.dart';
part 'heartbeat_entries.dart';
part 'heartbeat_labs.dart';
part 'heartbeat_measurements.dart';
part 'heartbeat_medications.dart';
part 'heartbeat_parsing.dart';

// The reference interval parsers stay in this file: the order check of the
// two bounds is the one place app code reads them as numbers, and the lab
// guard test allows it only here and in lab_details.dart.

/// One bound of a reference interval as printed ("4,0", "-2", "130"),
/// returned exactly as typed apart from surrounding spaces. Refused, each
/// naming [field]: a sign such as "<" (`INTERVAL_BOUND_HAS_SIGN`), a unit
/// after the number (`INTERVAL_BOUND_HAS_UNIT`), spaces inside
/// (`INTERVAL_BOUND_HAS_SPACE`), and what [parseLabDecimal] refuses
/// (`NOT_A_NUMBER`, `AMBIGUOUS_SEPARATOR`). A negative low is allowed.
String parseIntervalBound(String raw, String field) {
  final t = raw.trim();
  // A plus sign is a sign too ("+4"), never a space problem.
  if (_comparatorFirst.hasMatch(t) || t.startsWith('+')) {
    throw InputError('INTERVAL_BOUND_HAS_SIGN', field);
  }
  final negative = _labMinus.hasMatch(t);
  final digits = negative ? t.substring(1) : t;
  if (_unitAfterNumber.hasMatch(digits.trim())) {
    throw InputError('INTERVAL_BOUND_HAS_UNIT', field);
  }
  try {
    final v = parseLabDecimal(digits);
    if (!v.isFinite) throw const InputError('NOT_A_NUMBER');
  } on InputError catch (e) {
    throw InputError(e.code == 'EMPTY' ? 'NOT_A_NUMBER' : e.code, field);
  }
  if (!LabReferenceInterval.boundPattern.hasMatch(t)) {
    throw InputError('INTERVAL_BOUND_HAS_SPACE', field);
  }
  return t;
}

/// The reference interval as the person typed it from the report, or null
/// when every field is blank. Fields: `refLow`, `refHigh`, `refUnit`,
/// `refPartition`. A unit or partition alone is `INTERVAL_NEEDS_BOUND`
/// (on `refLow`); a bound without a unit is `INTERVAL_UNIT_REQUIRED`; a low
/// above the high is `INTERVAL_LOW_ABOVE_HIGH` (on `refLow`). The bounds
/// are never compared with any result.
LabReferenceInterval? parseReferenceInterval({
  required String low,
  required String high,
  required String unit,
  required String partition,
}) {
  final u = labTextAsStored(unit);
  final p = labTextAsStored(partition);
  if (low.trim().isEmpty && high.trim().isEmpty && u.isEmpty && p.isEmpty) {
    return null;
  }
  if (low.trim().isEmpty && high.trim().isEmpty) {
    throw const InputError('INTERVAL_NEEDS_BOUND', 'refLow');
  }
  final lo = low.trim().isEmpty ? null : parseIntervalBound(low, 'refLow');
  final hi = high.trim().isEmpty ? null : parseIntervalBound(high, 'refHigh');
  if (u.isEmpty) throw const InputError('INTERVAL_UNIT_REQUIRED', 'refUnit');
  if (u.runes.length > LabReferenceInterval.maxTextLength) {
    throw const InputError('TEXT_TOO_LONG', 'refUnit');
  }
  if (p.runes.length > LabReferenceInterval.maxTextLength) {
    throw const InputError('TEXT_TOO_LONG', 'refPartition');
  }
  if (lo != null &&
      hi != null &&
      LabReferenceInterval.boundValue(lo) >
          LabReferenceInterval.boundValue(hi)) {
    throw const InputError('INTERVAL_LOW_ABOVE_HIGH', 'refLow');
  }
  return LabReferenceInterval(
    lowText: lo,
    highText: hi,
    unit: u,
    partition: p.isEmpty ? null : p,
  );
}

/// What every group of use cases needs from the service: the repository,
/// the clock, the id generator, the current version of an entry and the
/// live heads of one kind. [HeartbeatService] supplies the first three.
abstract class _HeartbeatCore {
  HealthRepository get repository;
  Clock get clock;
  IdGenerator get _ids;

  /// The live version [targetId] of a live entry, or an [InputError]. Only
  /// the current version can be amended: amending an older one would fork
  /// the history (conflicts come from sync or import, never from here).
  Future<HealthRecord> _currentTarget(String profileId, String targetId) async {
    final all = await repository.records(profileId);
    if (!all.any((r) => r.id == targetId)) {
      throw const InputError('TARGET_NOT_FOUND');
    }
    for (final e in buildTimeline(all)) {
      for (final h in e.heads) {
        if (h.id == targetId) return h;
      }
    }
    throw const InputError('TARGET_NOT_CURRENT');
  }

  /// The live heads of [kind] whose details are a [D], the latest first by
  /// [by]. Every list of one kind of entry reads through here.
  Future<List<HealthRecord>> _liveHeads<D extends RecordDetails>(
    String profileId,
    RecordKind kind, {
    required _NewestBy by,
  }) async {
    final all = await repository.records(profileId, kind: kind);
    return [
      for (final e in buildTimeline(all))
        for (final h in e.heads)
          if (h.details is D) h,
    ]..sort(
      by == _NewestBy.recorded
          ? (a, b) => b.recordedAt.compareTo(a.recordedAt)
          : (a, b) => b.observedAt.compareTo(a.observedAt),
    );
  }
}

/// Which time puts an entry first in a list of live heads.
enum _NewestBy { recorded, observed }

/// The record use cases of Human OS, one facade over focused groups:
/// measurements and weight, labs, medications, daily domains, and
/// conditions, preventive items and documents (each in its own part).
class HeartbeatService extends _HeartbeatCore
    with
        _MeasurementUseCases,
        _LabUseCases,
        _MedicationUseCases,
        _DailyUseCases,
        _EntryUseCases {
  HeartbeatService(
    this.repository, {
    this.clock = const SystemClock(),
    IdGenerator? ids,
  }) : _ids = ids ?? UuidV4Generator();

  @override
  final HealthRepository repository;
  @override
  final Clock clock;
  @override
  final IdGenerator _ids;

  /// Returns the existing SELF profile, or creates one the first time.
  /// The id lives inside the vault, so the same profile survives restarts
  /// and moving a portable folder.
  Future<Profile> ensureSelfProfile() async {
    final existing = (await repository.profiles()).where(
      (p) => p.type == ProfileType.self,
    );
    if (existing.isNotEmpty) return existing.first;
    final p = Profile(
      id: _ids.newId(),
      type: ProfileType.self,
      createdAt: clock.nowUtc(),
    );
    await repository.putProfile(p);
    return p;
  }

  /// Every fact of the profile on one timeline. [includeHidden] adds deleted
  /// and withdrawn entries (history view).
  Future<List<TimelineEntry>> timeline(
    String profileId, {
    bool includeHidden = false,
  }) async => buildTimeline(
    await repository.records(profileId),
    includeHidden: includeHidden,
  );

  /// Withdraws [targetId] as entered in error, or deletes its whole fact
  /// ([AmendReason.deleted]). Appends a marker; nothing is rewritten.
  Future<HealthRecord> amend({
    required String profileId,
    required String targetId,
    required AmendReason reason,
  }) async {
    if (!reason.isMarker) throw ArgumentError.value(reason, 'reason');
    final target = await _currentTarget(profileId, targetId);
    final now = clock.nowUtc();
    final marker = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: target.kind,
      state: RecordState.reported,
      valueStatus: ValueStatus.notApplicable,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: target.observedAt,
      recordedAt: now,
      supersedesId: target.id,
      amendReason: reason,
      deletedAt: reason == AmendReason.deleted ? now : null,
      schemaVersion: HealthRecord.writeSchemaFor(target.kind),
    );
    await repository.appendRecord(marker);
    return marker;
  }
}
