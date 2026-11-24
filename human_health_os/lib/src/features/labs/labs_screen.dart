import '../../domain/settings/date_style.dart';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../application/heartbeat_service.dart';
import '../../domain/labs/lab_groups.dart';
import '../../domain/ports/health_repository.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../../navigation/destinations.dart';
import '../../presentation/widgets/area_intro.dart';
import '../../presentation/widgets/entry_list.dart';
import '../../presentation/widgets/first_step.dart';
import '../../presentation/widgets/loading_line.dart';
import '../../presentation/widgets/read_failed_note.dart';
import '../../presentation/widgets/sheet_parts.dart';
import '../../presentation/widgets/status_chip.dart';
import '../../presentation/widgets/term_link.dart';
import '../../presentation/widgets/whole_label_field.dart';
import '../measurements/measurement_format.dart' show labReportLines;
import '../timeline/timeline_screen.dart' show fmtValue, fmtWhen;
import 'lab_group_screen.dart';

/// Labs (ladder F004): the list of current results first, and a sheet to
/// enter a result exactly as the report printed it (U030: results before
/// the form). Flags and ranges are the laboratory's, shown verbatim; the
/// app adds no interpretation.
class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

/// The add form's fields. They live with the screen, not the sheet, so the
/// sample date and laboratory stay for the next result from the same
/// report, and a closed add sheet keeps what was typed.
class _LabForm {
  _LabForm() {
    date.addListener(_dropCarriedIfReportChanged);
    laboratory.addListener(_dropCarriedIfReportChanged);
  }

  final analyte = TextEditingController();
  final value = TextEditingController();
  final unit = TextEditingController();
  final date = TextEditingController();
  final specimen = TextEditingController();
  final laboratory = TextEditingController();
  final flag = TextEditingController();
  final range = TextEditingController();

  /// More from the report (F004-S3, D-045), in a section collapsed by
  /// default. The report time stays for the next result from the same
  /// report, like the sample date and the laboratory, but only while both
  /// stay as they were (R019): a new sample date or laboratory means
  /// another report, so the carried report time is cleared.
  final reportTime = TextEditingController();
  final method = TextEditingController();
  final refLow = TextEditingController();
  final refHigh = TextEditingController();
  final refUnit = TextEditingController();
  final refPartition = TextEditingController();
  bool moreOpen = false;
  bool notReported = false;

  /// How the report prints the value (F004-S2): Number by default.
  LabValueKind kind = LabValueKind.number;
  HealthRecord? correcting;

  /// The add form's sample date, laboratory and report time, kept while a
  /// correction borrows the form (review finding: a cancelled correction
  /// left the old result's date in the next new entry).
  ({String date, String laboratory, String reportTime})? addMode;

  /// The sample date and laboratory a carried report time belongs to;
  /// null when the report time was not carried over from a saved result.
  ({String date, String laboratory})? carriedFor;

  void _dropCarriedIfReportChanged() {
    final c = carriedFor;
    if (c == null) return;
    if (date.text != c.date || laboratory.text != c.laboratory) {
      carriedFor = null;
      reportTime.clear();
    }
  }

  List<TextEditingController> get _all => [
    analyte,
    value,
    unit,
    date,
    specimen,
    laboratory,
    flag,
    range,
    ...more,
  ];

  /// The fields of the "More from the report" section.
  List<TextEditingController> get more => [
    reportTime,
    method,
    refLow,
    refHigh,
    refUnit,
    refPartition,
  ];

  /// How many of them hold text (shown while the section is collapsed).
  int get moreFilled => more.where((c) => c.text.trim().isNotEmpty).length;

  LabInput input() => LabInput(
    analyte: analyte.text,
    value: value.text,
    notReported: notReported,
    unit: unit.text,
    sampleDate: date.text,
    specimen: specimen.text,
    laboratory: laboratory.text,
    sourceFlag: flag.text,
    referenceText: range.text,
    kind: kind,
    reportTime: reportTime.text,
    method: method.text,
    refLow: refLow.text,
    refHigh: refHigh.text,
    refUnit: refUnit.text,
    refPartition: refPartition.text,
  );

  void startCorrection(HealthRecord r) {
    final lab = r.lab!;
    addMode ??= (
      date: date.text,
      laboratory: laboratory.text,
      reportTime: reportTime.text,
    );
    // Remembered in addMode; the correction's own values must not clear it.
    carriedFor = null;
    correcting = r;
    analyte.text = lab.analyteLabel;
    notReported = r.valueStatus != ValueStatus.present;
    kind = lab.valueKind;
    value.text = r.originalText ?? '';
    unit.text = r.quantity?.unit ?? lab.result?.unit ?? '';
    date.text = _ymd(r.observedAt);
    specimen.text = lab.specimen ?? '';
    laboratory.text = lab.laboratory ?? '';
    flag.text = lab.sourceFlag ?? '';
    range.text = lab.referenceText ?? '';
    final reported = lab.reportedAt;
    reportTime.text = reported == null ? '' : typedLocal(reported);
    method.text = lab.method ?? '';
    final iv = lab.referenceInterval;
    refLow.text = iv?.lowText ?? '';
    refHigh.text = iv?.highText ?? '';
    refUnit.text = iv?.unit ?? '';
    refPartition.text = iv?.partition ?? '';
    // A correction shows what the stored version holds.
    moreOpen = lab.hasReportDetails;
  }

  /// Clears one result's fields. Sample date, laboratory and report time
  /// stay for the next result from the same report, except after a
  /// correction, which gives back the add form's own values.
  void clear() {
    for (final c in [
      analyte,
      value,
      unit,
      specimen,
      flag,
      range,
      method,
      refLow,
      refHigh,
      refUnit,
      refPartition,
    ]) {
      c.clear();
    }
    moreOpen = false;
    notReported = false;
    kind = LabValueKind.number;
    correcting = null;
    final add = addMode;
    if (add != null) {
      date.text = add.date;
      laboratory.text = add.laboratory;
      reportTime.text = add.reportTime;
      addMode = null;
    }
    carriedFor = reportTime.text.trim().isEmpty
        ? null
        : (date: date.text, laboratory: laboratory.text);
  }

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _LabsScreenState extends State<LabsScreen> {
  final _form = _LabForm();

  /// "Saved" under the Add button. A notifier, so opening or closing the
  /// sheet repaints that line alone, never the list of results.
  final _saved = ValueNotifier<bool>(false);
  bool _loaded = false;
  bool _readFailed = false;
  List<TimelineEntry> _entries = const [];

  /// One row per shown version (a conflict lists each), flattened once per
  /// read so the list builds only the rows in view.
  List<LabRow> _rows = const [];

  /// Tests with more than one current result (F004-S4): the same name,
  /// unit and specimen as typed. A view of [_rows]; nothing is written.
  List<LabGroup> _groups = const [];

  HeartbeatService get _svc => widget.services.heartbeat;
  String get _me => widget.services.self.id;

  @override
  void initState() {
    super.initState();
    _form.date.text = _ymd(DateTime.now());
    _reload();
  }

  @override
  void dispose() {
    _form.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final e = await _svc.labTimeline(_me);
      if (mounted) {
        setState(() {
          _entries = e;
          _rows = [
            for (final x in e)
              for (final r in x.heads)
                (
                  record: r,
                  entryId: x.rootId,
                  conflict: x.status == EntryStatus.conflict,
                ),
          ];
          _groups = [
            for (final g in labGroups(_rows))
              if (g.length > 1) g,
          ];
          _loaded = true;
          _readFailed = false;
        });
      }
    } on Object {
      // Said in words with Try again, never "No records yet" for records
      // that could not be read (AIONIA v1.2).
      if (mounted) setState(() => _readFailed = true);
    }
  }

  void _retry() {
    setState(() => _readFailed = false);
    _reload();
  }

  /// Opens the sheet for a new result, or for a correction of [r].
  Future<void> _open([HealthRecord? r]) async {
    if (r != null) _form.startCorrection(r);
    _saved.value = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _LabSheet(svc: _svc, me: _me, form: _form),
    );
    if (!mounted) return;
    if (saved == true) {
      _form.clear();
      _saved.value = true;
      await _reload();
    } else if (_form.correcting != null) {
      // A correction that was not saved gives the add form its own values
      // (the form lives in the sheet; the list does not change).
      _form.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final rows = _readFailed || !_loaded ? const <Never>[] : _rows;
    final empty = !_readFailed && _loaded && _entries.isEmpty;
    final add = FilledButton.icon(
      key: const ValueKey('lab-add'),
      onPressed: _open,
      icon: const Icon(Icons.add),
      label: Text(s.labAdd),
    );
    return EntryList(
      key: const ValueKey('screen-labs'),
      itemCount: rows.length,
      itemBuilder: (_, i) => _LabTile(
        key: ValueKey('lab-row-${rows[i].record.id}'),
        record: rows[i].record,
        conflict: rows[i].conflict,
        onCorrect: () => _open(rows[i].record),
      ),
      header: [
        const AreaIntro(
          area: DestinationId.labs,
          terms: ['reference_interval', 'flag', 'unit'],
        ),
        const SizedBox(height: 12),
        Text(
          s.labsNoInterpretation,
          key: const ValueKey('labs-no-interpretation'),
          style: text.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        // One add action on the screen (R016): with no results it sits in
        // the first step, under the sentence that says what to type;
        // otherwise here, above the list.
        if (!empty) Align(alignment: Alignment.centerLeft, child: add),
        ValueListenableBuilder<bool>(
          valueListenable: _saved,
          builder: (context, saved, _) => !saved
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      s.saved,
                      key: const ValueKey('lab-saved'),
                      style: text.bodySmall,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        if (!_readFailed && _loaded && _groups.isNotEmpty) ...[
          Semantics(
            container: true,
            header: true,
            child: Text(s.labGroupsTitle, style: text.titleSmall),
          ),
          Text(
            s.labGroupsRule,
            key: const ValueKey('labs-group-rule'),
            style: text.bodySmall,
          ),
          for (final g in _groups)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey('lab-group-${g.rows.first.record.id}'),
                icon: const Icon(Icons.show_chart_outlined),
                label: Text(
                  s.labGroupLine(g.label, g.unit, g.specimen, g.length),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LabGroupScreen(group: g),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (_readFailed)
          ReadFailedNote(id: 'labs', onRetry: _retry)
        else if (!_loaded)
          const LoadingLine()
        else if (empty)
          FirstStep(
            key: const ValueKey('labs-empty'),
            text: s.labsFirstStep,
            action: add,
          ),
      ],
    );
  }
}

/// The add or correct form in a bottom sheet: fields scroll, Save and
/// Cancel stay in view (SheetFrame), and a refused save moves focus to the
/// field it is about (FieldFocus).
class _LabSheet extends StatefulWidget {
  const _LabSheet({required this.svc, required this.me, required this.form});

  final HeartbeatService svc;
  final String me;
  final _LabForm form;

  @override
  State<_LabSheet> createState() => _LabSheetState();
}

class _LabSheetState extends State<_LabSheet> {
  final _focus = FieldFocus();
  String? _errorCode;
  bool _busy = false;

  _LabForm get _f => widget.form;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  static const _moreFields = {
    'reportTime',
    'method',
    'refLow',
    'refHigh',
    'refUnit',
    'refPartition',
  };

  /// The field an error code is about, when the service names none.
  static String? _fieldOf(String code) => switch (code) {
    'LAB_ANALYTE_EMPTY' => 'analyte',
    'DATE_INVALID' || 'FUTURE_TIME' => 'date',
    'EMPTY' ||
    'NOT_A_NUMBER' ||
    'AMBIGUOUS_SEPARATOR' ||
    'OUT_OF_RANGE' ||
    'NOT_POSITIVE' ||
    'VALUE_HAS_COMPARATOR' ||
    'UNIT_IN_VALUE' ||
    'CENSORED_NEEDS_COMPARATOR' ||
    'CENSORED_NEEDS_NUMBER' ||
    'COMPARATOR_UNCLEAR' ||
    'LIMIT_HAS_SPACE' ||
    'TEXT_IS_A_NUMBER' ||
    'TEXT_IS_CENSORED' ||
    'TEXT_TOO_LONG' => 'value',
    _ => null,
  };

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    var saved = false;
    String? field;
    try {
      final target = _f.correcting;
      if (target == null) {
        await widget.svc.recordLab(profileId: widget.me, input: _f.input());
      } else {
        await widget.svc.correctLab(
          profileId: widget.me,
          targetId: target.id,
          input: _f.input(),
        );
      }
      saved = true;
    } on InputError catch (e) {
      _errorCode = e.code;
      field = e.field ?? _fieldOf(e.code);
    } on RecordValidationError catch (e) {
      _errorCode = e.code;
    } on StorageWriteRefused catch (e) {
      _errorCode = e.code;
    } catch (_) {
      _errorCode = 'SAVE_FAILED';
    } finally {
      if (mounted) {
        if (saved) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _busy = false;
            // An error in the collapsed section opens it, so the field it
            // is about can take focus.
            if (_moreFields.contains(field)) _f.moreOpen = true;
          });
          _focus.focusAfterFrame(this, field);
        }
      }
    }
  }

  Widget _field(
    TextEditingController c,
    String label,
    String key,
    String name, {
    String? helper,
    bool number = false,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: WholeLabelField(
      label: label,
      field: (labelText) => TextField(
        key: ValueKey(key),
        controller: c,
        focusNode: _focus[name],
        enabled: enabled,
        // Lab numbers may be negative (base excess -2): ask for a minus key.
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: labelText,
          helperText: helper,
          helperMaxLines: 20,
          border: const OutlineInputBorder(),
        ),
      ),
    ),
  );

  /// The line under "More from the report". Collapsed, it shows the report
  /// time itself (a value carried from the previous result is never hidden
  /// behind a count) and how many fields hold text.
  String _moreNote(S s, bool open) {
    final filled = _f.moreFilled;
    if (open || filled == 0) return s.labMoreHint;
    final rt = _f.reportTime.text.trim();
    return [
      if (rt.isNotEmpty) s.labMoreReportTime(rt),
      s.labMoreFilled(filled),
    ].join(' · ');
  }

  /// "More from the report": collapsed by default so the usual form stays
  /// short; opened by a tap, by a correction of a result that holds these
  /// details, or by an error about one of its fields.
  List<Widget> _moreSection(S s, TextTheme text) {
    final open = _f.moreOpen;
    final now = DateTime.now();
    final picks = [
      (s.presetNow, typedWall(now), true),
      ...TimePicks.recent(s, now: now).skip(1),
    ];
    return [
      Semantics(
        button: true,
        expanded: open,
        child: InkWell(
          key: const ValueKey('lab-more'),
          onTap: () => setState(() => _f.moreOpen = !open),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.labMoreTitle, style: text.titleSmall),
                        // Repaints when a carried report time is cleared
                        // by a new sample date or laboratory.
                        ListenableBuilder(
                          listenable: Listenable.merge(_f.more),
                          builder: (context, _) => Text(
                            _moreNote(s, open),
                            key: const ValueKey('lab-more-note'),
                            style: text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(open ? Icons.expand_less : Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (open) ...[
        const SizedBox(height: 8),
        _field(
          _f.reportTime,
          s.labReportTime,
          'lab-report-time',
          'reportTime',
          helper: s.labReportTimeHelp,
        ),
        TimePicks(
          keyPrefix: 'lab-report-time',
          controller: _f.reportTime,
          picks: picks,
          onPicked: () => setState(() {}),
        ),
        _field(
          _f.method,
          s.labMethod,
          'lab-method',
          'method',
          helper: s.labMethodHelp,
        ),
        Semantics(
          container: true,
          header: true,
          child: Text(s.labIntervalTitle, style: text.titleSmall),
        ),
        const SizedBox(height: 4),
        Text(
          s.labIntervalExplain,
          key: const ValueKey('lab-interval-explain'),
          style: text.bodySmall,
        ),
        const TermLink('reference_interval'),
        const SizedBox(height: 6),
        _field(
          _f.refLow,
          s.labIntervalLow,
          'lab-ref-low',
          'refLow',
          helper: s.labIntervalBoundHelp,
          number: true,
        ),
        _field(
          _f.refHigh,
          s.labIntervalHigh,
          'lab-ref-high',
          'refHigh',
          helper: s.labIntervalBoundHelp,
          number: true,
        ),
        _field(_f.refUnit, s.labIntervalUnit, 'lab-ref-unit', 'refUnit'),
        _field(
          _f.refPartition,
          s.labIntervalPartition,
          'lab-ref-partition',
          'refPartition',
          helper: s.labIntervalPartitionHelp,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final correcting = _f.correcting != null;
    return SheetFrame(
      key: const ValueKey('lab-form'),
      fields: [
        Semantics(
          container: true,
          header: true,
          child: Text(
            correcting ? s.labCorrectTitle : s.labAddTitle,
            style: text.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        _field(
          _f.analyte,
          s.labAnalyte,
          'lab-analyte',
          'analyte',
          helper: s.labAnalyteHelp,
        ),
        // How the value is printed (F004-S2): the field below changes with
        // it. Number is the default; nothing is guessed from the text.
        // One labelled group, so a screen reader names the question with
        // each choice (as conditions_screen's choices do).
        Semantics(
          key: const ValueKey('lab-kind-group'),
          container: true,
          label: s.labKindTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text(s.labKindTitle, style: text.labelLarge),
              ),
              const SizedBox(height: 6),
              Wrap(
                key: const ValueKey('lab-kind'),
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final k in LabValueKind.values)
                    ChoiceChip(
                      key: ValueKey('lab-kind-${k.code}'),
                      label: Text(s.labKind(k)),
                      selected: _f.kind == k,
                      onSelected: _f.notReported
                          ? null
                          : (_) => setState(() {
                              _f.kind = k;
                              _errorCode = null;
                            }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _field(
          _f.value,
          s.labValueLabel(_f.kind),
          'lab-value',
          'value',
          helper: s.labValueHelp(_f.kind),
          number: _f.kind == LabValueKind.number,
          enabled: !_f.notReported,
        ),
        CheckboxListTile(
          key: const ValueKey('lab-not-reported'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(s.labNotReported),
          value: _f.notReported,
          onChanged: (v) => setState(() => _f.notReported = v ?? false),
        ),
        _field(_f.unit, s.labUnit, 'lab-unit', 'unit', helper: s.labUnitHelp),
        _field(
          _f.date,
          s.labSampleDate,
          'lab-date',
          'date',
          helper: 'YYYY-MM-DD',
        ),
        _field(_f.specimen, s.labSpecimen, 'lab-specimen', 'specimen'),
        _field(_f.laboratory, s.labLaboratory, 'lab-laboratory', 'laboratory'),
        _field(_f.flag, s.labFlag, 'lab-flag', 'flag', helper: s.labFlagHelp),
        _field(
          _f.range,
          s.labRange,
          'lab-range',
          'range',
          helper: s.labRangeHelp,
        ),
        ..._moreSection(s, text),
        if (_errorCode != null)
          Semantics(
            liveRegion: true,
            child: Text(
              s.inputError(_errorCode!),
              key: const ValueKey('lab-error'),
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
      actions: [
        FilledButton(
          key: const ValueKey('lab-save'),
          onPressed: _busy ? null : _save,
          child: Text(correcting ? s.saveCorrection : s.save),
        ),
        TextButton(
          key: const ValueKey('lab-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}

class _LabTile extends StatelessWidget {
  const _LabTile({
    super.key,
    required this.record,
    required this.conflict,
    required this.onCorrect,
  });

  final HealthRecord record;
  final bool conflict;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final lab = record.lab!;
    final day = record.observedAt;
    final date = formatDay(day.year, day.month, day.day, displayDateOrder);
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(lab.analyteLabel, style: text.titleSmall)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    fmtValue(s, record),
                    textAlign: TextAlign.end,
                    style: text.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                '${s.labSampleDate}: $date',
                if (lab.specimen != null) lab.specimen!,
                if (lab.laboratory != null) lab.laboratory!,
                s.provenanceKind(record.provenance.kind),
              ].join(' · '),
              style: text.bodySmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (lab.sourceFlag != null)
                  StatusChip(
                    key: ValueKey('lab-flag-${record.id}'),
                    label: s.labPrintedFlag(lab.sourceFlag!),
                    tone: StatusTone.muted,
                  ),
                if (conflict)
                  StatusChip(
                    label: s.entryStatus(EntryStatus.conflict),
                    tone: StatusTone.warn,
                  ),
              ],
            ),
            Text(
              lab.referenceText == null
                  ? s.labNoRangePrinted
                  : s.labPrintedRange(lab.referenceText!),
              key: ValueKey('lab-range-${record.id}'),
              style: text.bodySmall,
            ),
            // What else the report printed (D-045): restated, never
            // compared with the value.
            for (final (i, line) in labReportLines(s, lab, fmtWhen).indexed)
              Text(
                line,
                key: ValueKey('lab-report-$i-${record.id}'),
                style: text.bodySmall,
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: ValueKey('lab-correct-${record.id}'),
                onPressed: onCorrect,
                icon: const Icon(Icons.edit_outlined),
                label: Text(s.amendAction(AmendReason.correction)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
