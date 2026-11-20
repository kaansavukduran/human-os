part of 'heartbeat_service.dart';

/// Conditions (F009), preventive items (F009 slice 2) and document
/// references (F010), each as the person names it.
mixin _EntryUseCases on _HeartbeatCore {
  /// Records a condition or symptom as the person names it, with who it
  /// comes from. [correcting] makes it a new version of that entry.
  Future<HealthRecord> recordCondition({
    required String profileId,
    required String name,
    required ConditionType nature,
    required ConditionTime time,
    required ConditionSource source,
    String since = '',
    String? correcting,
  }) async {
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.conditionEntry) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final details = ConditionEntryDetails(
      name: name.trim(),
      nature: nature,
      time: time,
      source: source,
      since: since.trim().isEmpty ? null : since.trim(),
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        problem.endsWith('_TOO_LONG') ? 'TEXT_TOO_LONG' : 'EMPTY',
        problem.startsWith('CONDITION_SINCE') ? 'since' : 'name',
      );
    }
    final now = clock.nowUtc();
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.conditionEntry,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: target?.observedAt ?? now,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.conditionEntry),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// The live condition entries, the latest recorded first.
  Future<List<HealthRecord>> conditions(String profileId) =>
      _liveHeads<ConditionEntryDetails>(
        profileId,
        RecordKind.conditionEntry,
        by: _NewestBy.recorded,
      );

  /// Records a preventive item (vaccination, screening, check-up) as the
  /// person names it: done, planned or unsure, with who it comes from and
  /// when as typed. No result is stored and nothing is scheduled or
  /// recommended. [correcting] makes it a new version of that entry.
  Future<HealthRecord> recordPreventive({
    required String profileId,
    required String name,
    required PreventiveType nature,
    required PreventiveStatus status,
    required ConditionSource source,
    String when = '',
    String? correcting,
  }) async {
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.preventiveEntry) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    // Carrying out a plan is a new fact, not a fix of the plan: a correction
    // never turns "planned" into "done" (planned ≠ completed).
    if (target != null &&
        status == PreventiveStatus.done &&
        (target.details as PreventiveEntryDetails?)?.status ==
            PreventiveStatus.planned) {
      throw const InputError('PLANNED_NOT_DONE', 'status');
    }
    final details = PreventiveEntryDetails(
      name: name.trim(),
      nature: nature,
      status: status,
      source: source,
      when: when.trim().isEmpty ? null : when.trim(),
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        problem.endsWith('_TOO_LONG') ? 'TEXT_TOO_LONG' : 'EMPTY',
        problem.startsWith('PREVENTIVE_WHEN') ? 'when' : 'name',
      );
    }
    final now = clock.nowUtc();
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.preventiveEntry,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: target?.observedAt ?? now,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.preventiveEntry),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records a reference to a document the person keeps (F010 slice 1):
  /// its title, kind, own date, issuer and where it is kept, each as typed.
  /// The app never reads, opens, uploads or stores the document.
  /// [correcting] makes it a new version of that entry, keeping its time.
  Future<HealthRecord> recordDocument({
    required String profileId,
    required String title,
    required DocumentType nature,
    String date = '',
    String issuer = '',
    String whereKept = '',
    String? correcting,
  }) async {
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.documentReference) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    final details = DocumentReferenceDetails(
      title: title.trim(),
      nature: nature,
      date: opt(date),
      issuer: opt(issuer),
      whereKept: opt(whereKept),
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        problem.endsWith('_TOO_LONG') ? 'TEXT_TOO_LONG' : 'EMPTY',
        switch (problem) {
          final p when p.startsWith('DOCUMENT_DATE') => 'date',
          final p when p.startsWith('DOCUMENT_ISSUER') => 'issuer',
          final p when p.startsWith('DOCUMENT_WHERE') => 'whereKept',
          _ => 'title',
        },
      );
    }
    final now = clock.nowUtc();
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.documentReference,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: target?.observedAt ?? now,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.documentReference),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// The live document references, the latest recorded first.
  Future<List<HealthRecord>> documents(String profileId) =>
      _liveHeads<DocumentReferenceDetails>(
        profileId,
        RecordKind.documentReference,
        by: _NewestBy.recorded,
      );

  /// The live preventive entries, the latest recorded first.
  Future<List<HealthRecord>> preventives(String profileId) =>
      _liveHeads<PreventiveEntryDetails>(
        profileId,
        RecordKind.preventiveEntry,
        by: _NewestBy.recorded,
      );
}
