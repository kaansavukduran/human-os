part of 'heartbeat_service.dart';

/// Daily domains as typed (F007): sleep, check-ins, food and activity.
mixin _DailyUseCases on _HeartbeatCore {
  /// Records one night: going to bed and waking up as typed. A blank
  /// waking time is now. A going-to-bed time without a date (`HH:MM`) is the
  /// last such time before waking, so "23:10" then "07:00" is one night.
  Future<HealthRecord> recordSleep({
    required String profileId,
    required String wentToBed,
    String wokeUp = '',
    WakeFeeling? feeling,
    LocalZone zone = const SystemLocalZone(),
    String? correcting,
  }) async {
    // A correction replaces the shown version of a night with new typed
    // times; the earlier version stays in history.
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.sleepNight) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final now = clock.nowUtc();
    final bedText = wentToBed.trim();
    if (bedText.isEmpty) throw const InputError('EMPTY', 'bed');
    // Each error names the field it is about.
    T inField<T>(String field, T Function() read) {
      try {
        return read();
      } on InputError catch (e) {
        throw InputError(e.code, field);
      }
    }

    final up = inField(
      'woke',
      () => parseMeasuredAt(wokeUp, nowUtc: now, zone: zone) ?? now,
    );
    final bed = inField('bed', () {
      if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(bedText)) {
        return parseMeasuredAt(bedText, nowUtc: now, zone: zone)!;
      }
      String on(DateTime wall) =>
          '${wall.year.toString().padLeft(4, '0')}-'
          '${wall.month.toString().padLeft(2, '0')}-'
          '${wall.day.toString().padLeft(2, '0')} $bedText';
      final upWall = zone.toLocal(up);
      DateTime? sameDay;
      try {
        sameDay = parseMeasuredAt(on(upWall), nowUtc: now, zone: zone);
      } on InputError catch (e) {
        if (e.code != 'FUTURE_TIME') rethrow;
      }
      if (sameDay != null && sameDay.isBefore(up)) return sameDay;
      final dayBefore = DateTime.utc(upWall.year, upWall.month, upWall.day - 1);
      return parseMeasuredAt(on(dayBefore), nowUtc: now, zone: zone)!;
    });
    final details = SleepNightDetails(
      wentToBed: bed,
      wokeUp: up,
      feeling: feeling,
    );
    final problem = details.problem();
    if (problem != null) throw InputError(problem, 'bed');
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.sleepNight,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: up,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.sleepNight),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records how the person says they feel now (or at the typed time).
  Future<HealthRecord> recordFeeling({
    required String profileId,
    SelfLevel? energy,
    SelfLevel? mood,
    SelfLevel? stress,
    String when = '',
    String? correcting,
  }) async {
    // A correction replaces the shown version; the earlier one stays.
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.feelingCheckIn) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final details = FeelingCheckInDetails(
      energy: energy,
      mood: mood,
      stress: stress,
    );
    final problem = details.problem();
    if (problem != null) throw InputError(problem);
    final now = clock.nowUtc();
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.feelingCheckIn,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      // A correction left without a time keeps the check-in's own time.
      observedAt:
          parseMeasuredAt(when, nowUtc: now) ?? target?.observedAt ?? now,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.feelingCheckIn),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records something eaten or drunk, as typed. [nutrients] holds only the
  /// values the person typed (blank ones are left out: missing, not zero).
  Future<HealthRecord> recordFood({
    required String profileId,
    required String what,
    String amount = '',
    Map<PrintedNutrient, String> nutrients = const {},
    LabelBasis? per,
    String when = '',
    String? correcting,
  }) async {
    // A correction replaces the shown version of an entry; the earlier one
    // stays in history.
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.foodEntry) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    final now = clock.nowUtc();
    // A correction left without a time keeps the entry's own time.
    final at = parseMeasuredAt(when, nowUtc: now) ?? target?.observedAt ?? now;
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    // Each label value is checked on its own, so the error names its field.
    for (final e in nutrients.entries) {
      final v = opt(e.value);
      if (v != null && parsePrintedNumber(v) == null) {
        throw InputError(
          'FOOD_NUTRIENT_NOT_A_NUMBER',
          'nutrient-${e.key.name}',
        );
      }
    }
    final details = FoodEntryDetails(
      what: what.trim(),
      amount: opt(amount),
      per: per,
      nutrients: {
        for (final e in nutrients.entries)
          if (opt(e.value) != null) e.key: opt(e.value)!,
      },
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        problem.endsWith('_TOO_LONG')
            ? 'TEXT_TOO_LONG'
            : problem.startsWith('FOOD_WHAT')
            ? 'EMPTY'
            : problem,
        problem == 'FOOD_LABEL_BASIS_REQUIRED'
            ? 'per'
            : problem.startsWith('FOOD_AMOUNT')
            ? 'amount'
            : 'what',
      );
    }
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.foodEntry,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: at,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.foodEntry),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// Records one activity as typed: minutes and steps are whole numbers,
  /// blank = not given. [correcting] makes it a new version of that entry.
  Future<HealthRecord> recordActivity({
    required String profileId,
    required String what,
    String minutes = '',
    String steps = '',
    String when = '',
    String? correcting,
  }) async {
    final target = correcting == null
        ? null
        : await _currentTarget(profileId, correcting);
    if (target != null && target.kind != RecordKind.activityEntry) {
      throw const InputError('TARGET_WRONG_KIND');
    }
    int? whole(String raw, String field) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      if (!RegExp(r'^\d{1,6}$').hasMatch(t)) {
        throw InputError('NOT_A_WHOLE_NUMBER', field);
      }
      return int.parse(t);
    }

    final now = clock.nowUtc();
    // A correction left without a time keeps the entry's own time.
    final at = parseMeasuredAt(when, nowUtc: now) ?? target?.observedAt ?? now;
    final details = ActivityEntryDetails(
      what: what.trim(),
      minutes: whole(minutes, 'minutes'),
      steps: whole(steps, 'steps'),
    );
    final problem = details.problem();
    if (problem != null) {
      throw InputError(
        switch (problem) {
          final p when p.endsWith('_TOO_LONG') => 'TEXT_TOO_LONG',
          final p when p.startsWith('ACTIVITY_WHAT') => 'EMPTY',
          final p => p,
        },
        switch (problem) {
          'ACTIVITY_MINUTES_RANGE' => 'minutes',
          'ACTIVITY_STEPS_RANGE' => 'steps',
          _ => 'what',
        },
      );
    }
    final record = HealthRecord(
      id: _ids.newId(),
      profileId: profileId,
      kind: RecordKind.activityEntry,
      state: RecordState.reported,
      valueStatus: ValueStatus.present,
      quantity: null,
      originalText: null,
      provenance: const Provenance.manual(),
      observedAt: at,
      recordedAt: now,
      details: details,
      supersedesId: target?.id,
      amendReason: target == null ? null : AmendReason.correction,
      schemaVersion: HealthRecord.writeSchemaFor(RecordKind.activityEntry),
    );
    await repository.appendRecord(record);
    return record;
  }

  /// The live activity entries, the latest first.
  Future<List<HealthRecord>> activities(String profileId) =>
      _liveHeads<ActivityEntryDetails>(
        profileId,
        RecordKind.activityEntry,
        by: _NewestBy.observed,
      );

  /// The live food entries, the latest first.
  Future<List<HealthRecord>> foods(String profileId) =>
      _liveHeads<FoodEntryDetails>(
        profileId,
        RecordKind.foodEntry,
        by: _NewestBy.observed,
      );

  /// The live check-ins, the latest first.
  Future<List<HealthRecord>> feelings(String profileId) =>
      _liveHeads<FeelingCheckInDetails>(
        profileId,
        RecordKind.feelingCheckIn,
        by: _NewestBy.observed,
      );

  /// The live nights, the latest waking first.
  Future<List<HealthRecord>> sleepNights(String profileId) =>
      _liveHeads<SleepNightDetails>(
        profileId,
        RecordKind.sleepNight,
        by: _NewestBy.observed,
      );
}
