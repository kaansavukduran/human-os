import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../application/heartbeat_service.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/record_area_screen.dart';
import '../../presentation/widgets/sheet_parts.dart';
import '../../presentation/widgets/whole_label_field.dart';
import '../../navigation/destinations.dart';
import '../timeline/timeline_screen.dart' show fmtWhen;
import '../../presentation/widgets/whole_chip.dart';

/// Medicines and supplements (F008): what the person uses, how it is meant
/// to be taken, and each dose they record as taken or skipped. Kept as
/// typed. A plan is never counted as a dose; nothing is checked or advised.
class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  HeartbeatService get _svc => widget.services.heartbeat;
  String get _me => widget.services.self.id;

  bool _busy = false;

  /// One change at a time; a refused change (a double tap on an older view,
  /// an item gone) is said in words, and the list is read again either way.
  Future<void> _setState(
    BuildContext context,
    RecordArea area,
    String itemRootId,
    PlanState state,
  ) async {
    if (_busy) return;
    final s = S.of(context);
    // Stopping is asked once more (it can be undone by Resume, but it
    // should not happen by a stray click).
    if (state == PlanState.stopped) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.medsStopConfirmTitle),
          content: Text(s.medsStopConfirmBody),
          actions: [
            TextButton(
              key: const ValueKey('meds-stop-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.cancel),
            ),
            FilledButton(
              key: const ValueKey('meds-stop-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(s.medsStop),
            ),
          ],
        ),
      );
      if (sure != true || !context.mounted) return;
    }
    _busy = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _svc.setPlanState(
        profileId: _me,
        itemRootId: itemRootId,
        state: state,
      );
    } on InputError catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          key: const ValueKey('meds-state-error'),
          content: Text(s.inputError(e.code)),
        ),
      );
    } finally {
      _busy = false;
      await area.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return RecordAreaScreen<MedicationView>(
      key: const ValueKey('screen-medications'),
      area: DestinationId.medications,
      id: 'meds',
      title: s.medsTitle,
      what: s.medsIntro,
      addLabel: s.medsAdd,
      emptyText: s.medsNone,
      load: () => _svc.medications(_me),
      addSheet: (_) => _AddItemSheet(svc: _svc, me: _me),
      rowBuilder: (context, m, area) => _ItemCard(
        view: m,
        onPlan: () => area.openSheet(
          (_) => _PlanSheet(
            svc: _svc,
            me: _me,
            itemRootId: m.rootId,
            change: m.plan != null,
          ),
        ),
        onDose: (status) => area.openSheet(
          (_) => _DoseSheet(
            svc: _svc,
            me: _me,
            itemRootId: m.rootId,
            status: status,
          ),
        ),
        onState: (state) => _setState(context, area, m.rootId, state),
      ),
    );
  }
}

/// One calm card per item (U037): the name, then today's recorded doses
/// and the two ways to record one ("I took it", "I skipped it"), then the
/// plan as written, in the quieter colour, with its own small actions.
/// Each dose button only opens the dose sheet: nothing is recorded until
/// Save, and the plan is never counted as a dose (planned ≠ taken).
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.view,
    required this.onPlan,
    required this.onDose,
    required this.onState,
  });

  final MedicationView view;
  final VoidCallback onPlan;
  final ValueChanged<IntakeStatus> onDose;
  final ValueChanged<PlanState> onState;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final quiet = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final item = view.item;
    final plan = view.plan;
    final facts = [
      if (item.strength != null) item.strength!,
      if (item.form != null) item.form!,
      if (item.ingredients != null) item.ingredients!,
    ].join(' · ');
    final now = DateTime.now();
    final today = [
      for (final d in view.doses)
        if (_sameDay(d.observedAt.toLocal(), now))
          (d.details! as MedicationIntakeDetails).status,
    ];
    final takenToday = today.where((t) => t == IntakeStatus.taken).length;
    return Card(
      key: ValueKey('meds-item-${view.rootId}'),
      semanticContainer: true,
      margin: const EdgeInsets.only(bottom: Space.item),
      child: Padding(
        padding: const EdgeInsets.all(Space.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              // Its own node: only the title is the heading, not the card.
              container: true,
              header: true,
              child: Text(
                '${item.name} · ${s.medsCategoryLabel(item.category)}',
                style: text.titleMedium,
              ),
            ),
            if (facts.isNotEmpty) Text(facts, style: quiet),
            const SizedBox(height: Space.l),
            // Today first: what was recorded today, and how to record a dose.
            Text(
              today.isEmpty
                  ? s.medsTodayNone
                  : s.medsToday(takenToday, today.length - takenToday),
              key: ValueKey('meds-today-${view.rootId}'),
              style: text.bodyLarge,
            ),
            const SizedBox(height: Space.s),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                FilledButton.tonal(
                  key: ValueKey('meds-dose-${view.rootId}'),
                  onPressed: () => onDose(IntakeStatus.taken),
                  child: Text(s.medsTookIt),
                ),
                OutlinedButton(
                  key: ValueKey('meds-skip-${view.rootId}'),
                  onPressed: () => onDose(IntakeStatus.skipped),
                  child: Text(s.medsSkippedIt),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            Text(
              view.doses.isEmpty
                  ? s.medsNoDoses
                  : s.medsDoseCounts(
                      view.count(IntakeStatus.taken),
                      view.count(IntakeStatus.skipped),
                    ),
              key: ValueKey('meds-counts-${view.rootId}'),
              style: quiet,
            ),
            for (final d in view.doses.take(3))
              Text(
                s.medsDoseLine(
                  fmtWhen(d.observedAt),
                  (d.details! as MedicationIntakeDetails).status ==
                      IntakeStatus.taken,
                  (d.details! as MedicationIntakeDetails).amount,
                ),
                style: quiet?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            if (view.doses.length > 3)
              Text(
                s.medsMoreDoses(view.doses.length - 3),
                key: ValueKey('meds-more-${view.rootId}'),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: Space.m),
            const Divider(height: 1),
            const SizedBox(height: Space.m),
            // The plan as written: secondary, with its own quiet actions.
            Text(
              plan == null
                  ? s.medsNoPlan
                  : s.medsPlanLineState(
                      plan.schedule,
                      s.medsPlanSourceLabel(plan.source),
                      s.medsPlanStateLabel(plan.state),
                    ),
              key: ValueKey('meds-plan-${view.rootId}'),
              style: quiet,
            ),
            Wrap(
              spacing: Space.xs,
              children: [
                TextButton(
                  key: ValueKey('meds-plan-add-${view.rootId}'),
                  onPressed: onPlan,
                  child: Text(plan == null ? s.medsPlanAdd : s.medsPlanChange),
                ),
                if (plan != null && plan.state == PlanState.active) ...[
                  TextButton(
                    key: ValueKey('meds-pause-${view.rootId}'),
                    onPressed: () => onState(PlanState.paused),
                    child: Text(s.medsPause),
                  ),
                  TextButton(
                    key: ValueKey('meds-stop-${view.rootId}'),
                    onPressed: () => onState(PlanState.stopped),
                    child: Text(s.medsStop),
                  ),
                ],
                if (plan != null && plan.state != PlanState.active)
                  TextButton(
                    key: ValueKey('meds-resume-${view.rootId}'),
                    onPressed: () => onState(PlanState.active),
                    child: Text(s.medsResume),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A form in a bottom sheet (U037): the title, the fields in small groups,
/// one primary action (Save) and a quiet Cancel. An error about a field is
/// said under that field and the field takes focus (FieldFocus); any other
/// error is said above the buttons.
class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.title,
    required this.children,
    required this.error,
    required this.onSave,
    required this.saveKey,
  });

  final String title;
  final List<Widget> children;

  /// An error about no single field.
  final String? error;
  final VoidCallback onSave;
  final String saveKey;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SheetFrame(
      fields: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: Space.l),
        ...children,
        if (error != null)
          FieldError(error!, textKey: const ValueKey('meds-error')),
      ],
      // Save, and a visible way out without saving (mouse only).
      actions: [
        FilledButton(
          key: ValueKey(saveKey),
          onPressed: onSave,
          child: Text(s.medsSave),
        ),
        TextButton(
          key: const ValueKey('meds-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}

/// The error state of a medication sheet: the code and the field it is
/// about, and one focus node per field (G-73).
mixin _SheetErrors<T extends StatefulWidget> on State<T> {
  final focus = FieldFocus();
  String? errorText;
  String? errorField;

  /// The error for the sheet's bottom line: only one about no field.
  String? get looseError => errorField == null ? errorText : null;

  void refused(S s, InputError e, {String? fallbackField}) {
    setState(() {
      errorText = s.inputError(e.code);
      errorField = e.field ?? fallbackField;
    });
    focus.focusAfterFrame(this, errorField);
  }

  void clearError() {
    if (errorText != null) {
      setState(() => errorText = errorField = null);
    }
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  Widget field(
    String key,
    String name,
    String label,
    TextEditingController c, {
    String? helper,
    TextInputType keyboard = TextInputType.text,
    bool autofocus = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Space.m),
    child: WholeLabelField(
      label: label,
      field: (labelText) => TextField(
        key: ValueKey(key),
        controller: c,
        focusNode: focus[name],
        autofocus: autofocus,
        keyboardType: keyboard,
        textCapitalization: keyboard == TextInputType.text
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        onChanged: (_) => clearError(),
        decoration: InputDecoration(
          labelText: labelText,
          helperText: helper,
          helperMaxLines: 20,
          errorText: errorField == name ? errorText : null,
          errorMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      ),
    ),
  );
}

/// A labelled group of choices, read by a screen reader with its question.
Widget _choices<T>({
  required String label,
  required List<T> values,
  required T selected,
  required String Function(T) word,
  required String Function(T) key,
  required ValueChanged<T> onPick,
}) => Padding(
  padding: const EdgeInsets.only(bottom: Space.m),
  child: Semantics(
    container: true,
    label: label,
    child: Builder(
      builder: (context) => Column(
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
                WholeChip.choice(
                  key: ValueKey(key(v)),
                  label: word(v),
                  selected: v == selected,
                  onSelected: (_) => onPick(v),
                ),
            ],
          ),
        ],
      ),
    ),
  ),
);

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({required this.svc, required this.me});

  final HeartbeatService svc;
  final String me;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet>
    with _SheetErrors<_AddItemSheet> {
  final _name = TextEditingController();
  final _ingredients = TextEditingController();
  final _strength = TextEditingController();
  final _form = TextEditingController();
  var _category = MedicationCategory.supplement;

  @override
  void dispose() {
    for (final c in [_name, _ingredients, _strength, _form]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = S.of(context);
    try {
      await widget.svc.addMedication(
        profileId: widget.me,
        name: _name.text,
        category: _category,
        ingredients: _ingredients.text,
        strength: _strength.text,
        form: _form.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on InputError catch (e) {
      refused(s, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _FormSheet(
      title: s.medsAdd,
      error: looseError,
      onSave: _save,
      saveKey: 'meds-item-save',
      children: [
        // The sheet's title names the first group: no heading of its own
        // under it (U044, a heading on a heading).
        field('meds-name', 'name', s.medsName, _name),
        _choices(
          label: s.medsCategory,
          values: MedicationCategory.values,
          selected: _category,
          word: s.medsCategoryLabel,
          key: (c) => 'meds-category-${c.name}',
          onPick: (c) => setState(() => _category = c),
        ),
        SheetSection(s.medsSectionMore),
        field(
          'meds-strength',
          'strength',
          s.medsStrength,
          _strength,
          helper: s.medsStrengthHelp,
        ),
        field('meds-form', 'form', s.medsForm, _form, helper: s.medsFormHelp),
        field(
          'meds-ingredients',
          'ingredients',
          s.medsIngredients,
          _ingredients,
        ),
      ],
    );
  }
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({
    required this.svc,
    required this.me,
    required this.itemRootId,
    this.change = false,
  });

  final HeartbeatService svc;
  final String me;
  final String itemRootId;

  /// A plan exists: the sheet is titled "Change the plan".
  final bool change;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> with _SheetErrors<_PlanSheet> {
  final _schedule = TextEditingController();
  var _source = PlanSource.unknown;

  @override
  void dispose() {
    _schedule.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = S.of(context);
    try {
      await widget.svc.planMedication(
        profileId: widget.me,
        itemRootId: widget.itemRootId,
        schedule: _schedule.text,
        source: _source,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on InputError catch (e) {
      refused(s, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _FormSheet(
      title: widget.change ? s.medsPlanChange : s.medsPlanAdd,
      error: looseError,
      onSave: _save,
      saveKey: 'meds-plan-save',
      children: [
        field(
          'meds-schedule',
          'schedule',
          s.medsPlanSchedule,
          _schedule,
          helper: s.medsPlanScheduleHelp,
        ),
        _choices(
          label: s.medsPlanSource,
          values: PlanSource.values,
          selected: _source,
          word: s.medsPlanSourceLabel,
          key: (p) => 'meds-source-${p.name}',
          onPick: (p) => setState(() => _source = p),
        ),
      ],
    );
  }
}

class _DoseSheet extends StatefulWidget {
  const _DoseSheet({
    required this.svc,
    required this.me,
    required this.itemRootId,
    this.status = IntakeStatus.taken,
  });

  final HeartbeatService svc;
  final String me;
  final String itemRootId;

  /// Taken or skipped, as chosen on the card; changeable here.
  final IntakeStatus status;

  @override
  State<_DoseSheet> createState() => _DoseSheetState();
}

class _DoseSheetState extends State<_DoseSheet> with _SheetErrors<_DoseSheet> {
  final _amount = TextEditingController();
  final _when = TextEditingController();
  late var _status = widget.status;

  @override
  void dispose() {
    _amount.dispose();
    _when.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = S.of(context);
    try {
      await widget.svc.recordDose(
        profileId: widget.me,
        itemRootId: widget.itemRootId,
        status: _status,
        amount: _amount.text,
        when: _when.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on InputError catch (e) {
      refused(s, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _FormSheet(
      title: s.medsDose,
      error: looseError,
      onSave: _save,
      saveKey: 'meds-dose-save',
      children: [
        _choices(
          label: s.medsDoseStatusLabel,
          values: const [IntakeStatus.taken, IntakeStatus.skipped],
          selected: _status,
          word: (t) =>
              t == IntakeStatus.taken ? s.medsDoseTaken : s.medsDoseSkipped,
          key: (t) => 'meds-status-${t.name}',
          onPick: (t) => setState(() => _status = t),
        ),
        field(
          'meds-amount',
          'amount',
          s.medsDoseAmount,
          _amount,
          helper: s.medsDoseAmountHelp,
        ),
        field(
          'meds-when',
          'when',
          s.medsDoseWhen,
          _when,
          helper: s.medsDoseWhenHelp,
          keyboard: TextInputType.datetime,
        ),
        TimePicks(
          keyPrefix: 'meds-when',
          controller: _when,
          picks: TimePicks.recent(s),
          onPicked: clearError,
        ),
      ],
    );
  }
}
