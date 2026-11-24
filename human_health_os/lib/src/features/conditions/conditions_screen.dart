import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../application/heartbeat_service.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../../navigation/destinations.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/record_area_screen.dart';
import '../../presentation/widgets/whole_label_field.dart';
import '../../presentation/widgets/sheet_parts.dart';

/// Conditions and symptoms (F009 slice 1): as the person names them, with
/// whether they are current, past or unsure and who they come from. A
/// self-report is not a confirmed diagnosis; nothing is coded, inferred,
/// confirmed or suggested.
class ConditionsScreen extends StatelessWidget {
  const ConditionsScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final svc = services.heartbeat;
    final me = services.self.id;
    return RecordAreaScreen<HealthRecord>(
      key: const ValueKey('screen-conditions'),
      area: DestinationId.conditions,
      id: 'cond',
      title: s.condTitle,
      what: s.condIntro,
      addLabel: s.condAdd,
      emptyText: s.condNone,
      load: () => svc.conditions(me),
      addSheet: (_) => _ConditionSheet(svc: svc, me: me),
      rowBuilder: (context, r, area) => RecordEntryRow(
        id: 'cond',
        entryId: r.id,
        line: s.condLine(r.details! as ConditionEntryDetails),
        onCorrect: () => area.openSheet(
          (_) => _ConditionSheet(svc: svc, me: me, correcting: r),
        ),
      ),
    );
  }
}

class _ConditionSheet extends StatefulWidget {
  const _ConditionSheet({required this.svc, required this.me, this.correcting});

  final HeartbeatService svc;
  final String me;

  /// The shown version being corrected; null for a new entry.
  final HealthRecord? correcting;

  @override
  State<_ConditionSheet> createState() => _ConditionSheetState();
}

class _ConditionSheetState extends State<_ConditionSheet> {
  final _name = TextEditingController();
  final _since = TextEditingController();
  final _focus = FieldFocus();
  var _nature = ConditionType.condition;
  // Not sure until the person says: a state they did not choose is never
  // recorded for them.
  var _time = ConditionTime.unsure;
  var _source = ConditionSource.selfReported;
  String? _error;
  String? _errorField;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final d = widget.correcting?.details;
    if (d is ConditionEntryDetails) {
      _name.text = d.name;
      _since.text = d.since ?? '';
      _nature = d.nature;
      _time = d.time;
      _source = d.source;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _since.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = S.of(context);
    setState(() => _busy = true);
    var saved = false;
    try {
      await widget.svc.recordCondition(
        profileId: widget.me,
        name: _name.text,
        nature: _nature,
        time: _time,
        source: _source,
        since: _since.text,
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
    String f, {
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Space.m),
    child: WholeLabelField(
      label: label,
      field: (labelText) => TextField(
        key: ValueKey(key),
        controller: c,
        focusNode: _focus[f],
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) {
          if (_error != null) setState(() => _error = _errorField = null);
        },
        decoration: InputDecoration(
          labelText: labelText,
          helperText: helper,
          helperMaxLines: 20,
          errorText: _errorField == f ? _error : null,
          errorMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      ),
    ),
  );

  Widget _choice<T extends Enum>(
    String name,
    String label,
    List<T> values,
    T value,
    String Function(T) word,
    ValueChanged<T> onPick,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: Space.l),
    child: Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final v in values)
                ChoiceChip(
                  key: ValueKey('cond-$name-${v.name}'),
                  label: Text(word(v)),
                  selected: v == value,
                  onSelected: (_) => setState(() => onPick(v)),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SheetFrame(
      fields: [
        Semantics(
          header: true,
          child: Text(
            widget.correcting == null ? s.condAdd : s.condCorrectTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: Space.l),
        _field('cond-name', s.condName, _name, 'name'),
        _choice(
          'nature',
          s.condAskNature,
          ConditionType.values,
          _nature,
          s.condNature,
          (v) => _nature = v,
        ),
        _choice(
          'time',
          s.condAskTime,
          ConditionTime.values,
          _time,
          s.condTime,
          (v) => _time = v,
        ),
        _choice(
          'source',
          s.condAskSource,
          ConditionSource.values,
          _source,
          s.condSource,
          (v) => _source = v,
        ),
        _field(
          'cond-since',
          s.condSince,
          _since,
          'since',
          helper: s.condSinceHelp,
        ),
        if (_error != null && _errorField != 'name' && _errorField != 'since')
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const ValueKey('cond-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
      actions: [
        FilledButton(
          key: const ValueKey('cond-save'),
          onPressed: _busy ? null : _save,
          child: Text(s.save),
        ),
        TextButton(
          key: const ValueKey('cond-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}
