import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../application/heartbeat_service.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../../presentation/widgets/record_area_screen.dart';
import '../../presentation/widgets/sheet_parts.dart';
import '../../navigation/destinations.dart';
import '../timeline/timeline_screen.dart' show fmtWhen;

/// Activity (F007 slice 6): walks, workouts and steps typed by hand. Minutes
/// and steps are whole numbers or not given; nothing is estimated (no
/// calories), added up, rated or merged with device data.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final svc = services.heartbeat;
    final me = services.self.id;
    return RecordAreaScreen<HealthRecord>(
      key: const ValueKey('screen-activity'),
      area: DestinationId.activity,
      id: 'act',
      title: s.actTitle,
      what: s.actIntro,
      addLabel: s.actAdd,
      emptyText: s.actNone,
      load: () => svc.activities(me),
      addSheet: (_) => _ActivitySheet(svc: svc, me: me),
      rowBuilder: (context, r, area) => RecordEntryRow(
        id: 'act',
        entryId: r.id,
        line: s.actLine(r.details! as ActivityEntryDetails),
        when: fmtWhen(r.observedAt),
        onCorrect: () => area.openSheet(
          (_) => _ActivitySheet(svc: svc, me: me, correcting: r),
        ),
      ),
    );
  }
}

class _ActivitySheet extends StatefulWidget {
  const _ActivitySheet({required this.svc, required this.me, this.correcting});

  final HeartbeatService svc;
  final String me;

  /// The shown version being corrected; null for a new entry.
  final HealthRecord? correcting;

  @override
  State<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<_ActivitySheet> {
  final _what = TextEditingController();
  final _minutes = TextEditingController();
  final _steps = TextEditingController();
  final _when = TextEditingController();
  final _focus = FieldFocus();
  String? _error;
  String? _errorField;
  bool _busy = false;

  /// The time the sheet opened with; left as is, the entry keeps its own
  /// time (to the second), not this minute.
  String? _shownWhen;

  @override
  void initState() {
    super.initState();
    final d = widget.correcting?.details;
    if (d is ActivityEntryDetails) {
      _what.text = d.what;
      _minutes.text = d.minutes?.toString() ?? '';
      _steps.text = d.steps?.toString() ?? '';
      _when.text = _shownWhen = typedLocal(widget.correcting!.observedAt);
    }
  }

  @override
  void dispose() {
    _what.dispose();
    _minutes.dispose();
    _steps.dispose();
    _when.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = S.of(context);
    setState(() => _busy = true);
    var saved = false;
    try {
      await widget.svc.recordActivity(
        profileId: widget.me,
        what: _what.text,
        minutes: _minutes.text,
        steps: _steps.text,
        when: _when.text == _shownWhen ? '' : _when.text,
        correcting: widget.correcting?.id,
      );
      saved = true;
    } on InputError catch (e) {
      _error = s.inputError(e.code);
      _errorField = e.field;
    } finally {
      if (mounted) {
        if (saved) {
          Navigator.of(context).pop(true);
        } else {
          setState(() => _busy = false);
          _focus.focusAfterFrame(this, _errorField);
        }
      }
    }
  }

  Widget _field(
    String key,
    String label,
    TextEditingController c,
    String field, {
    String? help,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: ValueKey(key),
      controller: c,
      focusNode: _focus[field],
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      onChanged: (_) {
        if (_error != null) {
          setState(() => _error = _errorField = null);
        }
      },
      textCapitalization: keyboard == null
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        helperText: _errorField == field ? null : help,
        helperMaxLines: 3,
        errorText: _errorField == field ? _error : null,
        errorMaxLines: 4,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    return SheetFrame(
      fields: [
        Semantics(
          header: true,
          child: Text(
            widget.correcting == null ? s.actAdd : s.actCorrectTitle,
            style: text.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        _field('act-what', s.actWhat, _what, 'what'),
        _field(
          'act-minutes',
          s.actMinutes,
          _minutes,
          'minutes',
          keyboard: TextInputType.number,
        ),
        _field(
          'act-steps',
          s.actSteps,
          _steps,
          'steps',
          keyboard: TextInputType.number,
        ),
        _field(
          'act-when',
          s.foodWhen,
          _when,
          'when',
          help: s.foodWhenHelp,
          keyboard: TextInputType.datetime,
        ),
        TimePicks(
          keyPrefix: 'act-when',
          controller: _when,
          picks: TimePicks.recent(s),
          onPicked: () => setState(() => _error = _errorField = null),
        ),
        // An error without a field of its own is said here; one on a
        // field is shown (and read) on that field only.
        if (_error != null &&
            !const {'what', 'minutes', 'steps', 'when'}.contains(_errorField))
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const ValueKey('act-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
      ],
      actions: [
        FilledButton(
          key: const ValueKey('act-save'),
          onPressed: _busy ? null : _save,
          child: Text(s.save),
        ),
        TextButton(
          key: const ValueKey('act-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}
