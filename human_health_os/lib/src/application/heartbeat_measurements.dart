part of 'heartbeat_service.dart';

/// What a person typed for one measurement (F007). A blood pressure reading
/// uses [systolic] and [diastolic]; the other kinds use [value]. [context]
/// is optional free text ("sitting, left arm"), kept exactly as typed.
class MeasurementInput {
  const MeasurementInput({
    this.value = '',
    this.systolic = '',
    this.diastolic = '',
    this.context = '',
    this.when = '',
    this.notMeasured = false,
    this.unit = '',
    this.glucoseTiming,
  });

  final String value;
  final String systolic;
  final String diastolic;
  final String context;

  /// The time typed in the "When" field. Blank means the save time for a
  /// new entry and the unchanged time for a correction (G-48, D-047).
  final String when;

  /// "I did not measure this" (D-047): saved as `notMeasured` with no
  /// number, never as zero. Only for [notMeasuredKinds]. A correction of a
  /// reading never becomes "not measured"; a correction of a "not measured"
  /// entry with no number typed stays one (its time or note changes).
  final bool notMeasured;

  /// The unit chosen for a kind with more than one ([RecordKind.units]:
  /// mg/dL or mmol/L for capillary glucose), kept as chosen and never
  /// converted (D-048). Blank: none chosen (a correction keeps the stored
  /// unit). Ignored for a kind with one unit.
  final String unit;

  /// Before or after eating, as chosen for a capillary glucose (D-048);
  /// null = not given. Never inferred and never interpreted.
  final GlucoseTiming? glucoseTiming;
}

/// The kinds for which "I did not measure this" is offered (D-047): the
/// vital signs a person checks on a routine (a daily blood pressure), where
/// a missed reading is itself worth keeping. Waist and height are measured
/// now and then, so a "not measured" entry for them would say nothing.
const Set<RecordKind> notMeasuredKinds = {
  RecordKind.bloodPressure,
  RecordKind.restingHeartRate,
  RecordKind.bodyTemperature,
  RecordKind.oxygenSaturation,
  RecordKind.respiratoryRate,
  // A home glucose check is often on a routine too (D-048); body fat from a
  // scale is now and then, like waist and height.
  RecordKind.capillaryGlucose,
};

/// Body weight (F002/F003) and measurements typed by hand (F007).
mixin _MeasurementUseCases on _HeartbeatCore {
  double _weightKg(String input) {
    final value = parseLabDecimal(input);
    if (value <= 0 || value > 700) throw const InputError('OUT_OF_RANGE');
    return value;
  }

  /// Records a manually entered body weight in kg as an OBSERVED fact.
  Future<HealthRecord> recordWeightKg({
    required String profileId,
    required String input,
    DateTime? observedAt,
  }) async {
    final value = _weightKg(input);
    final now = clock.nowUtc();
    final when = (observedAt ?? now).toUtc();
    if (isFutureTime(when, now)) throw const InputError('FUTURE_TIME');
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.bodyWeight,
      state: RecordState.observed,
      valueStatus: ValueStatus.present,
      quantity: Quantity(value, 'kg'),
      originalText: input.trim(),
      provenance: const Provenance.manual(),
      observedAt: when,
      recordedAt: now,
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Current weights (heads of live entries), newest first.
  Future<List<HealthRecord>> currentWeights(String profileId) async =>
      currentRecords(
        await repository.records(profileId, kind: RecordKind.bodyWeight),
      );

  /// Body-weight timeline entries, newest first (ladder F003).
  Future<List<TimelineEntry>> weightTimeline(String profileId) async =>
      buildTimeline(
        await repository.records(profileId, kind: RecordKind.bodyWeight),
      );

  /// Saves a better value for the same observation. The old version stays
  /// in history; the new one is a manual, OBSERVED entry.
  Future<HealthRecord> correctWeightKg({
    required String profileId,
    required String targetId,
    required String input,
  }) async {
    final value = _weightKg(input);
    final target = await _currentTarget(profileId, targetId);
    if (target.kind != RecordKind.bodyWeight) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: target.kind,
      state: RecordState.observed,
      valueStatus: ValueStatus.present,
      quantity: Quantity(value, 'kg'),
      originalText: input.trim(),
      provenance: const Provenance.manual(),
      observedAt: target.observedAt,
      recordedAt: clock.nowUtc(),
      supersedesId: target.id,
      amendReason: AmendReason.correction,
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Measurement entries of [kind], newest first (ladder F007).
  Future<List<TimelineEntry>> measurementTimeline(
    String profileId,
    RecordKind kind,
  ) async => buildTimeline(await repository.records(profileId, kind: kind));

  /// A number typed for a measurement: a decimal comma is fine, a possible
  /// thousands separator is refused, blank is EMPTY (never 0), and 0 or
  /// less is refused (leave a value you do not know empty).
  double _measurementNumber(String raw, String field) {
    final double v;
    try {
      v = parseLabDecimal(raw);
    } on InputError catch (e) {
      throw InputError(e.code, field);
    }
    // Hundreds of digits overflow to infinity: not a number a person measured.
    if (!v.isFinite) throw InputError('NOT_A_NUMBER', field);
    if (v <= 0) throw InputError('NOT_POSITIVE', field);
    return v;
  }

  /// The observation time of a correction of [target] (G-48, D-047). The
  /// field opens with the stored time as typed; blank or that same text
  /// keeps the stored instant exactly (also one inside a repeated
  /// clock-change hour, or with seconds from a save time). Any other text
  /// is a new time under the usual entry rules: a future, skipped or
  /// repeated time is refused on the `when` field and nothing is written.
  DateTime _correctedTime(
    HealthRecord target,
    String raw,
    DateTime now,
    LocalZone zone,
  ) {
    final text = raw.trim();
    if (text.isEmpty || text == typedInZone(target.observedAt, zone)) {
      return target.observedAt;
    }
    return parseMeasuredAt(text, nowUtc: now, zone: zone)!;
  }

  HealthRecord _measurementRecord(
    String profileId,
    RecordKind kind,
    MeasurementInput input, {
    HealthRecord? target,
    LocalZone zone = const SystemLocalZone(),
  }) {
    if (!kind.isMeasurement) throw ArgumentError.value(kind, 'kind');
    final context = input.context.trim();
    if (context.runes.length > HealthRecord.maxContextLength) {
      throw const InputError('CONTEXT_TOO_LONG', 'context');
    }
    if (input.glucoseTiming != null && kind != RecordKind.capillaryGlucose) {
      throw ArgumentError.value(input.glucoseTiming, 'glucoseTiming');
    }
    Quantity? quantity;
    String? originalText;
    RecordDetails? details;
    final typed = kind.isStructured
        ? [input.systolic, input.diastolic]
        : [input.value];
    final noNumberTyped = typed.every((t) => t.trim().isEmpty);
    // A correction of a "not measured" entry with no number typed moves
    // its time or note and stays "not measured" (D-047, R021); a typed
    // number turns it into a reading.
    final targetNotMeasured = target?.valueStatus == ValueStatus.notMeasured;
    final notMeasured =
        input.notMeasured || (targetNotMeasured && noNumberTyped);
    if (notMeasured) {
      // Missing ≠ zero: a "not measured" entry holds no number at all.
      // A correction of a reading says what the value was; withdrawing a
      // reading is "entered in error", never a "not measured" version.
      if ((target != null && !targetNotMeasured) ||
          !notMeasuredKinds.contains(kind)) {
        throw const InputError('NOT_MEASURED_NOT_OFFERED');
      }
      if (!noNumberTyped) {
        throw InputError(
          'NOT_MEASURED_WITH_VALUE',
          kind.isStructured ? 'systolic' : 'value',
        );
      }
      // The meal timing belongs to a reading; a "not measured" entry holds
      // none (D-048).
      if (input.glucoseTiming != null) {
        throw const InputError('NOT_MEASURED_WITH_VALUE', 'timing');
      }
    } else if (kind.isStructured) {
      final systolic = _measurementNumber(input.systolic, 'systolic');
      final diastolic = _measurementNumber(input.diastolic, 'diastolic');
      // Checked at entry only: the upper number is larger by definition, so
      // an equal or smaller one was mistyped or swapped (D-018).
      if (systolic <= diastolic) throw const InputError('BP_ORDER', 'systolic');
      details = BloodPressureDetails(
        systolic: systolic,
        diastolic: diastolic,
        unit: kind.unit!,
        systolicText: input.systolic.trim(),
        diastolicText: input.diastolic.trim(),
      );
    } else {
      final number = _measurementNumber(input.value, 'value');
      // Definitional, not clinical: a percentage cannot be above 100. An
      // entry rule only; stored records are not re-judged (D-018).
      if ((kind == RecordKind.oxygenSaturation ||
              kind == RecordKind.bodyFatPercentage) &&
          number > 100) {
        throw const InputError('OUT_OF_DEFINITION', 'value');
      }
      var unit = kind.unit;
      if (kind.units.length > 1) {
        // The unit the device showed, chosen by the person: kept as chosen,
        // never guessed from the number and never converted (D-048). A
        // correction keeps the stored unit unless another is chosen.
        final chosen = input.unit.trim();
        unit = chosen.isEmpty ? target?.quantity?.unit : chosen;
        if (unit == null) {
          throw const InputError('UNIT_CHOICE_REQUIRED', 'unit');
        }
        if (!kind.units.contains(unit)) {
          throw const InputError('UNIT_NOT_SUPPORTED', 'unit');
        }
      }
      quantity = Quantity(number, unit);
      originalText = input.value.trim();
      if (input.glucoseTiming case final t?) details = GlucoseTimingDetails(t);
    }
    final now = clock.nowUtc();
    // A correction keeps the stored time unless a different one is typed
    // (G-48); a new entry takes the typed time, or the save time. Resolved
    // once, before the record is built.
    final observedAt = target != null
        ? _correctedTime(target, input.when, now, zone)
        : parseMeasuredAt(input.when, nowUtc: now, zone: zone) ?? now;
    final ctx = context.isEmpty ? null : context;
    // A correction that changes nothing would only add an empty version.
    if (target != null &&
        target.valueStatus ==
            (notMeasured ? ValueStatus.notMeasured : ValueStatus.present) &&
        target.quantity == quantity &&
        target.originalText == originalText &&
        target.details == details &&
        target.context == ctx &&
        target.observedAt == observedAt) {
      throw const InputError('NO_CHANGE');
    }
    return HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: kind,
      // A scale's body fat is the device's estimate as it showed it: a
      // report of a model output, never an observed fact (D-048).
      state: kind.isDeviceEstimate
          ? RecordState.reported
          : RecordState.observed,
      valueStatus: notMeasured ? ValueStatus.notMeasured : ValueStatus.present,
      quantity: quantity,
      originalText: originalText,
      provenance: const Provenance.manual(),
      observedAt: observedAt,
      recordedAt: now,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      context: ctx,
      details: details,
      schemaVersion: HealthRecord.writeSchemaFor(kind),
    );
  }

  /// Records a measurement typed by hand as an OBSERVED, manual fact at the
  /// typed time or the moment it is saved, or "not measured" with no
  /// number (D-047). Nothing is derived, averaged or judged.
  Future<HealthRecord> recordMeasurement({
    required String profileId,
    required RecordKind kind,
    required MeasurementInput input,
    LocalZone zone = const SystemLocalZone(),
  }) async {
    final record = _measurementRecord(profileId, kind, input, zone: zone);
    await repository.appendRecord(record);
    return record;
  }

  /// A better value, note or time for the same measurement: a new version
  /// of the same kind whose `supersedes_id` names the version it corrects;
  /// that version stays in history byte for byte. The time stays unless a
  /// different one is typed (G-48, D-047). Another kind's record is refused.
  Future<HealthRecord> correctMeasurement({
    required String profileId,
    required String targetId,
    required MeasurementInput input,
    LocalZone zone = const SystemLocalZone(),
  }) async {
    final target = await _currentTarget(profileId, targetId);
    if (!target.kind.isMeasurement) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final record = _measurementRecord(
      profileId,
      target.kind,
      input,
      target: target,
      zone: zone,
    );
    await repository.appendRecord(record);
    return record;
  }
}
