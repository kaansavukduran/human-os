import '../../domain/settings/date_style.dart';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/ids.dart' show Clock;
import '../../application/heartbeat_service.dart';
import '../../domain/ports/health_repository.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/casing.dart';
import '../../l10n/strings.dart';
import '../../navigation/destination_switch.dart';
import '../../navigation/destinations.dart';
import '../measurements/measurement_format.dart';
import '../../presentation/widgets/area_intro.dart';
import '../../presentation/widgets/entry_list.dart';
import '../../presentation/widgets/first_step.dart';
import '../../presentation/widgets/loading_line.dart';
import '../../presentation/widgets/midnight_refresh.dart';
import '../../presentation/widgets/read_failed_note.dart';
import '../../presentation/widgets/record_row.dart';
import '../../presentation/widgets/sheet_parts.dart';
import '../../presentation/widgets/whole_label_field.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/status_chip.dart';
import '../../presentation/widgets/whole_chip.dart';

/// Timeline (ladder F003): every fact once, newest first, with its versions.
/// Corrections add versions; "entered in error" withdraws a version; delete
/// removes the whole fact from views. Nothing is rewritten.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with WidgetsBindingObserver, MidnightRefresh {
  List<TimelineEntry> _entries = const [];
  bool _showHidden = false;
  bool _loaded = false;
  bool _readFailed = false;

  HeartbeatService get _svc => widget.services.heartbeat;
  String get _me => widget.services.self.id;

  /// The app's clock (R025): "Today" and "Yesterday" follow it, and the
  /// headers are written again just after local midnight and on resume.
  @override
  Clock get midnightClock => _svc.clock;

  @override
  void didUpdateWidget(TimelineScreen old) {
    super.didUpdateWidget(old);
    if (old.services.heartbeat.clock != _svc.clock) scheduleMidnight();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final e = await _svc.timeline(_me, includeHidden: _showHidden);
      if (mounted) {
        setState(() {
          _entries = e;
          _loaded = true;
          _readFailed = false;
        });
      }
    } on Object {
      // Said in words with Try again, never a blank list (AIONIA v1.2).
      if (mounted) setState(() => _readFailed = true);
    }
  }

  void _retry() {
    setState(() => _readFailed = false);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final go = DestinationSwitch.maybeOf(context);
    final entries = _readFailed ? const <TimelineEntry>[] : _entries;
    // Day headers (U038): the entries are newest first, so a header goes
    // before the first entry of each day.
    final items = timelineItems(s, entries, midnightClock.nowUtc().toLocal());
    return EntryList(
      key: const ValueKey('screen-timeline'),
      itemCount: items.length,
      itemBuilder: (_, i) => switch (items[i]) {
        (final day, final label, null) => DayHeader(
          label,
          key: ValueKey('timeline-day-$day'),
          first: i == 0,
        ),
        (_, _, final TimelineEntry e) => _EntryTile(
          key: ValueKey('timeline-entry-${e.rootId}'),
          entry: e,
          onTap: () => _openDetail(e),
        ),
      },
      header: [
        const AreaIntro(area: DestinationId.timeline, terms: ['correction']),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const ValueKey('timeline-show-hidden'),
          contentPadding: EdgeInsets.zero,
          title: Text(s.showHidden),
          // The two words in plain terms, for someone who has never
          // deleted anything yet (U041).
          subtitle: Text(
            s.showHiddenHelp,
            key: const ValueKey('timeline-show-hidden-help'),
          ),
          value: _showHidden,
          onChanged: (v) {
            setState(() => _showHidden = v);
            _reload();
          },
        ),
        if (_readFailed)
          ReadFailedNote(id: 'timeline', onRetry: _retry)
        else if (!_loaded)
          const LoadingLine()
        else if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: FirstStep(
              key: const ValueKey('timeline-empty'),
              text: s.timelineFirstStep,
              action: go == null
                  ? null
                  : TextButton.icon(
                      key: const ValueKey('timeline-go-today'),
                      onPressed: () => go(DestinationId.today),
                      icon: const Icon(Icons.wb_sunny_outlined),
                      label: Text(s.goToToday),
                    ),
            ),
          ),
      ],
    );
  }

  Future<void> _openDetail(TimelineEntry e) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EntryDetail(entry: e, svc: _svc, profileId: _me),
    );
    if (changed == true) await _reload();
  }
}

String fmtValue(S s, HealthRecord r) {
  if (r.kind.isMeasurement) return measurementValue(s, r);
  final d = r.details;
  if (d is MedicationItemDetails) {
    return '${d.name} · ${s.medsCategoryLabel(d.category)}';
  }
  if (d is FeelingCheckInDetails) return s.feelLine(d.energy, d.mood, d.stress);
  if (d is FoodEntryDetails) return s.foodLine(d);
  if (d is ActivityEntryDetails) return s.actLine(d);
  if (d is ConditionEntryDetails) return s.condLine(d);
  if (d is PreventiveEntryDetails) return s.prevLine(d);
  if (d is DocumentReferenceDetails) return s.docLine(d);
  if (d is SleepNightDetails) {
    return s.sleepLine(
      fmtWhen(d.wentToBed),
      fmtWhen(d.wokeUp),
      d.timeInBed,
      d.feeling,
    );
  }
  if (d is MedicationPlanDetails) {
    return d.state == PlanState.active
        ? d.schedule
        : '${d.schedule} · ${s.medsPlanStateLabel(d.state)}';
  }
  if (d is MedicationIntakeDetails) {
    return [
      d.status == IntakeStatus.taken ? s.medsDoseTaken : s.medsDoseSkipped,
      ?d.amount,
    ].join(' · ');
  }
  final printed = r.lab?.result;
  if (printed != null && r.valueStatus == ValueStatus.present) {
    return labPrintedValue(s, r, printed);
  }
  final q = r.quantity;
  if (r.valueStatus != ValueStatus.present || q == null) {
    return s.valueStatus(r.valueStatus);
  }
  final v = r.kind == RecordKind.labResult
      ? (r.originalText ?? q.value.toString())
      : r.kind == RecordKind.bodyWeight
      ? fmtShown(s, q.value, r.originalText)
      : decimalIn(
          s.lang,
          q.value == q.value.roundToDouble()
              ? q.value.toStringAsFixed(0)
              : q.value.toStringAsFixed(1),
        );
  final unit = q.unit;
  return unit == null ? '$v (${s.unitNotGiven})' : '$v $unit';
}

/// A lab sample date is a calendar day (stored as UTC midnight): shown
/// without a time and without a time-zone shift.
String fmtObserved(HealthRecord r) {
  if (!r.observedDateOnly) return fmtWhen(r.observedAt);
  final d = r.observedAt;
  return formatDay(d.year, d.month, d.day, displayDateOrder);
}

String recordTitle(S s, HealthRecord r) =>
    r.lab?.analyteLabel ?? s.recordKind(r.kind);

String fmtWhen(DateTime utc) =>
    formatWhenShown(utc.toLocal(), displayDateOrder, displayClock);

/// The calendar day a record belongs to (U038): a lab sample date is its
/// own calendar day (stored as UTC midnight, never shifted); any other
/// record falls on the local day it was observed.
DateTime recordDay(HealthRecord r) =>
    recordDayOf(r.observedAt, dateOnly: r.observedDateOnly);

/// The calendar day of the stored instant [utc]: as stored for a date
/// alone, else the local day.
DateTime recordDayOf(DateTime utc, {required bool dateOnly}) {
  final d = dateOnly ? utc : utc.toLocal();
  return DateTime(d.year, d.month, d.day);
}

/// "Today", "Yesterday" or the date in the chosen order, for [day] seen
/// from the local day of [now].
String dayLabel(S s, DateTime day, DateTime now) {
  if (day == DateTime(now.year, now.month, now.day)) return s.dayToday;
  if (day == DateTime(now.year, now.month, now.day - 1)) {
    return s.dayYesterday;
  }
  return formatDay(day.year, day.month, day.day, displayDateOrder);
}

/// The Timeline's rows: a day header `(yyyy-mm-dd, label, null)` before
/// the first entry of each day, then each entry `(day, label, entry)`.
List<(String, String, TimelineEntry?)> timelineItems(
  S s,
  List<TimelineEntry> entries,
  DateTime now,
) {
  final items = <(String, String, TimelineEntry?)>[];
  String? last;
  for (final e in entries) {
    final d = recordDay(e.shown);
    final key = formatDay(d.year, d.month, d.day, DateOrder.iso);
    final label = dayLabel(s, d, now);
    if (key != last) items.add((key, label, null));
    last = key;
    items.add((key, label, e));
  }
  return items;
}

/// When, under a day header: the time of day alone, as the chosen clock
/// shows it. A sample date has no time, so it says it is a sample date.
String fmtTimeOfDay(S s, HealthRecord r) {
  if (r.observedDateOnly) return '${s.labSampleDate}: ${fmtObserved(r)}';
  final full = fmtWhen(r.observedAt);
  return full.substring(full.indexOf(' ') + 1);
}

/// "time corrected from … to …" when [v] is a measurement correction whose
/// time differs from the version it corrects (G-48); null otherwise.
String? timeCorrectedLine(S s, HealthRecord v, Map<String, HealthRecord> byId) {
  if (!v.kind.isMeasurement || isAmendMarker(v)) return null;
  final prev = byId[v.supersedesId];
  if (prev == null || prev.observedAt == v.observedAt) return null;
  return s.timeCorrected(fmtWhen(prev.observedAt), fmtWhen(v.observedAt));
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({super.key, required this.entry, required this.onTap});

  final TimelineEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = entry.shown;
    final value = entry.status == EntryStatus.conflict
        ? s.versionsDisagree
        : fmtValue(s, r);
    // One row (U038): what and the value as typed, then the time; where it
    // came from, when it was saved and the report's other lines are in the
    // record's sheet, under "Details".
    return RecordRow(
      title: recordTitle(s, r),
      value: value,
      when: fmtTimeOfDay(s, r),
      onTap: onTap,
      chips: [
        // Worked out, modelled, planned …: said on the row, so it never
        // looks like a measurement (model output ≠ observed fact, R025).
        if (s.recordStateOnRow(r.state) case final state?)
          StatusChip(
            key: ValueKey('timeline-state-${r.id}'),
            label: state,
            tone: StatusTone.info,
          ),
        if (entry.corrected)
          StatusChip(
            label: s.versionsCount(entry.versions.length),
            tone: StatusTone.info,
          ),
        if (entry.status != EntryStatus.current)
          StatusChip(
            label: s.entryStatus(entry.status),
            tone: entry.status == EntryStatus.conflict
                ? StatusTone.warn
                : StatusTone.muted,
          ),
      ],
    );
  }
}

/// One fact: every version with why it exists, and the three different ways
/// to change it (correct, entered in error, delete).
class _EntryDetail extends StatefulWidget {
  const _EntryDetail({
    required this.entry,
    required this.svc,
    required this.profileId,
  });

  final TimelineEntry entry;
  final HeartbeatService svc;
  final String profileId;

  @override
  State<_EntryDetail> createState() => _EntryDetailState();
}

class _EntryDetailState extends State<_EntryDetail> {
  final _controller = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _context = TextEditingController();
  final _when = TextEditingController();

  /// The unit and meal timing of a capillary glucose being corrected
  /// (D-048): opened as stored, changeable, never converted.
  String? _unit;
  GlucoseTiming? _timing;
  String? _correcting;
  String? _errorCode;
  String? _errorField;
  bool _busy = false;

  /// The versions' machinery is shown (U038); closed when the sheet opens.
  bool _details = false;

  @override
  void dispose() {
    _controller.dispose();
    _systolic.dispose();
    _diastolic.dispose();
    _context.dispose();
    _when.dispose();
    super.dispose();
  }

  void _startCorrecting(HealthRecord head) => setState(() {
    _correcting = head.id;
    _errorCode = null;
    _errorField = null;
    _controller.clear();
    _systolic.clear();
    _diastolic.clear();
    // The note belongs to the observation; a correction keeps it unless
    // the person changes it.
    _context.text = head.context ?? '';
    _unit = head.quantity?.unit;
    _timing = switch (head.details) {
      GlucoseTimingDetails(:final timing) => timing,
      _ => null,
    };
    if (head.kind.isMeasurement) {
      // A measurement opens as stored (G-48): its value as typed and its
      // time, so a wrong time alone can be put right. The same text saved
      // back keeps the stored instant; "not measured" opens empty.
      _when.text = typedLocal(head.observedAt);
      final d = head.details;
      if (head.valueStatus == ValueStatus.present) {
        if (d is BloodPressureDetails) {
          _systolic.text = d.systolicText ?? fmtMeasured(d.systolic, null);
          _diastolic.text = d.diastolicText ?? fmtMeasured(d.diastolic, null);
        } else if (head.quantity case final q?) {
          _controller.text = head.originalText ?? fmtMeasured(q.value, null);
        }
      }
    }
  });

  /// An error without a field of its own shows on the form's first field.
  String? _errorFor(S s, String field) {
    final first = _correctingKind == RecordKind.bloodPressure
        ? 'systolic'
        : 'value';
    return _errorCode != null && (_errorField ?? first) == field
        ? s.inputError(_errorCode!)
        : null;
  }

  RecordKind? get _correctingKind {
    for (final h in widget.entry.heads) {
      if (h.id == _correcting) return h.kind;
    }
    return null;
  }

  Widget _correctField(
    S s,
    TextEditingController c,
    String label,
    String key,
    String field, {
    bool number = true,
    bool autofocus = false,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: WholeLabelField(
      label: label,
      field: (labelText) => TextField(
        key: ValueKey(key),
        controller: c,
        autofocus: autofocus,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: number ? null : const [ContextLengthFormatter()],
        decoration: InputDecoration(
          labelText: labelText,
          helperText: helper,
          helperMaxLines: 20,
          border: const OutlineInputBorder(),
          errorText: _errorFor(s, field),
          errorMaxLines: 3,
          counterText: '',
        ),
      ),
    ),
  );

  /// When the measurement was taken (G-48): quick picks and the field,
  /// opened with the stored time.
  List<Widget> _whenFields(S s, HealthRecord head) {
    final now = DateTime.now();
    return [
      TimePicks(
        keyPrefix: 'correct-when',
        controller: _when,
        picks: [
          (s.presetKeepTime, typedLocal(head.observedAt), true),
          // "Now" as a time: an empty field keeps the stored time here.
          (s.presetNow, typedWall(now), true),
          ...TimePicks.recent(s, now: now).skip(1),
        ],
      ),
      // A "not measured" entry has no reading time: its time is when the
      // miss was noted (R021).
      if (head.valueStatus == ValueStatus.notMeasured)
        _correctField(
          s,
          _when,
          s.correctWhenNotMeasuredField,
          'correct-input-when',
          'when',
          number: false,
          helper: s.correctWhenNotMeasuredHint,
        )
      else
        _correctField(
          s,
          _when,
          s.correctWhenField,
          'correct-input-when',
          'when',
          number: false,
          helper: s.correctWhenHint,
        ),
    ];
  }

  /// The correction form of [head]'s kind: one number for body weight and
  /// scalar measurements, two for blood pressure, plus the note and, for a
  /// measurement, its time.
  List<Widget> _correctionFields(S s, HealthRecord head) {
    final helper = head.valueStatus == ValueStatus.notMeasured
        ? s.correctNotMeasuredValueHint
        : s.amendExplain(AmendReason.correction);
    if (head.kind == RecordKind.bloodPressure) {
      return [
        _correctField(
          s,
          _systolic,
          s.systolicField,
          'correct-input-systolic',
          'systolic',
          autofocus: true,
          helper: helper,
        ),
        _correctField(
          s,
          _diastolic,
          s.diastolicField,
          'correct-input-diastolic',
          'diastolic',
        ),
        _correctField(
          s,
          _context,
          s.contextField,
          'correct-input-context',
          'context',
          number: false,
          helper: s.contextHelp,
        ),
        ..._whenFields(s, head),
      ];
    }
    return [
      _correctField(
        s,
        _controller,
        head.kind.isMeasurement ? s.measurementField(head.kind) : s.weightField,
        'correct-input',
        'value',
        autofocus: true,
        helper: helper,
      ),
      if (head.kind.units.length > 1) ..._glucoseChoices(s, head.kind),
      if (head.kind.isMeasurement) ...[
        _correctField(
          s,
          _context,
          s.contextField,
          'correct-input-context',
          'context',
          number: false,
          helper: s.contextHelp,
        ),
        ..._whenFields(s, head),
      ],
    ];
  }

  /// The unit (and, for capillary glucose, the meal timing) as chips,
  /// opened with the stored choice (D-048).
  List<Widget> _glucoseChoices(S s, RecordKind kind) {
    final text = Theme.of(context).textTheme;
    final error = _errorCode != null && _errorField == 'unit'
        ? s.inputError(_errorCode!)
        : null;
    return [
      // One group to a screen reader; each unit spoken in words.
      Semantics(
        key: const ValueKey('correct-unit-group'),
        container: true,
        label: s.glucoseUnitLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(s.glucoseUnitLabel, style: text.bodyMedium),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in kind.units)
                  WholeChip.choice(
                    key: ValueKey('correct-unit-$u'),
                    label: s.unit(u),
                    semanticsLabel: s.spokenUnit(u),
                    selected: _unit == u,
                    onSelected: _busy ? null : (_) => setState(() => _unit = u),
                  ),
              ],
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          error ?? s.glucoseUnitHelp,
          style: text.bodySmall?.copyWith(
            color: error == null
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.error,
          ),
        ),
      ),
      if (kind == RecordKind.capillaryGlucose) ...[
        Text(s.glucoseTimingLabel, style: text.bodyMedium),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in GlucoseTiming.values)
                WholeChip.choice(
                  key: ValueKey('correct-timing-${t.code}'),
                  label: s.glucoseTiming(t),
                  selected: _timing == t,
                  onSelected: _busy
                      ? null
                      : (on) => setState(() => _timing = on ? t : null),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  Future<void> _saveCorrection(HealthRecord head) => _run(
    () => head.kind.isMeasurement
        ? widget.svc.correctMeasurement(
            profileId: widget.profileId,
            targetId: head.id,
            input: MeasurementInput(
              value: _controller.text,
              systolic: _systolic.text,
              diastolic: _diastolic.text,
              context: _context.text,
              when: _when.text,
              unit: _unit ?? '',
              // A timing belongs to a reading: none is sent while the
              // entry stays "not measured" (no number typed).
              glucoseTiming:
                  head.valueStatus == ValueStatus.notMeasured &&
                      _controller.text.trim().isEmpty
                  ? null
                  : _timing,
            ),
          )
        : widget.svc.correctWeightKg(
            profileId: widget.profileId,
            targetId: head.id,
            input: _controller.text,
          ),
  );

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _errorCode = null;
      _errorField = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } on InputError catch (e) {
      setState(() {
        _errorCode = e.code;
        _errorField = e.field;
      });
    } on RecordValidationError catch (e) {
      setState(() => _errorCode = e.code);
    } on StorageWriteRefused catch (e) {
      setState(() => _errorCode = e.code);
    } catch (_) {
      setState(() => _errorCode = 'SAVE_FAILED');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAmend(HealthRecord head, AmendReason reason) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.amendTitle(reason)),
        content: Text(s.amendExplain(reason)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: ValueKey('confirm-${reason.code}'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(s.amendAction(reason)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => widget.svc.amend(
        profileId: widget.profileId,
        targetId: head.id,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final e = widget.entry;
    final headIds = {for (final h in e.heads) h.id};
    final byId = {for (final v in e.versions) v.id: v};
    final quiet = Theme.of(context).colorScheme.onSurfaceVariant;
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('timeline-detail'),
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recordTitle(s, e.shown), style: text.titleLarge),
            const SizedBox(height: Space.xs),
            Text(
              s.entryStatusExplain(e.status),
              style: text.bodyMedium?.copyWith(color: quiet),
            ),
            const SizedBox(height: Space.l),
            Semantics(
              header: true,
              child: Text(s.versions, style: text.titleSmall),
            ),
            // Each version: the value as typed first, then why it exists
            // and when; the machinery (when it was saved, where it came
            // from, the report's other lines) behind "Details" (U038).
            for (final v in e.versions.reversed)
              Padding(
                key: ValueKey('version-${v.id}'),
                padding: const EdgeInsets.only(top: Space.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmtValue(s, v),
                      style: text.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    // The lab's printed range stays in view under the
                    // value, as on Labs (R025).
                    if (v.lab case final lab?)
                      Text(
                        lab.referenceInterval != null
                            ? s.labIntervalLine(lab.referenceInterval!)
                            : lab.referenceText != null
                            ? s.labPrintedRange(lab.referenceText!)
                            : s.labNoRangePrinted,
                        key: ValueKey('timeline-lab-range-${v.id}'),
                        style: text.bodyMedium?.copyWith(color: quiet),
                      ),
                    Text(
                      [
                        s.versionRole(
                          isFirst: v.supersedesId == null,
                          withdrawn: e.withdrawn.contains(v.id),
                          current: headIds.contains(v.id) && e.isLive,
                        ),
                        if (v.kind.isMeasurement &&
                            savedWhenDifferent(v, fmtWhen) != null)
                          s.measuredAtLabel(fmtWhen(v.observedAt))
                        else
                          fmtObserved(v),
                        // A correction that moved the time says from what
                        // to what (G-48); the earlier version keeps its own
                        // time.
                        ?timeCorrectedLine(s, v, byId),
                        if (v.kind.isMeasurement) ...[
                          if (typedWhenDifferent(v) case final typed?)
                            '${s.enteredAs} "$typed"',
                          if (v.context case final note?)
                            '${s.contextLabel}: "$note"',
                        ] else if (v.originalText != null)
                          '"${v.originalText}"',
                      ].join(' · '),
                      style: text.bodyMedium?.copyWith(color: quiet),
                    ),
                    if (_details)
                      Padding(
                        key: ValueKey('version-details-${v.id}'),
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DetailLine(
                              '${s.enteredOn} ${fmtWhen(v.recordedAt)}',
                            ),
                            DetailLine(
                              '${s.recordState(v.state)} · '
                              '${s.provenanceKind(v.provenance.kind)}',
                            ),
                            if (v.lab case final lab?)
                              for (final line in labReportLines(
                                s,
                                lab,
                                fmtWhen,
                              ))
                                // The interval is already in view above.
                                if (lab.referenceInterval == null ||
                                    line !=
                                        s.labIntervalLine(
                                          lab.referenceInterval!,
                                        ))
                                  DetailLine(line),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: Space.xs),
            DetailsToggle(
              id: 'timeline-${e.rootId}',
              open: _details,
              about: recordTitle(s, e.shown),
              onToggle: () => setState(() => _details = !_details),
            ),
            if (e.deletion != null)
              Text(
                '${s.entryStatus(EntryStatus.deleted)} · '
                '${fmtWhen(e.deletion!.deletedAt ?? e.deletion!.recordedAt)}',
                key: const ValueKey('timeline-deleted-at'),
                style: text.bodySmall,
              ),
            if (e.isLive) ...[
              const Divider(height: 24),
              for (final head in e.heads) ...[
                if (e.heads.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(fmtValue(s, head), style: text.titleSmall),
                  ),
                if (_correcting == head.id) ...[
                  ..._correctionFields(s, head),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        key: const ValueKey('correct-save'),
                        onPressed: _busy ? null : () => _saveCorrection(head),
                        child: Text(s.saveCorrection),
                      ),
                      TextButton(
                        key: const ValueKey('correct-cancel'),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _correcting = null;
                                _errorCode = null;
                                _errorField = null;
                              }),
                        child: Text(s.cancel),
                      ),
                    ],
                  ),
                ] else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Lab results are corrected on Labs, where every
                      // printed field can be re-entered.
                      if (head.kind == RecordKind.bodyWeight ||
                          head.kind.isMeasurement)
                        OutlinedButton.icon(
                          key: ValueKey('action-correct-${head.id}'),
                          onPressed: _busy
                              ? null
                              : () => _startCorrecting(head),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(s.amendAction(AmendReason.correction)),
                        ),
                      OutlinedButton.icon(
                        key: ValueKey('action-error-${head.id}'),
                        onPressed: _busy
                            ? null
                            : () => _confirmAmend(
                                head,
                                AmendReason.enteredInError,
                              ),
                        icon: const Icon(Icons.block_outlined),
                        label: Text(s.amendAction(AmendReason.enteredInError)),
                      ),
                      OutlinedButton.icon(
                        key: ValueKey('action-delete-${head.id}'),
                        onPressed: _busy
                            ? null
                            : () => _confirmAmend(head, AmendReason.deleted),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(s.amendAction(AmendReason.deleted)),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
              ],
              if (_errorCode != null && _correcting == null)
                Text(
                  s.inputError(_errorCode!),
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
