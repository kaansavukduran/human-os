import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/appearance_scope.dart';
import '../../domain/guide/glossary.dart';
import '../../domain/settings/appearance.dart';
import '../../presentation/widgets/number_pad.dart';
import '../../presentation/widgets/sheet_parts.dart' show FieldFocus;
import '../guide/glossary_screen.dart';
import '../trends/trend_screen.dart';
import '../../application/heartbeat_service.dart';
import '../../domain/ports/health_repository.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../../navigation/destination_switch.dart';
import '../../navigation/destinations.dart';
import '../measurements/measurement_format.dart';
import '../timeline/timeline_screen.dart' show fmtWhen;

/// Measurements typed by hand (ladder F007): a quiet grid of tiles that show
/// the latest value of each kind, and one entry sheet per kind. Each save is
/// one record, kept exactly as typed with its time and source; nothing is
/// averaged, derived or judged, and a value that does not exist is named,
/// never drawn as 0. The history of each kind lives on the Timeline.
class MeasurementsCard extends StatefulWidget {
  const MeasurementsCard({super.key, required this.services});

  final AppServices services;

  /// In the order shown.
  static const kinds = [
    RecordKind.bloodPressure,
    RecordKind.restingHeartRate,
    RecordKind.bodyTemperature,
    RecordKind.oxygenSaturation,
    RecordKind.respiratoryRate,
    RecordKind.capillaryGlucose,
    RecordKind.waistCircumference,
    RecordKind.height,
    RecordKind.bodyFatPercentage,
  ];

  @override
  State<MeasurementsCard> createState() => _MeasurementsCardState();
}

class _MeasurementsCardState extends State<MeasurementsCard> {
  Map<RecordKind, List<TimelineEntry>> _entries = const {};

  HeartbeatService get _svc => widget.services.heartbeat;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final me = widget.services.self.id;
    final next = {
      for (final k in MeasurementsCard.kinds)
        k: await _svc.measurementTimeline(me, k),
    };
    if (mounted) setState(() => _entries = next);
  }

  Future<void> _add(RecordKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = S.of(context);
    final go = DestinationSwitch.maybeOf(context);
    // The colour a snack bar action has on the snack bar's own surface.
    final actionColor = Theme.of(context).colorScheme.inversePrimary;
    // A screen reader (or switch access) needs time to reach the button: the
    // snack bar then stays until it is used or closed (WCAG 2.2.1). The
    // button stays in the content, not in SnackBar.action, so the words wrap
    // at 2x text on a 320 dp phone.
    final accessible = MediaQuery.accessibleNavigationOf(context);
    widget.services.checkpointSaved?.value = null;
    final saved = await showModalBottomSheet<HealthRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Typed numbers are never lost to a stray swipe or tap outside: the
      // sheet closes with Save or Cancel.
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _EntrySheet(services: widget.services, kind: kind),
    );
    final checkpoint = widget.services.checkpointSaved?.value;
    if (saved == null) {
      // A backup may have been made for an entry that was then not saved:
      // the person is told where it is.
      if (checkpoint != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(s.checkpointKept(checkpoint)),
            duration: const Duration(seconds: 12),
            showCloseIcon: true,
          ),
        );
      }
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The value is read back with its unit (D-048): "Saved: 5,4
            // mmol/L", so a unit chosen out of sight is seen at once; a
            // screen reader hears the unit in words.
            Semantics(
              liveRegion: true,
              label: checkpoint == null
                  ? s.savedValue(spokenMeasurement(s, saved))
                  : s.checkpointSaved(
                      checkpoint,
                      value: spokenMeasurement(s, saved),
                    ),
              child: ExcludeSemantics(
                child: Text(
                  checkpoint == null
                      ? s.savedValue(measurementValue(s, saved))
                      : s.checkpointSaved(
                          checkpoint,
                          value: measurementValue(s, saved),
                        ),
                  key: const ValueKey('measure-saved'),
                ),
              ),
            ),
            // Under the text, not beside it, so the words wrap at large
            // text on a narrow phone instead of overflowing.
            if (go != null)
              TextButton(
                key: const ValueKey('measure-show-timeline'),
                style: TextButton.styleFrom(
                  foregroundColor: actionColor,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  go(DestinationId.timeline);
                },
                child: Text(s.showOnTimeline),
              ),
          ],
        ),
        // Long enough to reach the action; it closes on its own, unless
        // navigation is accessible and there is a button to reach.
        duration: Duration(
          seconds: checkpoint != null
              ? 12
              : go != null
              ? 6
              : 3,
        ),
        persist: accessible && go != null,
        showCloseIcon: checkpoint != null || (accessible && go != null),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final prefs =
        AppearanceScope.watch(context, AppearanceAspect.tiles) ??
        const AppearanceSettings();
    final codes = prefs.visible([
      for (final k in MeasurementsCard.kinds) k.code,
    ]);
    final shown = [
      for (final c in codes)
        MeasurementsCard.kinds.firstWhere((k) => k.code == c),
    ];
    return Column(
      key: const ValueKey('measurements-card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(s.measurementsTitle, style: text.titleMedium),
        ),
        const SizedBox(height: 4),
        Text(
          s.measurementsNote,
          key: const ValueKey('measurements-note'),
          style: text.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Text(
            s.allTilesHidden,
            key: const ValueKey('measurements-all-hidden'),
            style: text.bodyMedium,
          ),
        LayoutBuilder(
          builder: (context, box) {
            final columns = tileColumns(
              box.maxWidth,
              MediaQuery.textScalerOf(context).scale(14) / 14,
            );
            const gap = 12.0;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final k in shown)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: width,
                      maxWidth: width,
                      minHeight: 96,
                    ),
                    child: _Tile(
                      kind: k,
                      entries: _entries[k] ?? const [],
                      onAdd: () => _add(k),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Tile columns for [width] at [textScale]: the width is measured in text
/// that size, so large text on a narrow phone gets one tile per row
/// (G-49) and the value is never squeezed into a sliver.
int tileColumns(double width, double textScale) {
  final w = width / (textScale <= 0 ? 1 : textScale);
  if (w >= 720) return 4;
  if (w >= 480) return 3;
  if (w >= 260) return 2;
  return 1;
}

/// The latest value of one kind and a way to add another.
class _Tile extends StatelessWidget {
  const _Tile({required this.kind, required this.entries, required this.onAdd});

  final RecordKind kind;
  final List<TimelineEntry> entries;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final entry = latestWithValue(entries);
    final conflict = entry?.status == EntryStatus.conflict;
    // A newer "I did not measure this" (D-047) is said in words under the
    // latest value, never as a number and never as zero.
    final newest = entries.firstOrNull;
    final missed =
        newest != null &&
            newest != entry &&
            newest.status == EntryStatus.current &&
            newest.shown.valueStatus == ValueStatus.notMeasured
        ? s.notMeasuredOn(fmtWhen(newest.shown.observedAt))
        : null;
    final latest = conflict ? null : entry?.heads.first;
    final code = kind.code;
    final String value;
    final String spoken;
    String? caption;
    if (conflict) {
      value = s.versionsDisagree;
      spoken = '${s.recordKind(kind)}: ${s.versionsDisagree}';
    } else if (latest == null) {
      value = s.measurementNotYet;
      spoken = '${s.recordKind(kind)}: ${s.measurementNotYet}';
    } else {
      value = measurementValue(s, latest);
      caption = whenCaption(s, latest, fmtWhen);
      spoken = s.spokenLatest(
        s.recordKind(kind),
        spokenMeasurement(s, latest),
        fmtWhen(latest.observedAt),
        s.provenanceKind(latest.provenance.kind),
        saved: savedWhenDifferent(latest, fmtWhen),
      );
    }
    return Semantics(
      key: ValueKey('measure-latest-$code'),
      label: [spoken, ?missed, s.addMeasurement].join('. '),
      button: true,
      excludeSemantics: true,
      onTap: onAdd,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          key: ValueKey('measure-tile-$code'),
          borderRadius: BorderRadius.circular(12),
          onTap: onAdd,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        s.recordKind(kind),
                        style: text.bodyMedium?.copyWith(color: scheme.outline),
                      ),
                    ),
                    Icon(Icons.add, size: 20, color: scheme.primary),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  key: ValueKey('measure-latest-value-$code'),
                  style: latest == null
                      ? text.bodyMedium?.copyWith(color: scheme.outline)
                      : text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: text.bodyMedium?.copyWith(color: scheme.outline),
                  ),
                ],
                if (missed != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    missed,
                    key: ValueKey('measure-not-measured-$code'),
                    style: text.bodyMedium?.copyWith(color: scheme.outline),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One kind, one purpose: the value (or the two blood pressure numbers),
/// Save, and under "More details" the time and a note.
class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.services, required this.kind});

  final AppServices services;
  final RecordKind kind;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final _value = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _context = TextEditingController();
  final _when = TextEditingController();
  final _more = ExpansibleController();
  final _focus = FieldFocus();
  late TextEditingController _active = _value;

  /// The unit chosen for a kind with more than one (capillary glucose:
  /// mg/dL or mmol/L, D-048); starts as the unit of the person's newest
  /// reading of this kind, or none.
  String? _unit;

  /// Before or after eating, as chosen for a capillary glucose; optional.
  GlucoseTiming? _timing;
  bool? _padChoice;

  bool get _pad =>
      _padChoice ??
      (AppearanceScope.watch(context, AppearanceAspect.pad)?.padOpen ?? false);
  String? _errorCode;
  String? _errorField;
  bool _busy = false;

  /// "I did not measure this" (D-047): the value fields are hidden (what
  /// was typed comes back on unticking) and nothing numeric is sent.
  bool _notMeasured = false;

  /// Notes the person typed on earlier measurements, newest first.
  List<String> _notes = const [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
    if (widget.kind.units.length > 1) _loadUnit();
  }

  /// The unit of the newest reading of this kind, so a person whose meter
  /// shows mmol/L does not choose it every time. Shown chosen; changeable.
  Future<void> _loadUnit() async {
    final entries = await widget.services.heartbeat.measurementTimeline(
      widget.services.self.id,
      widget.kind,
    );
    final unit = latestWithValue(entries)?.shown.quantity?.unit;
    if (mounted && _unit == null && unit != null) {
      setState(() => _unit = unit);
    }
  }

  Future<void> _loadNotes() async {
    final records = await widget.services.heartbeat.repository.records(
      widget.services.self.id,
    );
    final notes = previousNotes(records);
    if (mounted) setState(() => _notes = notes);
  }

  @override
  void dispose() {
    _value.dispose();
    _systolic.dispose();
    _diastolic.dispose();
    _context.dispose();
    _when.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errorCode = null;
      _errorField = null;
    });
    try {
      final saved = await widget.services.heartbeat.recordMeasurement(
        profileId: widget.services.self.id,
        kind: widget.kind,
        input: MeasurementInput(
          value: _notMeasured ? '' : _value.text,
          systolic: _notMeasured ? '' : _systolic.text,
          diastolic: _notMeasured ? '' : _diastolic.text,
          context: _context.text,
          when: _when.text,
          notMeasured: _notMeasured,
          unit: _notMeasured ? '' : (_unit ?? ''),
          glucoseTiming: _notMeasured ? null : _timing,
        ),
      );
      if (mounted) Navigator.of(context).pop(saved);
      return;
    } on InputError catch (e) {
      _errorCode = e.code;
      _errorField = e.field;
    } on RecordValidationError catch (e) {
      _errorCode = e.code;
    } on StorageWriteRefused catch (e) {
      _errorCode = e.code;
    } catch (_) {
      // Storage/IO failure: memory is only updated after a write, so
      // nothing is shown as saved.
      _errorCode = 'SAVE_FAILED';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (_errorField == 'when' || _errorField == 'context') {
      _more.expand();
    }
    // The field the error is about takes focus and comes into view.
    _focus.focusAfterFrame(this, _errorField);
  }

  String? _errorFor(S s, String field) =>
      _errorCode != null && _errorField == field
      ? s.inputError(_errorCode!)
      : null;

  Widget _field(
    S s,
    TextEditingController c,
    String label,
    String key,
    String field, {
    bool number = true,
    String? hint,
    bool autofocus = false,
    bool last = true,
    String? suffix,
    String? spokenSuffix,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Focus(
      onFocusChange: (has) {
        if (has) setState(() => _active = c);
      },
      child: TextField(
        key: ValueKey(key),
        controller: c,
        focusNode: _focus[field],
        autofocus: autofocus,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onSubmitted: last ? (_) => _busy ? null : _save() : null,
        inputFormatters: field == 'context'
            ? const [ContextLengthFormatter()]
            : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          helperMaxLines: 3,
          errorText: _errorFor(s, field),
          errorMaxLines: 3,
          // The chosen unit sits inside the field (D-048), beside the
          // number, so it is seen while typing even when the chips are
          // under the keyboard.
          suffix: suffix == null
              ? null
              : Text(
                  suffix,
                  key: ValueKey('$key-unit'),
                  semanticsLabel: spokenSuffix,
                ),
        ),
      ),
    ),
  );

  /// The unit chips of a kind with more than one unit (D-048): none is
  /// guessed from the number; the error, if any, shows under them.
  Widget _unitChoice(S s, RecordKind kind) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final error = _errorFor(s, 'unit');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The label and the chips are one group to a screen reader; each
          // unit is spoken in words, not letter by letter.
          Semantics(
            key: const ValueKey('measure-unit-group'),
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
                    for (final (i, u) in kind.units.indexed)
                      ChoiceChip(
                        key: ValueKey('measure-unit-$u'),
                        focusNode: i == 0 ? _focus['unit'] : null,
                        label: Text(s.unit(u), semanticsLabel: s.spokenUnit(u)),
                        selected: _unit == u,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _unit = u),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error ?? s.glucoseUnitHelp,
            key: error == null ? null : const ValueKey('measure-unit-error'),
            style: text.bodySmall?.copyWith(
              color: error == null ? scheme.outline : scheme.error,
            ),
          ),
        ],
      ),
    );
  }

  /// Meal timing of a capillary glucose, as chosen (optional; tapping the
  /// chosen one again clears it). Never inferred from the time.
  Widget _timingChoice(S s) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.glucoseTimingLabel, style: text.bodyMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in GlucoseTiming.values)
                ChoiceChip(
                  key: ValueKey('measure-timing-${t.code}'),
                  label: Text(s.glucoseTiming(t)),
                  selected: _timing == t,
                  onSelected: _busy
                      ? null
                      : (on) => setState(() => _timing = on ? t : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _stamp(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _presets(S s) {
    final now = DateTime.now();
    final today8 = DateTime(now.year, now.month, now.day, 8);
    final yesterday20 = DateTime(now.year, now.month, now.day - 1, 20);
    final options = <(String, String?, bool)>[
      (s.presetNow, '', true),
      (s.presetHourAgo, _stamp(now.subtract(const Duration(hours: 1))), true),
      (s.presetMorning, _stamp(today8), today8.isBefore(now)),
      (s.presetYesterdayEvening, _stamp(yesterday20), true),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, value, enabled) in options)
            ActionChip(
              key: ValueKey('measure-preset-$label'),
              label: Text(label),
              onPressed: enabled
                  ? () => setState(() => _when.text = value ?? '')
                  : null,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final kind = widget.kind;
    final hint = s.measurementHint(kind);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          key: ValueKey('measure-sheet-${kind.code}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(s.recordKind(kind), style: text.titleMedium),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('measure-trend'),
                icon: const Icon(Icons.show_chart_outlined),
                label: Text(s.seeOverTime),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TrendScreen(services: widget.services, kind: kind),
                  ),
                ),
              ),
            ),
            if (glossaryForKind(kind.code) case final entry?)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('measure-about'),
                  icon: const Icon(Icons.info_outline),
                  label: Text(s.aboutMeasurement),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GlossaryEntryScreen(entry: entry),
                    ),
                  ),
                ),
              ),
            if (notMeasuredKinds.contains(kind))
              CheckboxListTile(
                key: const ValueKey('measure-not-measured'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _notMeasured,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _notMeasured = v ?? false;
                        _errorCode = null;
                        _errorField = null;
                      }),
                title: Text(s.notMeasuredToggle),
                subtitle: _notMeasured ? Text(s.notMeasuredHelp) : null,
              ),
            if (_notMeasured)
              const SizedBox.shrink()
            else if (kind.isStructured) ...[
              _field(
                s,
                _systolic,
                s.systolicField,
                'measure-systolic',
                'systolic',
                autofocus: true,
                last: false,
              ),
              _field(
                s,
                _diastolic,
                s.diastolicField,
                'measure-diastolic',
                'diastolic',
              ),
            ] else
              _field(
                s,
                _value,
                s.measurementField(kind),
                'measure-value',
                'value',
                hint: hint,
                autofocus: true,
                suffix: kind.units.length > 1
                    ? (_unit == null ? s.unitNotChosen : s.unit(_unit!))
                    : null,
                spokenSuffix: kind.units.length > 1
                    ? (_unit == null ? s.unitNotChosen : s.spokenUnit(_unit!))
                    : null,
              ),
            if (!_notMeasured && kind.units.length > 1) _unitChoice(s, kind),
            if (!_notMeasured && kind == RecordKind.capillaryGlucose)
              _timingChoice(s),
            if (!_notMeasured)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('measure-pad-toggle'),
                  onPressed: () => setState(() => _padChoice = !_pad),
                  child: Text(_pad ? s.numberPadHide : s.numberPadShow),
                ),
              ),
            if (_pad && !_notMeasured)
              Padding(
                key: const ValueKey('measure-pad'),
                padding: const EdgeInsets.only(top: 8),
                child: NumberPad(
                  target: () => _active,
                  onChanged: () => setState(() {}),
                ),
              ),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('measure-more'),
                controller: _more,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  s.moreDetails,
                  style: text.bodyMedium?.copyWith(color: scheme.primary),
                ),
                children: [
                  _presets(s),
                  _field(
                    s,
                    _when,
                    s.whenField,
                    'measure-when',
                    'when',
                    number: false,
                    hint: s.whenHint,
                  ),
                  _field(
                    s,
                    _context,
                    s.contextField,
                    'measure-context',
                    'context',
                    number: false,
                  ),
                  if (_notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.yourNotes, style: text.bodyMedium),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < _notes.length; i++)
                                ActionChip(
                                  key: ValueKey('measure-note-$i'),
                                  label: Text(_notes[i]),
                                  onPressed: () => setState(() {
                                    _context.text = _notes[i];
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_errorCode != null && _errorField == null) ...[
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Text(
                  s.inputError(_errorCode!),
                  key: const ValueKey('measure-error'),
                  style: text.bodyMedium?.copyWith(color: scheme.error),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Stacked, full width: at large text a side-by-side pair squeezed
            // the Save label into a narrow strip.
            FilledButton(
              key: const ValueKey('measure-save'),
              onPressed: _busy ? null : _save,
              child: Text(s.saveMeasurement),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('measure-cancel'),
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(s.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
