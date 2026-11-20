/// Record use cases: a local SELF profile, canonical body-weight observations
/// (F002) and their timeline with corrections, withdrawals and deletions
/// (F003), lab results as printed (F004) and measurements typed by hand
/// (F007), all through the [HealthRepository] port.
library;

import '../core/ids.dart';
import 'input_error.dart';
import 'measured_at.dart';
import '../domain/ports/health_repository.dart';
import '../domain/profile/profile.dart';
import '../domain/records/health_record.dart';

export 'input_error.dart';

/// Parses user text such as `78.4`, `78,4` or ` 78 `. Blank input is an error,
/// never zero (missing ≠ zero).
double parseDecimal(String raw) {
  final t = raw.trim().replaceAll(' ', '');
  if (t.isEmpty) throw const InputError('EMPTY');
  if (!RegExp(r'^\d+([.,]\d+)?$').hasMatch(t)) {
    throw const InputError('NOT_A_NUMBER');
  }
  return double.parse(t.replaceAll(',', '.'));
}

/// A lab result as typed from a report. Every field is the printed text.
class LabInput {
  const LabInput({
    required this.analyte,
    required this.value,
    required this.notReported,
    required this.unit,
    required this.sampleDate,
    this.specimen = '',
    this.laboratory = '',
    this.sourceFlag = '',
    this.referenceText = '',
    this.kind = LabValueKind.number,
    this.reportTime = '',
    this.method = '',
    this.refLow = '',
    this.refHigh = '',
    this.refUnit = '',
    this.refPartition = '',
  });

  final String analyte;

  /// The value as printed: a number ("5,4"), a comparator and a number
  /// ("< 5") or text ("Pozitif"), as [kind] says.
  final String value;

  /// How the report prints the value (F004-S2, D-043).
  final LabValueKind kind;

  /// The report lists the test but gives no value (missing ≠ zero).
  final bool notReported;
  final String unit;

  /// `YYYY-MM-DD`, the day the sample was collected.
  final String sampleDate;
  final String specimen;
  final String laboratory;
  final String sourceFlag;
  final String referenceText;

  /// More from the report (F004-S3, D-045), every field optional and as
  /// printed. [reportTime] is when the laboratory reported the result, in
  /// the "When" grammar (`YYYY-MM-DD HH:MM`, `HH:MM`); blank = not given.
  final String reportTime;

  /// The method as printed ("enzymatic", "HPLC").
  final String method;

  /// The reference interval as printed: the low and/or high number, the
  /// unit printed with them and the partition ("Kadın 20-49 yaş"). Typed by
  /// the person; never read from [referenceText].
  final String refLow;
  final String refHigh;
  final String refUnit;
  final String refPartition;
}

/// Parses `YYYY-MM-DD` into that calendar day (UTC midnight, a date without
/// a time of day). Anything else is `DATE_INVALID`.
DateTime parseSampleDate(String raw) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (m == null) throw const InputError('DATE_INVALID');
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime.utc(y, mo, d);
  if (date.year != y || date.month != mo || date.day != d) {
    throw const InputError('DATE_INVALID');
  }
  return date;
}

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
};

/// Like [parseDecimal], but refuses a value whose separator could be a
/// thousands separator ("150,000", "7.500", "250.000"): guessing would store
/// a number 1000 times off while the screen shows the printed text.
double parseLabDecimal(String raw) {
  final t = raw.trim().replaceAll(' ', '');
  if (RegExp(r'^[1-9]\d{0,2}[.,]\d{3}$').hasMatch(t)) {
    throw const InputError('AMBIGUOUS_SEPARATOR');
  }
  return parseDecimal(raw);
}

/// A number with a unit typed after it ("5 mg/dL", "37mmol/mol", "6 %").
final RegExp _unitAfterNumber = RegExp(
  r'^\d+([.,]\d+)?\s*[\p{L}%/µ°]',
  unicode: true,
);

/// A comparator typed first: "<", ">", "≤", "≥" or "=".
final RegExp _comparatorFirst = RegExp(r'^[<>≤≥=]');

/// A sign typed before a lab number: "-" or the minus sign "\u2212" (U+2212).
final RegExp _labMinus = RegExp(r'^[\-\u2212]');

/// A ratio or titre as printed ("1/160", "1:80"): text, not a unit.
final RegExp _titre = RegExp(r'^\d+\s*[/:]\s*\d+');

/// The number of a plain lab value. Besides [parseLabDecimal]'s rules, a
/// comparator first ("<5") is `VALUE_HAS_COMPARATOR` and a unit after the
/// number ("5 mg/dL") is `UNIT_IN_VALUE`, so the message says what to do.
/// A leading "-" or "\u2212" makes it negative (base excess -2): labs print
/// negative results, while weight and the other measurements never take
/// one. Spaces after the sign are ignored, as inside the number ("- 2" is
/// -2); the record keeps what was typed as its original text.
double parseLabNumber(String raw) {
  var t = raw.trim();
  if (_comparatorFirst.hasMatch(t)) {
    throw const InputError('VALUE_HAS_COMPARATOR', 'value');
  }
  final negative = _labMinus.hasMatch(t);
  if (negative) t = t.substring(1).trim();
  if (_unitAfterNumber.hasMatch(t)) {
    throw const InputError('UNIT_IN_VALUE', 'value');
  }
  try {
    final v = parseLabDecimal(t);
    if (!v.isFinite) throw const InputError('NOT_A_NUMBER');
    // "-0" is 0: a sign on zero is not a different result.
    return negative && v != 0 ? -v : v;
  } on InputError catch (e) {
    // A sign alone ("-") is a number without digits, not a blank field.
    if (negative && e.code == 'EMPTY') {
      throw const InputError('NOT_A_NUMBER', 'value');
    }
    throw InputError(e.code, 'value');
  }
}

/// A censored lab value ("< 5", "<=0,1", "> 1000", "≥ 90"): one comparator
/// and one number, the number kept exactly as typed. Refused: blank
/// (`EMPTY`), no comparator (`CENSORED_NEEDS_COMPARATOR`), a comparator
/// alone (`CENSORED_NEEDS_NUMBER`), two comparators or a stray "="
/// (`COMPARATOR_UNCLEAR`), a unit in the value (`UNIT_IN_VALUE`), and a
/// number [parseLabDecimal] refuses. The limit is stored exactly as typed,
/// so a limit that is not plain digits as typed ("1 000", "5 ,4") is
/// `LIMIT_HAS_SPACE` rather than kept in a form the record refuses, and a
/// value longer than a text result is `TEXT_TOO_LONG`. Every error is about
/// the value field.
({LabComparator comparator, String limitText}) parseCensoredLab(String raw) {
  final t = raw.trim();
  if (t.isEmpty) throw const InputError('EMPTY', 'value');
  if (t.runes.length > LabPrintedResult.maxTextLength) {
    throw const InputError('TEXT_TOO_LONG', 'value');
  }
  LabComparator? comparator;
  var rest = '';
  // Longest typed form first, so "<=" is never read as "<" then "=".
  for (final e in LabComparator.typed.entries) {
    if (t.startsWith(e.key)) {
      comparator = e.value;
      rest = t.substring(e.key.length).trim();
      break;
    }
  }
  if (comparator == null) {
    throw InputError(
      _comparatorFirst.hasMatch(t)
          ? 'COMPARATOR_UNCLEAR'
          : 'CENSORED_NEEDS_COMPARATOR',
      'value',
    );
  }
  if (rest.isEmpty) throw const InputError('CENSORED_NEEDS_NUMBER', 'value');
  if (_comparatorFirst.hasMatch(rest)) {
    throw const InputError('COMPARATOR_UNCLEAR', 'value');
  }
  if (_unitAfterNumber.hasMatch(rest)) {
    throw const InputError('UNIT_IN_VALUE', 'value');
  }
  try {
    parseLabDecimal(rest);
  } on InputError catch (e) {
    throw InputError(e.code, 'value');
  }
  // parseLabDecimal drops inner spaces; the limit is kept as typed, so it
  // must already be plain digits (review R017).
  if (!LabPrintedResult.limitPattern.hasMatch(rest)) {
    throw const InputError('LIMIT_HAS_SPACE', 'value');
  }
  return (comparator: comparator, limitText: rest);
}

/// Invisible characters that change the direction of the text around them
/// (U+202A–U+202E, U+2066–U+2069) and the direction marks U+200E, U+200F
/// and U+061C. Kept, one of them could reorder a summary line.
final RegExp _directionMarks = RegExp(
  r'[\u202A-\u202E\u2066-\u2069\u200E\u200F\u061C]',
);

/// Control characters (Unicode Cc: tabs, line breaks and the rest).
final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F-\x9F]');

/// A plain number, signed or not, once spaces are removed.
final RegExp _signedNumber = RegExp(r'^[+\-\u2212]?\d+([.,]\d+)?$');

/// A leading sign and the spaces after it.
final RegExp _leadingSign = RegExp(r'^[+\-\u2212]\s*');

/// The text of a lab result as it is stored: direction marks removed and
/// each control character (a pasted line break or tab) made a space, then
/// surrounding spaces trimmed. Nothing visible changes.
String labTextAsStored(String raw) =>
    raw.replaceAll(_directionMarks, '').replaceAll(_controlChars, ' ').trim();

/// A lab result printed as text ("Pozitif", "Reaktif değil", "1+", a titre
/// such as "1/160"), kept verbatim apart from surrounding spaces and the
/// invisible characters [labTextAsStored] removes. Refused, because each
/// has its own kind and must not hide from what a number can do: a plain
/// number, signed or not (`TEXT_IS_A_NUMBER`); a number with a unit after
/// it, "5 mg/dL" or "6 %" (`UNIT_IN_VALUE`); a sign and a number, with or
/// without a unit, "<5 mg/dL" (`TEXT_IS_CENSORED`).
String parseLabText(String raw) {
  final t = labTextAsStored(raw);
  if (t.isEmpty) throw const InputError('EMPTY', 'value');
  if (t.runes.length > LabPrintedResult.maxTextLength) {
    throw const InputError('TEXT_TOO_LONG', 'value');
  }
  if (_signedNumber.hasMatch(t.replaceAll(' ', ''))) {
    throw const InputError('TEXT_IS_A_NUMBER', 'value');
  }
  if (_comparatorFirst.hasMatch(t)) {
    final rest = t.replaceFirst(RegExp(r'^[<>≤≥=\s]+'), '');
    if (RegExp(r'^\d').hasMatch(rest) && !_titre.hasMatch(rest)) {
      throw const InputError('TEXT_IS_CENSORED', 'value');
    }
  }
  final unsigned = t.replaceFirst(_leadingSign, '');
  if (_unitAfterNumber.hasMatch(unsigned) && !_titre.hasMatch(unsigned)) {
    throw const InputError('UNIT_IN_VALUE', 'value');
  }
  return t;
}

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

/// The method as printed, or null when blank (field `method`).
String? parseLabMethod(String raw) {
  final m = labTextAsStored(raw);
  if (m.isEmpty) return null;
  if (m.runes.length > LabDetails.maxMethodLength) {
    throw const InputError('TEXT_TOO_LONG', 'method');
  }
  return m;
}

/// A report time starts with the date the laboratory printed.
final RegExp _reportDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) ');

/// A clock time alone, as the "When" fields accept it.
final RegExp _bareTime = RegExp(r'^\d{1,2}:\d{2}$');

/// When the laboratory reported the result, or null when blank. The "When"
/// rules of [parseMeasuredAt], every error on the field `reportTime`, except
/// that a bare time ("14:30") is refused with `REPORT_TIME_NEEDS_DATE`: a
/// report is often entered days after it was printed, so a time alone is
/// never read as today. A report dated before the sample day, compared by
/// the date as typed (also when an offset is typed), is
/// `REPORT_BEFORE_SAMPLE`.
DateTime? parseReportTime(
  String raw, {
  required DateTime nowUtc,
  required DateTime sampleDay,
  LocalZone zone = const SystemLocalZone(),
}) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  // Checked before the time itself, so "14:30" later today is not
  // reported as a future time either.
  if (_bareTime.hasMatch(text)) {
    throw const InputError('REPORT_TIME_NEEDS_DATE', 'reportTime');
  }
  final DateTime? t;
  try {
    t = parseMeasuredAt(text, nowUtc: nowUtc, zone: zone);
  } on InputError catch (e) {
    throw InputError(e.code, 'reportTime');
  }
  final typed = _reportDate.firstMatch(text);
  if (t == null || typed == null) {
    throw const InputError('REPORT_TIME_NEEDS_DATE', 'reportTime');
  }
  final day = DateTime.utc(
    int.parse(typed[1]!),
    int.parse(typed[2]!),
    int.parse(typed[3]!),
  );
  if (day.isBefore(sampleDay)) {
    throw const InputError('REPORT_BEFORE_SAMPLE', 'reportTime');
  }
  return t;
}

class HeartbeatService {
  HeartbeatService(
    this.repository, {
    this.clock = const SystemClock(),
    IdGenerator? ids,
  }) : _ids = ids ?? UuidV4Generator();

  final HealthRepository repository;
  final Clock clock;
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

  /// Every fact of the profile on one timeline. [includeHidden] adds deleted
  /// and withdrawn entries (history view).
  Future<List<TimelineEntry>> timeline(
    String profileId, {
    bool includeHidden = false,
  }) async => buildTimeline(
    await repository.records(profileId),
    includeHidden: includeHidden,
  );

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

  /// Lab results, newest sample first (ladder F004).
  Future<List<TimelineEntry>> labTimeline(String profileId) async =>
      buildTimeline(
        await repository.records(profileId, kind: RecordKind.labResult),
      );

  HealthRecord _labRecord(
    String profileId,
    LabInput input, {
    String? supersedesId,
  }) {
    final analyte = input.analyte.trim();
    if (analyte.isEmpty) throw const InputError('LAB_ANALYTE_EMPTY');
    final sample = parseSampleDate(input.sampleDate);
    final now = clock.nowUtc();
    // Compare calendar days in the user's time zone: the sample day may be
    // today, never tomorrow (review finding: comparing instants let a
    // mistyped tomorrow through in most zones).
    final local = now.toLocal();
    if (sample.isAfter(DateTime.utc(local.year, local.month, local.day))) {
      throw const InputError('FUTURE_TIME');
    }
    String? opt(String raw) => raw.trim().isEmpty ? null : raw.trim();
    final unit = opt(input.unit);
    final kind = input.notReported ? LabValueKind.number : input.kind;
    final double? value = input.notReported || kind != LabValueKind.number
        ? null
        : parseLabNumber(input.value);
    final LabPrintedResult? printed = switch (kind) {
      _ when input.notReported => null,
      LabValueKind.number => null,
      LabValueKind.censored => () {
        final c = parseCensoredLab(input.value);
        return LabPrintedResult.censored(
          comparator: c.comparator,
          limitText: c.limitText,
          unit: unit,
        );
      }(),
      LabValueKind.text => LabPrintedResult.text(
        text: parseLabText(input.value),
        unit: unit,
      ),
    };
    // A text result's original text is the stored text: no hidden
    // direction marks or control characters reach a summary line.
    final typed = printed?.kind == LabValueKind.text
        ? printed!.text!
        : input.value.trim();
    final present = value != null || printed != null;
    // More from the report (D-045): each optional, each kept as printed.
    final reportedAt = parseReportTime(
      input.reportTime,
      nowUtc: now,
      sampleDay: sample,
    );
    final method = parseLabMethod(input.method);
    final interval = parseReferenceInterval(
      low: input.refLow,
      high: input.refHigh,
      unit: input.refUnit,
      partition: input.refPartition,
    );
    final lab = LabDetails(
      analyteLabel: analyte,
      specimen: opt(input.specimen),
      laboratory: opt(input.laboratory),
      sourceFlag: opt(input.sourceFlag),
      referenceText: opt(input.referenceText),
      result: printed,
      reportedAt: reportedAt,
      method: method,
      referenceInterval: interval,
    );
    return HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.labResult,
      state: RecordState.reported,
      valueStatus: present ? ValueStatus.present : ValueStatus.notReported,
      quantity: value == null ? null : Quantity(value, unit),
      originalText: present ? typed : null,
      provenance: const Provenance.manual(),
      observedAt: sample,
      recordedAt: now,
      supersedesId: supersedesId,
      amendReason: supersedesId == null ? null : AmendReason.correction,
      lab: lab,
      // Each record at the oldest schema that holds it: a plain number at 3
      // (readable by every app since F004), a printed result at 14 (D-043),
      // report details at 15 (D-045).
      schemaVersion: HealthRecord.writeSchemaForLab(lab),
    );
  }

  /// Records a lab result exactly as printed: a REPORTED value with its
  /// printed unit, flag and range. A missing unit or range stays missing.
  Future<HealthRecord> recordLab({
    required String profileId,
    required LabInput input,
  }) async {
    final record = _labRecord(profileId, input);
    await repository.appendRecord(record);
    return record;
  }

  /// A corrected transcription of the same lab result (new version).
  Future<HealthRecord> correctLab({
    required String profileId,
    required String targetId,
    required LabInput input,
  }) async {
    final target = await _currentTarget(profileId, targetId);
    if (target.kind != RecordKind.labResult) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final record = _labRecord(profileId, input, supersedesId: target.id);
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
    Quantity? quantity;
    String? originalText;
    BloodPressureDetails? details;
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
      if (kind == RecordKind.oxygenSaturation && number > 100) {
        throw const InputError('OUT_OF_DEFINITION', 'value');
      }
      quantity = Quantity(number, kind.unit);
      originalText = input.value.trim();
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
      state: RecordState.observed,
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

  // Medicines and supplements (F008). The person's own words, kept as
  // typed. A plan is never turned into doses; only a recorded dose says
  // what was taken.

  static String? _medsText(String raw, String field, {bool required = false}) {
    final t = raw.trim();
    if (t.isEmpty) {
      if (required) throw InputError('EMPTY', field);
      return null;
    }
    if (t.runes.length > maxMedicationText) {
      throw InputError('TEXT_TOO_LONG', field);
    }
    return t;
  }

  /// The live medicine or supplement whose first version is [itemRootId].
  Future<TimelineEntry> _liveItem(String profileId, String itemRootId) async {
    final entries = buildTimeline(
      await repository.records(profileId, kind: RecordKind.medicationItem),
    );
    for (final e in entries) {
      if (e.rootId == itemRootId) return e;
    }
    throw const InputError('TARGET_NOT_FOUND');
  }

  HealthRecord _medsRecord(
    String profileId,
    RecordKind kind,
    RecordDetails details, {
    DateTime? observedAt,
  }) {
    final now = clock.nowUtc();
    return HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: kind,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: observedAt ?? now,
      recordedAt: now,
      details: details,
      schemaVersion: HealthRecord.writeSchemaFor(kind),
    );
  }

  /// Adds a medicine or supplement the person uses (the product, as named).
  Future<HealthRecord> addMedication({
    required String profileId,
    required String name,
    required MedicationCategory category,
    String ingredients = '',
    String strength = '',
    String form = '',
  }) async {
    final record = _medsRecord(
      profileId,
      RecordKind.medicationItem,
      MedicationItemDetails(
        name: _medsText(name, 'name', required: true)!,
        category: category,
        ingredients: _medsText(ingredients, 'ingredients'),
        strength: _medsText(strength, 'strength'),
        form: _medsText(form, 'form'),
      ),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Writes how a medicine or supplement is meant to be taken. A newer plan
  /// for the same item replaces the shown one; older plans stay in history.
  Future<HealthRecord> planMedication({
    required String profileId,
    required String itemRootId,
    required String schedule,
    PlanSource source = PlanSource.unknown,
  }) async {
    await _liveItem(profileId, itemRootId);
    // A new wording keeps a paused or stopped plan paused or stopped: only
    // setPlanState changes the state.
    final earlier = _latest(
      await repository.records(profileId, kind: RecordKind.medicationPlan),
      itemRootId,
    );
    final record = _medsRecord(
      profileId,
      RecordKind.medicationPlan,
      MedicationPlanDetails(
        itemRootId: itemRootId,
        schedule: _medsText(schedule, 'schedule', required: true)!,
        source: source,
        state: earlier?.state ?? PlanState.active,
      ),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Pauses, stops or resumes the shown plan of an item: a new plan record
  /// with the same words and source and the new [state]; the earlier plan
  /// stays in history. Refused when there is no plan to change.
  Future<HealthRecord> setPlanState({
    required String profileId,
    required String itemRootId,
    required PlanState state,
  }) async {
    await _liveItem(profileId, itemRootId);
    final all = await repository.records(
      profileId,
      kind: RecordKind.medicationPlan,
    );
    final current = _latest(all, itemRootId);
    if (current == null) throw const InputError('TARGET_NOT_FOUND');
    if (current.state == state) throw const InputError('NO_CHANGE');
    final record = _medsRecord(
      profileId,
      RecordKind.medicationPlan,
      MedicationPlanDetails(
        itemRootId: itemRootId,
        schedule: current.schedule,
        source: current.source,
        state: state,
      ),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records one dose the person took or skipped, at the typed time or now.
  Future<HealthRecord> recordDose({
    required String profileId,
    required String itemRootId,
    required IntakeStatus status,
    String amount = '',
    String when = '',
  }) async {
    await _liveItem(profileId, itemRootId);
    final now = clock.nowUtc();
    final record = _medsRecord(
      profileId,
      RecordKind.medicationIntake,
      MedicationIntakeDetails(
        itemRootId: itemRootId,
        status: status,
        amount: _medsText(amount, 'amount'),
      ),
      observedAt: parseMeasuredAt(when, nowUtc: now) ?? now,
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records one night: going to bed and waking up as typed. A blank
  /// waking time is now. A going-to-bed time without a date (`HH:MM`) is the
  /// last such time before waking, so "23:10" then "07:00" is one night.
  Future<HealthRecord> recordSleep({
    required String profileId,
    required String wentToBed,
    String wokeUp = '',
    WakeFeeling? feeling,
    LocalZone zone = const SystemLocalZone(),
    String? correcting,
  }) async {
    // A correction replaces the shown version of a night with new typed
    // times; the earlier version stays in history.
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.sleepNight) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final now = clock.nowUtc();
    final bedText = wentToBed.trim();
    if (bedText.isEmpty) throw const InputError('EMPTY', 'bed');
    // Each error names the field it is about.
    T inField<T>(String field, T Function() read) {
      try {
        return read();
      } on InputError catch (e) {
        throw InputError(e.code, field);
      }
    }

    final up = inField(
      'woke',
      () => parseMeasuredAt(wokeUp, nowUtc: now, zone: zone) ?? now,
    );
    final bed = inField('bed', () {
      if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(bedText)) {
        return parseMeasuredAt(bedText, nowUtc: now, zone: zone)!;
      }
      String on(DateTime wall) =>
          '${wall.year.toString().padLeft(4, '0')}-'
          '${wall.month.toString().padLeft(2, '0')}-'
          '${wall.day.toString().padLeft(2, '0')} $bedText';
      final upWall = zone.toLocal(up);
      DateTime? sameDay;
      try {
        sameDay = parseMeasuredAt(on(upWall), nowUtc: now, zone: zone);
      } on InputError catch (e) {
        if (e.code != 'FUTURE_TIME') rethrow;
      }
      if (sameDay != null && sameDay.isBefore(up)) return sameDay;
      final dayBefore = DateTime.utc(upWall.year, upWall.month, upWall.day - 1);
      return parseMeasuredAt(on(dayBefore), nowUtc: now, zone: zone)!;
    });
    final details = SleepNightDetails(
      wentToBed: bed,
      wokeUp: up,
      feeling: feeling,
    );
    final problem = details.problem();
    if (problem != null) throw InputError(problem, 'bed');
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.sleepNight,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: up,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.sleepNight),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records how the person says they feel now (or at the typed time).
  Future<HealthRecord> recordFeeling({
    required String profileId,
    SelfLevel? energy,
    SelfLevel? mood,
    SelfLevel? stress,
    String when = '',
    String? correcting,
  }) async {
    // A correction replaces the shown version; the earlier one stays.
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.feelingCheckIn) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final details = FeelingCheckInDetails(
      energy: energy,
      mood: mood,
      stress: stress,
    );
    final problem = details.problem();
    if (problem != null) throw InputError(problem);
    final now = clock.nowUtc();
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.feelingCheckIn,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      // A correction left without a time keeps the check-in's own time.
      observedAt:
          parseMeasuredAt(when, nowUtc: now) ?? target?.observedAt ?? now,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.feelingCheckIn),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records something eaten or drunk, as typed. [nutrients] holds only the
  /// values the person typed (blank ones are left out: missing, not zero).
  Future<HealthRecord> recordFood({
    required String profileId,
    required String what,
    String amount = '',
    Map<PrintedNutrient, String> nutrients = const {},
    LabelBasis? per,
    String when = '',
    String? correcting,
  }) async {
    // A correction replaces the shown version of an entry; the earlier one
    // stays in history.
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.foodEntry) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final now = clock.nowUtc();
    // A correction left without a time keeps the entry's own time.
    final at = parseMeasuredAt(when, nowUtc: now) ?? target?.observedAt ?? now;
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    // Each label value is checked on its own, so the error names its field.
    for (final e in nutrients.entries) {
      final v = opt(e.value);
      if (v != null && parsePrintedNumber(v) == null) {
        throw InputError(
          'FOOD_NUTRIENT_NOT_A_NUMBER',
          'nutrient-${e.key.name}',
        );
      }
    }
    final details = FoodEntryDetails(
      what: what.trim(),
      amount: opt(amount),
      per: per,
      nutrients: {
        for (final e in nutrients.entries)
          if (opt(e.value) != null) e.key: opt(e.value)!,
      },
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        problem.endsWith('_TOO_LONG')
            ? 'TEXT_TOO_LONG'
            : problem.startsWith('FOOD_WHAT')
            ? 'EMPTY'
            : problem,
        problem == 'FOOD_LABEL_BASIS_REQUIRED'
            ? 'per'
            : problem.startsWith('FOOD_AMOUNT')
            ? 'amount'
            : 'what',
      );
    }
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.foodEntry,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: at,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.foodEntry),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records one activity as typed: minutes and steps are whole numbers,
  /// blank = not given. [correcting] makes it a new version of that entry.
  Future<HealthRecord> recordActivity({
    required String profileId,
    required String what,
    String minutes = '',
    String steps = '',
    String when = '',
    String? correcting,
  }) async {
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.activityEntry) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    int? whole(String raw, String field) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      if (!RegExp(r'^\d{1,6}$').hasMatch(t)) {
        throw InputError('NOT_A_WHOLE_NUMBER', field);
      }
      return int.parse(t);
    }

    final now = clock.nowUtc();
    // A correction left without a time keeps the entry's own time.
    final at = parseMeasuredAt(when, nowUtc: now) ?? target?.observedAt ?? now;
    final details = ActivityEntryDetails(
      what: what.trim(),
      minutes: whole(minutes, 'minutes'),
      steps: whole(steps, 'steps'),
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        switch (problem) {
          final p when p.endsWith('_TOO_LONG') => 'TEXT_TOO_LONG',
          final p when p.startsWith('ACTIVITY_WHAT') => 'EMPTY',
          final p => p,
        },
        switch (problem) {
          'ACTIVITY_MINUTES_RANGE' => 'minutes',
          'ACTIVITY_STEPS_RANGE' => 'steps',
          _ => 'what',
        },
      );
    }
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.activityEntry,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: at,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.activityEntry),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records a condition or symptom as the person names it, with who it
  /// comes from. [correcting] makes it a new version of that entry.
  Future<HealthRecord> recordCondition({
    required String profileId,
    required String name,
    required ConditionType nature,
    required ConditionTime time,
    required ConditionSource source,
    String since = '',
    String? correcting,
  }) async {
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.conditionEntry) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final details = ConditionEntryDetails(
      name: name.trim(),
      nature: nature,
      time: time,
      source: source,
      since: since.trim().isEmpty ? null : since.trim(),
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        problem.endsWith('_TOO_LONG') ? 'TEXT_TOO_LONG' : 'EMPTY',
        problem.startsWith('CONDITION_SINCE') ? 'since' : 'name',
      );
    }
    final now = clock.nowUtc();
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.conditionEntry,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: target?.observedAt ?? now,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.conditionEntry),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// The live condition entries, the latest recorded first.
  Future<List<HealthRecord>> conditions(String profileId) async {
    final all = await repository.records(
      profileId,
      kind: RecordKind.conditionEntry,
    );
    return [
      for (final e in buildTimeline(all))
        for (final h in e.heads)
          if (h.details is ConditionEntryDetails) h,
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  /// Records a preventive item (vaccination, screening, check-up) as the
  /// person names it: done, planned or unsure, with who it comes from and
  /// when as typed. No result is stored and nothing is scheduled or
  /// recommended. [correcting] makes it a new version of that entry.
  Future<HealthRecord> recordPreventive({
    required String profileId,
    required String name,
    required PreventiveType nature,
    required PreventiveStatus status,
    required ConditionSource source,
    String when = '',
    String? correcting,
  }) async {
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.preventiveEntry) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    // Carrying out a plan is a new fact, not a fix of the plan: a correction
    // never turns "planned" into "done" (planned ≠ completed).
    if (target != null &&
        status == PreventiveStatus.done &&
        (target.details as PreventiveEntryDetails?)?.status ==
            PreventiveStatus.planned) {
      throw const InputError('PLANNED_NOT_DONE', 'status');
    }
    final details = PreventiveEntryDetails(
      name: name.trim(),
      nature: nature,
      status: status,
      source: source,
      when: when.trim().isEmpty ? null : when.trim(),
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        problem.endsWith('_TOO_LONG') ? 'TEXT_TOO_LONG' : 'EMPTY',
        problem.startsWith('PREVENTIVE_WHEN') ? 'when' : 'name',
      );
    }
    final now = clock.nowUtc();
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.preventiveEntry,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: target?.observedAt ?? now,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.preventiveEntry),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records a reference to a document the person keeps (F010 slice 1):
  /// its title, kind, own date, issuer and where it is kept, each as typed.
  /// The app never reads, opens, uploads or stores the document.
  /// [correcting] makes it a new version of that entry, keeping its time.
  Future<HealthRecord> recordDocument({
    required String profileId,
    required String title,
    required DocumentType nature,
    String date = '',
    String issuer = '',
    String whereKept = '',
    String? correcting,
  }) async {
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.documentReference) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    final details = DocumentReferenceDetails(
      title: title.trim(),
      nature: nature,
      date: opt(date),
      issuer: opt(issuer),
      whereKept: opt(whereKept),
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        problem.endsWith('_TOO_LONG') ? 'TEXT_TOO_LONG' : 'EMPTY',
        switch (problem) {
          final p when p.startsWith('DOCUMENT_DATE') => 'date',
          final p when p.startsWith('DOCUMENT_ISSUER') => 'issuer',
          final p when p.startsWith('DOCUMENT_WHERE') => 'whereKept',
          _ => 'title',
        },
      );
    }
    final now = clock.nowUtc();
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.documentReference,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: target?.observedAt ?? now,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.documentReference),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// The live document references, the latest recorded first.
  Future<List<HealthRecord>> documents(String profileId) async {
    final all = await repository.records(
      profileId,
      kind: RecordKind.documentReference,
    );
    return [
      for (final e in buildTimeline(all))
        for (final h in e.heads)
          if (h.details is DocumentReferenceDetails) h,
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  /// The live preventive entries, the latest recorded first.
  Future<List<HealthRecord>> preventives(String profileId) async {
    final all = await repository.records(
      profileId,
      kind: RecordKind.preventiveEntry,
    );
    return [
      for (final e in buildTimeline(all))
        for (final h in e.heads)
          if (h.details is PreventiveEntryDetails) h,
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  /// The live activity entries, the latest first.
  Future<List<HealthRecord>> activities(String profileId) async {
    final all = await repository.records(
      profileId,
      kind: RecordKind.activityEntry,
    );
    return [
      for (final e in buildTimeline(all))
        for (final h in e.heads)
          if (h.details is ActivityEntryDetails) h,
    ]..sort((a, b) => b.observedAt.compareTo(a.observedAt));
  }

  /// The live food entries, the latest first.
  Future<List<HealthRecord>> foods(String profileId) async {
    final all = await repository.records(profileId, kind: RecordKind.foodEntry);
    return [
      for (final e in buildTimeline(all))
        for (final h in e.heads)
          if (h.details is FoodEntryDetails) h,
    ]..sort((a, b) => b.observedAt.compareTo(a.observedAt));
  }

  /// The live check-ins, the latest first.
  Future<List<HealthRecord>> feelings(String profileId) async {
    final all = await repository.records(
      profileId,
      kind: RecordKind.feelingCheckIn,
    );
    return [
      for (final e in buildTimeline(all))
        for (final h in e.heads)
          if (h.details is FeelingCheckInDetails) h,
    ]..sort((a, b) => b.observedAt.compareTo(a.observedAt));
  }

  /// The live nights, the latest waking first.
  Future<List<HealthRecord>> sleepNights(String profileId) async {
    final all = await repository.records(
      profileId,
      kind: RecordKind.sleepNight,
    );
    final heads = [
      for (final e in buildTimeline(all))
        for (final h in e.heads)
          if (h.details is SleepNightDetails) h,
    ]..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    return heads;
  }

  /// Each live medicine or supplement with its newest live plan and its
  /// recorded doses (newest first). Doses come only from dose records.
  Future<List<MedicationView>> medications(String profileId) async {
    final all = await repository.records(profileId);
    List<TimelineEntry> of(RecordKind k) =>
        buildTimeline(all.where((r) => r.kind == k));
    final planRecords = [
      for (final r in all)
        if (r.kind == RecordKind.medicationPlan) r,
    ];
    final doses = of(RecordKind.medicationIntake);
    return [
      for (final e in of(RecordKind.medicationItem))
        if (e.heads.isNotEmpty && e.shown.details is MedicationItemDetails)
          MedicationView(
            rootId: e.rootId,
            item: e.shown.details! as MedicationItemDetails,
            itemRecord: e.shown,
            plan: _latest(planRecords, e.rootId),
            doses: [
              for (final d in doses)
                for (final h in d.heads)
                  if (h.details is MedicationIntakeDetails &&
                      (h.details! as MedicationIntakeDetails).itemRootId ==
                          e.rootId)
                    h,
            ]..sort((a, b) => b.observedAt.compareTo(a.observedAt)),
          ),
    ];
  }

  /// The shown plan of an item among [stored] plan records (in the order
  /// they were written): the live one saved last; on equal save times (a
  /// coarse clock) the one written later.
  static MedicationPlanDetails? _latest(
    List<HealthRecord> stored,
    String itemRootId,
  ) {
    final written = {for (var i = 0; i < stored.length; i++) stored[i].id: i};
    HealthRecord? best;
    for (final p in buildTimeline(stored)) {
      for (final h in p.heads) {
        final d = h.details;
        if (d is! MedicationPlanDetails || d.itemRootId != itemRootId) continue;
        if (best == null ||
            h.recordedAt.isAfter(best.recordedAt) ||
            (h.recordedAt == best.recordedAt &&
                written[h.id]! > written[best.id]!)) {
          best = h;
        }
      }
    }
    return best?.details as MedicationPlanDetails?;
  }
}

/// One medicine or supplement as Human OS shows it (F008).
class MedicationView {
  const MedicationView({
    required this.rootId,
    required this.item,
    required this.itemRecord,
    required this.plan,
    required this.doses,
  });

  final String rootId;
  final MedicationItemDetails item;
  final HealthRecord itemRecord;
  final MedicationPlanDetails? plan;

  /// Dose records only, newest first.
  final List<HealthRecord> doses;

  int count(IntakeStatus s) => doses
      .where((d) => (d.details! as MedicationIntakeDetails).status == s)
      .length;
}
