part of 'heartbeat_service.dart';

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

/// Lab results as printed (F004).
mixin _LabUseCases on _HeartbeatCore {
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
}
