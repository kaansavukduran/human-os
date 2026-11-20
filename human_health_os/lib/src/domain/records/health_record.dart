/// Canonical health record envelope (docs/DATA_MODEL.md).
///
/// Pure Dart: no Flutter, IO or platform imports. Every invariant that can be
/// checked locally is enforced by [HealthRecord.validate]:
/// - a PRESENT value always has a quantity, or for a structured kind (blood
///   pressure) its structured details; any other value status carries neither
///   (missing ≠ zero);
/// - corrections are new records that point at what they supersede, and say
///   why ([AmendReason]); nothing is edited in place;
/// - the original source representation is kept next to the normalized value.
library;

import '../errors.dart';
import 'lab_details.dart';
import 'record_details.dart';
import 'timeline.dart';

export 'lab_details.dart';
export 'record_details.dart';
export 'timeline.dart';

/// What kind of truth a record represents. Never collapse these.
enum RecordState {
  observed,
  reported,
  planned,
  completed,
  derived,
  modelled,
  assumed,
  unknown,
}

/// Whether a value exists. Anything other than [present] carries no number.
enum ValueStatus { present, notReported, notMeasured, notApplicable, unknown }

/// Where a record came from.
enum ProvenanceKind {
  manual,
  device,
  provider,
  document,
  api,
  derived,
  modelled,
  imported,
  unknown,
}

/// Record kinds implemented so far. New kinds are added per FORGE, each
/// with the record schema that introduced it: a record of a kind is never
/// written under an older schema, so an older app refuses it instead of
/// skipping it as unreadable.
enum RecordKind {
  bodyWeight('body.weight', unit: 'kg'),

  /// A laboratory result as printed (F004, record schema 3).
  labResult('lab.result', minSchema: 3),

  /// Waist circumference typed by hand (F007, record schema 4).
  waistCircumference('body.waist_circumference', minSchema: 4, unit: 'cm'),

  /// Resting heart rate typed by hand (F007, record schema 4). Not a pulse
  /// read off a blood pressure monitor and not a heart-rate sample: the same
  /// display name is not the same measurand.
  restingHeartRate('vital.resting_heart_rate', minSchema: 4, unit: 'bpm'),

  /// One blood pressure reading, systolic and diastolic together in
  /// [BloodPressureDetails] (F007, record schema 4). Never a quantity.
  bloodPressure('vital.blood_pressure', minSchema: 4, unit: 'mmHg'),

  /// Standing height typed by hand (F007 slice 2, record schema 5). A new
  /// height is a new record, not a correction of an older one.
  height('body.height', minSchema: 5, unit: 'cm'),

  /// Body temperature typed by hand (F007 slice 2, record schema 5). The
  /// site (mouth, ear, armpit) is not captured; the note is the place for it.
  bodyTemperature('vital.body_temperature', minSchema: 5, unit: '°C'),

  /// Oxygen saturation (SpO2) as read from a pulse oximeter, typed by hand
  /// (F007 slice 2, record schema 5). An arterial blood-gas value is a
  /// different measurand and is not stored here.
  oxygenSaturation('vital.oxygen_saturation', minSchema: 5, unit: '%'),

  /// Respiratory rate counted by hand or read from a device (F007 slice 2,
  /// record schema 5).
  respiratoryRate('vital.respiratory_rate', minSchema: 5, unit: 'breaths/min'),

  /// A medicine or supplement the person uses, as they name it: the product,
  /// not its ingredients (F008, record schema 6). [MedicationItemDetails].
  medicationItem('medication.item', minSchema: 6),

  /// How a medicine or supplement is meant to be taken, in the person's or
  /// the prescriber's words (F008). A plan is never an intake.
  /// [MedicationPlanDetails].
  medicationPlan('medication.plan', minSchema: 6),

  /// One dose actually taken, or skipped, recorded by the person (F008).
  /// Only these records say what was taken. [MedicationIntakeDetails].
  medicationIntake('medication.intake', minSchema: 6),

  /// One night: going to bed and waking up, typed by hand (F007 slice 3,
  /// record schema 7). [SleepNightDetails]. Time in bed, not time asleep.
  sleepNight('sleep.night', minSchema: 7),

  /// How the person says they feel: energy, mood, stress as their own
  /// levels (F007 slice 4, record schema 8). [FeelingCheckInDetails].
  /// Self-report, never a diagnosis.
  feelingCheckIn('self.feeling_check_in', minSchema: 8),

  /// Something eaten or drunk, typed by hand (F007 slice 5, record schema
  /// 9). [FoodEntryDetails]. Nutrients only as printed; missing stays missing.
  foodEntry('nutrition.food_entry', minSchema: 9),

  /// One activity typed by hand (F007 slice 6, record schema 10).
  /// [ActivityEntryDetails]. Never merged with device data.
  activityEntry('activity.entry', minSchema: 10),

  /// A condition or symptom as the person names it, with who it comes from
  /// (F009 slice 1, record schema 11). [ConditionEntryDetails]. A
  /// self-report is never a confirmed diagnosis.
  conditionEntry('condition.entry', minSchema: 11),

  /// A preventive item (vaccination, screening, check-up) as the person
  /// names it, done, planned or unsure (F009 slice 2, record schema 12).
  /// [PreventiveEntryDetails]. Planned is never done; no result is stored.
  preventiveEntry('preventive.entry', minSchema: 12),

  /// A reference to a document the person keeps (F010 slice 1, record
  /// schema 13): what it is, its date and issuer as typed, and where it is
  /// kept. [DocumentReferenceDetails]. A reference is not the document: no
  /// file bytes, no reading, no extraction.
  documentReference('document.reference', minSchema: 13),

  /// Blood glucose from a finger-prick meter, typed by hand (F007 slice 8,
  /// record schema 16, D-048). Kept in the unit the meter showed, mg/dL or
  /// mmol/L, never converted; the meal timing, when given, is
  /// [GlucoseTimingDetails]. A laboratory (venous plasma) glucose is a lab
  /// result: the same display name is not the same measurand.
  capillaryGlucose('glucose.capillary', minSchema: 16),

  /// Body fat percentage as a home scale (or another device) showed it
  /// (F007 slice 8, record schema 16, D-048): the device's estimate, stored
  /// as [RecordState.reported], never as an observed fact.
  bodyFatPercentage('body.fat_percentage', minSchema: 16, unit: '%');

  const RecordKind(this.code, {this.minSchema = 1, this.unit});
  final String code;

  /// The record schema that introduced this kind.
  final int minSchema;

  /// The only unit stored for this kind (no conversion rule exists); null
  /// for a lab result, whose printed unit is kept as printed, and for a
  /// kind with more than one accepted unit ([units]).
  final String? unit;

  /// The units a measurement of this kind may be stored in, each kept as
  /// chosen and never converted into another (D-048): the meter's mg/dL or
  /// mmol/L for capillary glucose, otherwise the one canonical [unit].
  List<String> get units => switch (this) {
    capillaryGlucose => const ['mg/dL', 'mmol/L'],
    _ => [?unit],
  };

  /// The value is the device's own estimate as it showed it (a scale's body
  /// fat), saved as reported, never as an observed fact (D-048).
  bool get isDeviceEstimate => this == bodyFatPercentage;

  /// The F007 measurement kinds: typed by hand on Today, with an optional
  /// measurement context.
  bool get isMeasurement => switch (this) {
    waistCircumference ||
    restingHeartRate ||
    bloodPressure ||
    height ||
    bodyTemperature ||
    oxygenSaturation ||
    respiratoryRate ||
    capillaryGlucose ||
    bodyFatPercentage => true,
    bodyWeight ||
    labResult ||
    medicationItem ||
    medicationPlan ||
    medicationIntake ||
    sleepNight ||
    feelingCheckIn ||
    foodEntry ||
    activityEntry ||
    conditionEntry ||
    preventiveEntry ||
    documentReference => false,
  };

  /// The F008 medication kinds.
  bool get isMedication =>
      this == medicationItem ||
      this == medicationPlan ||
      this == medicationIntake;

  /// The value is [RecordDetails], never a single quantity.
  bool get isStructured =>
      this == bloodPressure ||
      isMedication ||
      this == sleepNight ||
      this == feelingCheckIn ||
      this == foodEntry ||
      this == activityEntry ||
      this == conditionEntry ||
      this == preventiveEntry ||
      this == documentReference;

  /// The `type` of the [RecordDetails] a structured kind carries.
  String? get detailsType => switch (this) {
    bloodPressure => BloodPressureDetails.typeTag,
    medicationItem => MedicationItemDetails.typeTag,
    medicationPlan => MedicationPlanDetails.typeTag,
    medicationIntake => MedicationIntakeDetails.typeTag,
    sleepNight => SleepNightDetails.typeTag,
    feelingCheckIn => FeelingCheckInDetails.typeTag,
    foodEntry => FoodEntryDetails.typeTag,
    activityEntry => ActivityEntryDetails.typeTag,
    conditionEntry => ConditionEntryDetails.typeTag,
    preventiveEntry => PreventiveEntryDetails.typeTag,
    documentReference => DocumentReferenceDetails.typeTag,
    // Optional beside the quantity, never in its place (D-048).
    capillaryGlucose => GlucoseTimingDetails.typeTag,
    _ => null,
  };

  static RecordKind fromCode(String code) => RecordKind.values.firstWhere(
    (k) => k.code == code,
    orElse: () => throw FormatException('Unknown record kind "$code"'),
  );
}

/// Why a record points at an earlier one (record schema 2, ladder F003).
/// See `timeline.dart` for how each reason changes what is current.
enum AmendReason {
  /// A better value for the same observation; the earlier version stays in
  /// history.
  correction('correction'),

  /// The target should never have been saved. It stops counting (if it was
  /// a correction, the previous version counts again) and stays in history
  /// marked as withdrawn.
  enteredInError('entered_in_error'),

  /// The person removed a true record. The whole fact leaves every view and
  /// stays in history as deleted (tombstone); later versions cannot bring
  /// it back.
  deleted('deleted');

  const AmendReason(this.code);
  final String code;

  static AmendReason fromCode(String code) => AmendReason.values.firstWhere(
    (r) => r.code == code,
    orElse: () => throw FormatException('Unknown amend reason "$code"'),
  );

  /// Withdraws or deletes its target instead of carrying a health value.
  bool get isMarker => this != correction;
}

class Quantity {
  const Quantity(this.value, this.unit);

  final double value;

  /// Unit as recorded (e.g. `kg`, or a lab's printed `mg/dL`). Never
  /// converted silently. Null only for a lab result whose report printed no
  /// unit: a missing unit stays missing (F004); body weight always has one.
  final String? unit;

  Map<String, Object?> toJson() => {'value': value, 'unit': unit};

  static Quantity fromJson(Map<String, Object?> j) =>
      Quantity((j['value']! as num).toDouble(), j['unit'] as String?);

  @override
  bool operator ==(Object other) =>
      other is Quantity && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);
}

class Provenance {
  const Provenance({
    required this.kind,
    this.sourceId,
    this.sourceVersion,
    this.deviceId,
  });

  const Provenance.manual() : this(kind: ProvenanceKind.manual);

  final ProvenanceKind kind;
  final String? sourceId;
  final String? sourceVersion;
  final String? deviceId;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (sourceId != null) 'source_id': sourceId,
    if (sourceVersion != null) 'source_version': sourceVersion,
    if (deviceId != null) 'device_id': deviceId,
  };

  static Provenance fromJson(Map<String, Object?> j) => Provenance(
    kind: ProvenanceKind.values.byName(j['kind']! as String),
    sourceId: j['source_id'] as String?,
    sourceVersion: j['source_version'] as String?,
    deviceId: j['device_id'] as String?,
  );
}

/// Data written by a newer app version. It is never guessed at or
/// downgraded (master §35.3); the store that holds it refuses to open.
class SchemaTooNewError implements Exception, CodedError {
  const SchemaTooNewError(this.what, this.version, this.supported);

  @override
  String get code => 'SCHEMA_TOO_NEW';

  final String what;
  final int version;
  final int supported;

  @override
  String toString() =>
      'SchemaTooNewError: $what schema $version is newer than this app ($supported)';
}

class RecordValidationError implements Exception, CodedError {
  const RecordValidationError(this.code, this.message);

  /// Stable machine code (e.g. `PRESENT_REQUIRES_QUANTITY`).
  @override
  final String code;
  final String message;

  @override
  String toString() => 'RecordValidationError($code): $message';
}

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.profileId,
    required this.kind,
    required this.state,
    required this.valueStatus,
    required this.quantity,
    required this.originalText,
    required this.provenance,
    required this.observedAt,
    required this.recordedAt,
    this.supersedesId,
    this.amendReason,
    this.deletedAt,
    this.lab,
    this.context,
    this.details,
    this.schemaVersion = defaultWriteSchema,
  });

  /// Record schema history (master §35.1). Each version reads every older
  /// one without rewriting it:
  /// - 1 (FORGE 002): the envelope; `supersedes_id` alone means correction.
  /// - 2 (F003): adds `amend_reason` (correction, entered in error, deleted).
  ///   A schema 1 record has no reason; one with `supersedes_id` is read as
  ///   a correction.
  /// - 3 (F004): adds the `lab.result` kind with `lab` details and allows a
  ///   lab value without a unit. Older records read unchanged.
  /// - 4 (F007, step RS-004, additive): adds the measurement kinds
  ///   `body.waist_circumference`, `vital.resting_heart_rate` and
  ///   `vital.blood_pressure`, the optional `context` text and the
  ///   kind-tagged `details` slot. Older records read unchanged.
  /// - 5 (F007 slice 2, step RS-005, additive): adds the measurement kinds
  ///   `body.height`, `vital.body_temperature`, `vital.oxygen_saturation`
  ///   and `vital.respiratory_rate`. No new key. Older records read
  ///   unchanged.
  /// - 6 (F008, step RS-006, additive): adds the medication kinds
  ///   `medication.item`, `medication.plan` and `medication.intake`, each
  ///   with its own `details` type. No new key. Older records read
  ///   unchanged.
  /// - 7 to 13: sleep, feeling, food, activity, condition, preventive and
  ///   document kinds (D-031 to D-036, D-040), each additive.
  /// - 14 (F004-S2, step RS-014, additive, D-043): adds the optional
  ///   `lab.result` object, a lab value that is not a plain number (censored
  ///   "< 5" or text "Pozitif") kept as printed, with no quantity. Only such
  ///   a lab result is written at 14; a plain number stays at 3. Older
  ///   records read unchanged.
  /// - 15 (F004-S3, step RS-015, additive, D-045): adds the optional
  ///   `lab.reported_at`, `lab.method` and `lab.reference_interval` (low
  ///   and/or high as typed, unit, partition), all as printed. Only a lab
  ///   result holding one of them is written at 15. Older records read
  ///   unchanged.
  /// - 16 (F007-S8, step RS-016, additive, D-048): adds the measurement
  ///   kinds `glucose.capillary` (quantity in mg/dL or mmol/L as chosen, no
  ///   conversion, optional `glucose_timing` details) and
  ///   `body.fat_percentage` (%, the device's estimate, state `reported`).
  ///   No new key. Only these kinds are written at 16. Older records read
  ///   unchanged.
  ///
  /// The newest schema this app reads; a newer one refuses the whole store.
  static const int currentSchemaVersion = 16;

  /// The schema that introduced [LabPrintedResult] (D-043).
  static const int labPrintedResultSchema = 14;

  /// The schema that introduced the report time, the method and the
  /// structured reference interval of a lab result (D-045).
  static const int labReportDetailsSchema = 15;

  /// The schema a lab result with [lab] is written with: the oldest that
  /// can hold it (3 for a plain number, 14 for a printed result, 15 when it
  /// keeps report details).
  static int writeSchemaForLab(LabDetails lab) => lab.hasReportDetails
      ? labReportDetailsSchema
      : lab.result != null
      ? labPrintedResultSchema
      : writeSchemaFor(RecordKind.labResult);

  /// A record that needs nothing from a newer schema is written at this one
  /// (D-018): weight and lab results stay readable by the apps of F004 to
  /// F006, which refuse a store as soon as it holds one schema 4 record.
  static const int defaultWriteSchema = 3;

  /// The schema a new record of [kind] is written with: the oldest that
  /// can hold it.
  static int writeSchemaFor(RecordKind kind) =>
      kind.minSchema > defaultWriteSchema ? kind.minSchema : defaultWriteSchema;

  /// Longest measurement context kept, in characters (Unicode code points,
  /// never UTF-16 units: an emoji counts once).
  static const int maxContextLength = 500;

  final String id;
  final String profileId;
  final RecordKind kind;
  final RecordState state;
  final ValueStatus valueStatus;
  final Quantity? quantity;

  /// The value exactly as the user or source wrote it (e.g. "78,4").
  final String? originalText;
  final Provenance provenance;

  /// When it happened (UTC).
  final DateTime observedAt;

  /// When it was entered (UTC).
  final DateTime recordedAt;
  final String? supersedesId;

  /// Why [supersedesId] is set (schema 2). Null on schema 1 records.
  final AmendReason? amendReason;
  final DateTime? deletedAt;

  /// The printed lab details of a [RecordKind.labResult] (schema 3).
  final LabDetails? lab;

  /// How the measurement was taken, exactly as typed (e.g. "sitting, left
  /// arm"); null = not given. Never parsed or inferred (schema 4,
  /// measurement kinds only).
  final String? context;

  /// The structured value of a structured kind (schema 4): a blood pressure
  /// reading; or, beside a quantity, the meal timing of a capillary glucose
  /// (schema 16). Null for every other kind.
  final RecordDetails? details;

  /// [observedAt] is a calendar day (UTC midnight of that day), not an
  /// instant: lab sample dates. Shown without a time-zone shift.
  bool get observedDateOnly => kind == RecordKind.labResult;
  final int schemaVersion;

  /// Throws [RecordValidationError] when an invariant is violated.
  void validate() {
    if (id.isEmpty || profileId.isEmpty) {
      throw const RecordValidationError(
        'MISSING_ID',
        'id and profileId are required',
      );
    }
    // Schema gates first: no early return below may let a newer kind or
    // field pass under an older schema.
    if (schemaVersion < kind.minSchema) {
      throw RecordValidationError(
        'KIND_NEEDS_NEWER_SCHEMA',
        '${kind.code} needs record schema ${kind.minSchema}',
      );
    }
    if (schemaVersion < 4 && (context != null || details != null)) {
      throw const RecordValidationError(
        'FIELD_NEEDS_NEWER_SCHEMA',
        'Measurement context and details need record schema 4',
      );
    }
    final printed = lab?.result;
    if (printed != null && schemaVersion < labPrintedResultSchema) {
      throw const RecordValidationError(
        'FIELD_NEEDS_NEWER_SCHEMA',
        'A lab value that is not a plain number needs record schema 14',
      );
    }
    if ((lab?.hasReportDetails ?? false) &&
        schemaVersion < labReportDetailsSchema) {
      throw const RecordValidationError(
        'FIELD_NEEDS_NEWER_SCHEMA',
        'Report time, method and reference interval need record schema 15',
      );
    }
    final present = valueStatus == ValueStatus.present;
    if (kind.isStructured) {
      if (quantity != null) {
        throw RecordValidationError(
          kind == RecordKind.bloodPressure
              ? 'BP_HAS_NO_QUANTITY'
              : 'STRUCTURED_HAS_NO_QUANTITY',
          '${kind.code} keeps its value in details, never as one number',
        );
      }
      if (present && details == null) {
        throw RecordValidationError(
          'DETAILS_MISMATCH',
          'A present ${kind.code} needs its details',
        );
      }
    } else if (present && quantity == null && printed == null) {
      throw const RecordValidationError(
        'PRESENT_REQUIRES_QUANTITY',
        'A present value needs a quantity',
      );
    }
    if (!present && quantity != null) {
      throw const RecordValidationError(
        'MISSING_HAS_NO_QUANTITY',
        'A missing value cannot carry a number (missing ≠ zero)',
      );
    }
    final d = details;
    // A kind without a details type takes none; capillary glucose takes its
    // timing beside the quantity (D-048).
    if (d != null && (!present || d.type != kind.detailsType)) {
      throw const RecordValidationError(
        'DETAILS_MISMATCH',
        'Structured details belong to a present value of their own kind',
      );
    }
    final ctx = context;
    if (ctx != null) {
      if (!kind.isMeasurement) {
        throw RecordValidationError(
          'CONTEXT_NOT_SUPPORTED',
          '${kind.code} keeps no measurement context',
        );
      }
      if (ctx.trim().isEmpty) {
        throw const RecordValidationError(
          'CONTEXT_EMPTY',
          'An empty context is stored as none',
        );
      }
      if (ctx.runes.length > maxContextLength) {
        throw const RecordValidationError(
          'CONTEXT_TOO_LONG',
          'The measurement context is too long',
        );
      }
    }
    if (!observedAt.isUtc || !recordedAt.isUtc) {
      throw const RecordValidationError(
        'NON_UTC_TIME',
        'Timestamps are stored in UTC',
      );
    }
    if (supersedesId != null && supersedesId == id) {
      throw const RecordValidationError(
        'SELF_SUPERSEDE',
        'A record cannot supersede itself',
      );
    }
    final reason = amendReason;
    if (reason != null && supersedesId == null) {
      throw const RecordValidationError(
        'AMEND_NEEDS_TARGET',
        'An amendment must name the record it amends',
      );
    }
    if (schemaVersion >= 2 && supersedesId != null && reason == null) {
      throw const RecordValidationError(
        'AMEND_REASON_REQUIRED',
        'Say why a record supersedes another (schema 2)',
      );
    }
    if (reason != null && reason.isMarker) {
      if (valueStatus != ValueStatus.notApplicable || quantity != null) {
        throw const RecordValidationError(
          'MARKER_HAS_NO_VALUE',
          'Withdrawing or deleting a record carries no health value',
        );
      }
    }
    if (schemaVersion >= 2 &&
        (deletedAt != null) != (reason == AmendReason.deleted)) {
      throw const RecordValidationError(
        'DELETE_TIME_MISMATCH',
        'Only a deletion carries a deletion time, and it always does',
      );
    }
    if (reason != null && reason.isMarker) {
      if (lab != null || context != null) {
        throw const RecordValidationError(
          'MARKER_HAS_NO_VALUE',
          'Withdrawing or deleting a record carries no lab details or context',
        );
      }
      return;
    }
    final q = quantity;
    if (q != null && q.unit == null && kind != RecordKind.labResult) {
      throw const RecordValidationError(
        'UNIT_REQUIRED',
        'Only a lab result may lack a unit',
      );
    }
    if ((lab != null) != (kind == RecordKind.labResult)) {
      throw const RecordValidationError(
        'LAB_DETAILS_MISMATCH',
        'Lab details belong to lab results, and every lab result has them',
      );
    }
    switch (kind) {
      case RecordKind.bodyWeight:
        final q = quantity;
        if (q == null) break;
        if (q.unit != 'kg') {
          throw RecordValidationError(
            'UNIT_NOT_SUPPORTED',
            'body.weight is stored in kg; "${q.unit}" needs an explicit conversion rule',
          );
        }
        if (!q.value.isFinite || q.value <= 0 || q.value > 700) {
          throw const RecordValidationError(
            'OUT_OF_PLAUSIBLE_RANGE',
            'Body weight must be between 0 and 700 kg',
          );
        }
      case RecordKind.labResult:
        // No plausibility range: the app holds no clinical thresholds. Only
        // a finite number and the printed name are required.
        if (printed != null) {
          if (!present) {
            throw const RecordValidationError(
              'LAB_RESULT_NEEDS_PRESENT',
              'A value not reported carries no printed result',
            );
          }
          if (quantity != null) {
            throw const RecordValidationError(
              'LAB_VALUE_TWICE',
              'A censored or text lab result carries no number',
            );
          }
          final code = printed.problem();
          if (code != null) {
            throw RecordValidationError(code, 'lab.result: $code');
          }
        }
        final v = quantity?.value;
        if (v != null && !v.isFinite) {
          throw const RecordValidationError(
            'VALUE_NOT_FINITE',
            'A lab value must be a finite number',
          );
        }
        if (lab!.analyteLabel.trim().isEmpty) {
          throw const RecordValidationError(
            'LAB_ANALYTE_REQUIRED',
            'A lab result needs the test name as printed',
          );
        }
        final detailsCode = lab!.reportDetailsProblem();
        if (detailsCode != null) {
          throw RecordValidationError(detailsCode, 'lab: $detailsCode');
        }
      case RecordKind.waistCircumference ||
          RecordKind.restingHeartRate ||
          RecordKind.height ||
          RecordKind.bodyTemperature ||
          RecordKind.oxygenSaturation ||
          RecordKind.respiratoryRate ||
          RecordKind.capillaryGlucose ||
          RecordKind.bodyFatPercentage:
        // Structural checks only: no upper bound and no clinical threshold
        // (none is specified; master §43). A circumference or a rate of 0
        // or less is not a measurement.
        final q = quantity;
        if (q == null) break;
        _checkUnit(q.unit);
        _checkNumber(q.value, allowZero: false);
      case RecordKind.bloodPressure:
        final bp = details;
        if (bp is! BloodPressureDetails) break;
        _checkUnit(bp.unit);
        _checkNumber(bp.systolic, allowZero: false);
        // A diastolic of 0 can be recorded by hand (sounds heard down to
        // zero), so stored records accept it; typed entry refuses it. The
        // order of the two numbers is checked at entry only: these domain
        // rules may be loosened later, never tightened (D-018).
        _checkNumber(bp.diastolic, allowZero: true);
      case RecordKind.medicationItem ||
          RecordKind.medicationPlan ||
          RecordKind.medicationIntake:
        final code = switch (details) {
          final MedicationDetails d => d.problem(),
          _ => null,
        };
        if (code != null) {
          throw RecordValidationError(code, '${kind.code}: $code');
        }
      case RecordKind.sleepNight ||
          RecordKind.feelingCheckIn ||
          RecordKind.foodEntry ||
          RecordKind.activityEntry ||
          RecordKind.conditionEntry ||
          RecordKind.preventiveEntry ||
          RecordKind.documentReference:
        final code = switch (details) {
          final SleepNightDetails d => d.problem(),
          final FeelingCheckInDetails d => d.problem(),
          final FoodEntryDetails d => d.problem(),
          final ActivityEntryDetails d => d.problem(),
          final ConditionEntryDetails d => d.problem(),
          final PreventiveEntryDetails d => d.problem(),
          final DocumentReferenceDetails d => d.problem(),
          _ => null,
        };
        if (code != null) {
          throw RecordValidationError(code, '${kind.code}: $code');
        }
    }
  }

  void _checkUnit(String? unit) {
    if (!kind.units.contains(unit)) {
      throw RecordValidationError(
        'UNIT_NOT_SUPPORTED',
        '${kind.code} is stored in ${kind.units.join(' or ')}; "$unit" needs an explicit conversion rule',
      );
    }
  }

  static void _checkNumber(double v, {required bool allowZero}) {
    if (!v.isFinite) {
      throw const RecordValidationError(
        'VALUE_NOT_FINITE',
        'A measurement must be a finite number',
      );
    }
    if (v < 0 || (v == 0 && !allowZero)) {
      throw const RecordValidationError(
        'VALUE_NOT_POSITIVE',
        'A measurement must be greater than 0',
      );
    }
  }

  /// Written in the shape of [schemaVersion], so an old record keeps its
  /// exact bytes when it is compared or exported again.
  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'id': id,
    'profile_id': profileId,
    'kind': kind.code,
    'state': state.name,
    'value_status': valueStatus.name,
    'quantity': quantity?.toJson(),
    'original_text': originalText,
    'provenance': provenance.toJson(),
    'observed_at': observedAt.toIso8601String(),
    'recorded_at': recordedAt.toIso8601String(),
    'supersedes_id': supersedesId,
    if (schemaVersion >= 2) 'amend_reason': amendReason?.code,
    'deleted_at': deletedAt?.toIso8601String(),
    if (schemaVersion >= 3) 'lab': lab?.toJson(),
    if (schemaVersion >= 4) 'context': context,
    if (schemaVersion >= 4) 'details': details?.toJson(),
  };

  static HealthRecord fromJson(Map<String, Object?> j) {
    final version = (j['schema_version'] as num?)?.toInt() ?? 1;
    if (version > currentSchemaVersion) {
      throw SchemaTooNewError('record', version, currentSchemaVersion);
    }
    final q = j['quantity'];
    return HealthRecord(
      schemaVersion: version,
      id: j['id']! as String,
      profileId: j['profile_id']! as String,
      kind: RecordKind.fromCode(j['kind']! as String),
      state: RecordState.values.byName(j['state']! as String),
      valueStatus: ValueStatus.values.byName(j['value_status']! as String),
      quantity: q == null
          ? null
          : Quantity.fromJson((q as Map).cast<String, Object?>()),
      originalText: j['original_text'] as String?,
      provenance: Provenance.fromJson(
        (j['provenance']! as Map).cast<String, Object?>(),
      ),
      observedAt: DateTime.parse(j['observed_at']! as String).toUtc(),
      recordedAt: DateTime.parse(j['recorded_at']! as String).toUtc(),
      supersedesId: j['supersedes_id'] as String?,
      amendReason: j['amend_reason'] == null
          ? null
          : AmendReason.fromCode(j['amend_reason']! as String),
      deletedAt: j['deleted_at'] == null
          ? null
          : DateTime.parse(j['deleted_at']! as String).toUtc(),
      lab: j['lab'] == null
          ? null
          : LabDetails.fromJson((j['lab']! as Map).cast<String, Object?>()),
      context: j['context'] as String?,
      details: j['details'] == null
          ? null
          : RecordDetails.fromJson(
              (j['details']! as Map).cast<String, Object?>(),
            ),
    );
  }
}

/// Whether a lab result can be used as a number by a calculation (F004-S2,
/// D-043). [value] is set only for a present plain number; otherwise
/// [notUsableReason] says why not, e.g. `LAB_VALUE_CENSORED`: a "< 5" is
/// not 5 and not any other number.
class LabNumber {
  const LabNumber._(this.value, this.unit, this.notUsableReason);

  final double? value;
  final String? unit;

  /// `NOT_A_LAB_RESULT`, `LAB_VALUE_MISSING` (not reported: missing ≠ zero),
  /// `LAB_VALUE_CENSORED` (below or above a limit: the true value is not
  /// known) or `LAB_VALUE_TEXT` (printed as text: no number); null when
  /// [value] is usable.
  final String? notUsableReason;

  bool get usable => value != null;
}

/// The only way a calculation may read a lab value as a number.
LabNumber labNumberFor(HealthRecord r) {
  if (r.kind != RecordKind.labResult) {
    return const LabNumber._(null, null, 'NOT_A_LAB_RESULT');
  }
  final printed = r.lab?.result;
  if (printed != null) {
    return LabNumber._(
      null,
      printed.unit,
      printed.kind == LabValueKind.censored
          ? 'LAB_VALUE_CENSORED'
          : 'LAB_VALUE_TEXT',
    );
  }
  final q = r.quantity;
  if (r.valueStatus != ValueStatus.present || q == null || !q.value.isFinite) {
    return const LabNumber._(null, null, 'LAB_VALUE_MISSING');
  }
  return LabNumber._(q.value, q.unit, null);
}

/// The current versions (newest observation first): the heads of every live
/// timeline entry. In a conflict both competing versions are returned.
/// History stays in the store (see `timeline.dart`).
List<HealthRecord> currentRecords(Iterable<HealthRecord> all) => [
  for (final e in buildTimeline(all)) ...e.heads,
];
