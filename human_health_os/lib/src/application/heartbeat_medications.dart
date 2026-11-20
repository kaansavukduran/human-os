part of 'heartbeat_service.dart';

mixin _MedicationUseCases on _HeartbeatCore {
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
