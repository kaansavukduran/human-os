import 'package:flutter/material.dart';

import '../../domain/records/health_record.dart' show AmendReason;
import '../../l10n/strings.dart';
import '../../navigation/destinations.dart';
import 'area_intro.dart';
import 'entry_list.dart';
import 'first_step.dart';
import 'loading_line.dart';
import 'read_failed_note.dart';

/// What a row can ask of the area it is shown in.
abstract interface class RecordArea {
  /// Opens [sheet] in a bottom sheet; when it closes with `true` (saved),
  /// the entries are read again.
  Future<void> openSheet(WidgetBuilder sheet);

  /// Reads the entries again.
  Future<void> reload();
}

/// One scaffold for the record areas (U033): the area's introduction, its
/// one Add action, then its entries as lazy slivers. While reading it says
/// so (LoadingLine); a failed read is said in words with Try again
/// (ReadFailedNote); with no entries the first step is the only empty
/// state: Aion, one sentence and the Add action inside it. With entries the
/// Add action sits above the list; it is one element in both places, so it
/// keeps keyboard focus after the first save. Until the first read is done
/// there is no Add action.
///
/// Keys, from [id]: `<id>-add`, `<id>-empty`, `<id>-none` (the sentence),
/// `<id>-read-failed` and `<id>-try-again`. The screen key is [key].
class RecordAreaScreen<T> extends StatefulWidget {
  const RecordAreaScreen({
    super.key,
    required this.area,
    required this.id,
    required this.title,
    required this.what,
    required this.addLabel,
    required this.emptyText,
    required this.load,
    required this.addSheet,
    required this.rowBuilder,
  });

  final DestinationId area;

  /// The key prefix shared by the area's widgets (`doc`, `cond`, …).
  final String id;
  final String title;
  final String what;
  final String addLabel;

  /// The first step's one sentence when there are no entries.
  final String emptyText;

  /// Reads the entries, newest first as the area wants them shown.
  final Future<List<T>> Function() load;

  /// The add sheet; it pops `true` when it saved.
  final WidgetBuilder addSheet;

  final Widget Function(BuildContext context, T entry, RecordArea area)
  rowBuilder;

  @override
  State<RecordAreaScreen<T>> createState() => _RecordAreaScreenState<T>();
}

class _RecordAreaScreenState<T> extends State<RecordAreaScreen<T>>
    implements RecordArea {
  List<T>? _entries;
  bool _readFailed = false;

  /// Keeps the one Add element (and its focus) when it moves from the first
  /// step to above the list after the first save (R023).
  final _addKey = GlobalKey(debugLabel: 'record-area-add');

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> reload() async {
    try {
      final entries = await widget.load();
      if (mounted) {
        setState(() {
          _entries = entries;
          _readFailed = false;
        });
      }
    } on Object {
      // Said in words with Try again, never a spinner forever (AIONIA v1.2).
      if (mounted) setState(() => _readFailed = true);
    }
  }

  void _retry() {
    setState(() => _readFailed = false);
    reload();
  }

  @override
  Future<void> openSheet(WidgetBuilder sheet) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: sheet,
    );
    if (saved == true) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final entries = _entries;
    final shown = _readFailed ? null : entries;
    final empty = !_readFailed && entries != null && entries.isEmpty;
    final add = KeyedSubtree(
      key: _addKey,
      child: FilledButton.icon(
        key: ValueKey('${w.id}-add'),
        onPressed: () => openSheet(w.addSheet),
        icon: const Icon(Icons.add),
        label: Text(w.addLabel),
      ),
    );
    return EntryList(
      itemCount: shown?.length ?? 0,
      itemBuilder: (context, i) => w.rowBuilder(context, shown![i], this),
      header: [
        AreaIntro(area: w.area, title: w.title, what: w.what),
        const SizedBox(height: 16),
        // One Add action on the screen: in the first step when there is
        // nothing yet, otherwise here, above the list. Not shown until the
        // first read is done, so it never jumps from here into the first
        // step (R023).
        if (entries != null && !empty) ...[
          Align(alignment: Alignment.centerLeft, child: add),
          const SizedBox(height: 16),
        ],
        if (_readFailed)
          ReadFailedNote(id: w.id, onRetry: _retry)
        else if (entries == null)
          const LoadingLine()
        else if (empty)
          FirstStep(
            key: ValueKey('${w.id}-empty'),
            text: w.emptyText,
            textKey: ValueKey('${w.id}-none'),
            action: add,
          ),
      ],
    );
  }
}

/// A record area's entry: its line as typed, an optional when line, and
/// Correct under the text, so a narrow window or large text never squeezes
/// the entry into a thin column. Keys: `<id>-entry-<entryId>` and
/// `<id>-correct-<entryId>`.
class RecordEntryRow extends StatelessWidget {
  const RecordEntryRow({
    super.key,
    required this.id,
    required this.entryId,
    required this.line,
    this.when,
    required this.onCorrect,
  });

  final String id;
  final String entryId;
  final String line;
  final String? when;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final when = this.when;
    final correct = TextButton(
      key: ValueKey('$id-correct-$entryId'),
      onPressed: onCorrect,
      child: Text(s.amendAction(AmendReason.correction)),
    );
    return Card(
      key: ValueKey('$id-entry-$entryId'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(line),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (when != null)
              Text(
                when,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            correct,
          ],
        ),
      ),
    );
  }
}
