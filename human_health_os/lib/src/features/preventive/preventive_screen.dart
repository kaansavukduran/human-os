import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../application/heartbeat_service.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../../navigation/destinations.dart';
import '../../presentation/widgets/record_area_screen.dart';
import '../../presentation/widgets/sheet_parts.dart';
import '../../presentation/widgets/whole_chip.dart';

/// Preventive items (F009 slice 2): vaccinations, screenings and check-ups
/// as the person names them, done, planned or unsure, with who they come
/// from. Planned is never done; no screening result is kept (screening is
/// not diagnosis); nothing is recommended, scheduled, due or reminded.
class PreventiveScreen extends StatelessWidget {
  const PreventiveScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final svc = services.heartbeat;
    final me = services.self.id;
    return RecordAreaScreen<HealthRecord>(
      key: const ValueKey('screen-preventive'),
      area: DestinationId.preventive,
      id: 'prev',
      title: s.prevTitle,
      what: s.prevIntro,
      addLabel: s.prevAdd,
      emptyText: s.prevNone,
      load: () => svc.preventives(me),
      addSheet: (_) => _PreventiveSheet(svc: svc, me: me),
      rowBuilder: (context, r, area) => RecordEntryRow(
        id: 'prev',
        entryId: r.id,
        line: s.prevLine(r.details! as PreventiveEntryDetails),
        onCorrect: () => area.openSheet(
          (_) => _PreventiveSheet(svc: svc, me: me, correcting: r),
        ),
      ),
    );
  }
}

class _PreventiveSheet extends StatefulWidget {
  const _PreventiveSheet({
    required this.svc,
    required this.me,
    this.correcting,
  });

  final HeartbeatService svc;
  final String me;

  /// The shown version being corrected; null for a new entry.
  final HealthRecord? correcting;

  @override
  State<_PreventiveSheet> createState() => _PreventiveSheetState();
}

class _PreventiveSheetState extends State<_PreventiveSheet> {
  final _name = TextEditingController();
  final _when = TextEditingController();
  final _focus = FieldFocus();
  // Nothing is chosen for the person: the type starts at "other".
  var _nature = PreventiveType.other;
  // Not sure until the person says: "done" is never picked for them, and a
  // planned item never reads as done.
  var _status = PreventiveStatus.unsure;
  var _source = ConditionSource.selfReported;
  String? _error;
  String? _errorField;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final d = widget.correcting?.details;
    if (d is PreventiveEntryDetails) {
      _name.text = d.name;
      _when.text = d.when ?? '';
      _nature = d.nature;
      _status = d.status;
      _source = d.source;
    }
  }

  @override
  void dispose() {
    _name.dispose();
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
      await widget.svc.recordPreventive(
        profileId: widget.me,
        name: _name.text,
        nature: _nature,
        status: _status,
        source: _source,
        when: _when.text,
        correcting: widget.correcting?.id,
      );
      saved = true;
    } on InputError catch (e) {
      _error = s.inputError(e.code);
      _errorField = e.field;
    } on Object {
      // A storage failure is said in words; nothing was written.
      _error = s.saveFailed;
      _errorField = null;
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

  Widget _field(String key, String label, TextEditingController c, String f) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          key: ValueKey(key),
          controller: c,
          focusNode: _focus[f],
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_error != null) setState(() => _error = _errorField = null);
          },
          decoration: InputDecoration(
            labelText: label,
            errorText: _errorField == f ? _error : null,
            errorMaxLines: 4,
            border: const OutlineInputBorder(),
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
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Text(label)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final v in values)
                WholeChip.choice(
                  key: ValueKey('prev-$name-${v.name}'),
                  label: word(v),
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
            widget.correcting == null ? s.prevAdd : s.prevCorrectTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        _field('prev-name', s.prevName, _name, 'name'),
        _choice(
          'nature',
          s.prevNatureLabel,
          PreventiveType.values,
          _nature,
          s.prevNature,
          (v) => _nature = v,
        ),
        _choice(
          'status',
          s.prevStatusLabel,
          PreventiveStatus.values,
          _status,
          s.prevStatus,
          (v) => _status = v,
        ),
        _choice(
          'source',
          s.prevSourceLabel,
          ConditionSource.values,
          _source,
          s.condSource,
          (v) => _source = v,
        ),
        _field('prev-when', s.prevWhen, _when, 'when'),
        if (_error != null && _errorField != 'name' && _errorField != 'when')
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const ValueKey('prev-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
      actions: [
        FilledButton(
          key: const ValueKey('prev-save'),
          onPressed: _busy ? null : _save,
          child: Text(s.save),
        ),
        TextButton(
          key: const ValueKey('prev-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}
