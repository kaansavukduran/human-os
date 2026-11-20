// H001 regression: the HeartbeatService split and its one live-heads helper
// change no ordering. Every list method is read back from one mixed fixture
// built only through the public API, and must return exactly the order the
// service returned before the split (recorded on the pre-split code).
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/application/measured_at.dart';
import 'package:human_health_os/src/core/ids.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

/// Each read of the clock is one minute later: every record has its own
/// recorded time, so "latest recorded first" and "latest observed first"
/// give different orders on the same entries.
class _Tick implements Clock {
  DateTime _t = DateTime.utc(2026, 11, 10, 12);
  @override
  DateTime nowUtc() => _t = _t.add(const Duration(minutes: 1));
}

const utc = OffsetRuleZone(_zero);
Duration _zero(DateTime _) => Duration.zero;

List<String> ids(Iterable<HealthRecord> rs) => [for (final r in rs) r.id];

void main() {
  test('every list method keeps its order on a mixed fixture', () async {
    final repo = LogRepository(
      sink: MemoryLogSink(),
      durability: StorageDurability.localFile,
      location: 'test',
    );
    await repo.open();
    final svc = HeartbeatService(repo, clock: _Tick());
    final me = (await svc.ensureSelfProfile()).id;

    // Four entries per kind, recorded a, b, c, d, observed on days 3, 1, 4
    // and 2. Then b is corrected (b2, recorded last, observed time kept) and
    // d is deleted. Kinds interleave so one kind's records sit between
    // another's.
    const days = [3, 1, 4, 2];
    String at(int day, [String time = '08:00']) => '2026-11-0$day $time';

    final sleep = <HealthRecord>[];
    final feel = <HealthRecord>[];
    final food = <HealthRecord>[];
    final act = <HealthRecord>[];
    final cond = <HealthRecord>[];
    final prev = <HealthRecord>[];
    final docs = <HealthRecord>[];
    for (var i = 0; i < 4; i++) {
      final day = days[i];
      sleep.add(
        await svc.recordSleep(
          profileId: me,
          wentToBed: at(day, '00:30'),
          wokeUp: at(day, '07:00'),
          zone: utc,
        ),
      );
      feel.add(
        await svc.recordFeeling(
          profileId: me,
          energy: SelfLevel.values[i % 3],
          when: at(day),
        ),
      );
      food.add(
        await svc.recordFood(profileId: me, what: 'meal $i', when: at(day)),
      );
      act.add(
        await svc.recordActivity(profileId: me, what: 'walk $i', when: at(day)),
      );
      cond.add(
        await svc.recordCondition(
          profileId: me,
          name: 'condition $i',
          nature: ConditionType.symptom,
          time: ConditionTime.current,
          source: ConditionSource.selfReported,
        ),
      );
      prev.add(
        await svc.recordPreventive(
          profileId: me,
          name: 'preventive $i',
          nature: PreventiveType.checkup,
          status: PreventiveStatus.done,
          source: ConditionSource.selfReported,
        ),
      );
      docs.add(
        await svc.recordDocument(
          profileId: me,
          title: 'document $i',
          nature: DocumentType.letter,
        ),
      );
    }

    final b2 = <String, HealthRecord>{
      'sleep': await svc.recordSleep(
        profileId: me,
        wentToBed: at(1, '00:15'),
        wokeUp: at(1, '07:00'),
        zone: utc,
        correcting: sleep[1].id,
      ),
      'feel': await svc.recordFeeling(
        profileId: me,
        energy: SelfLevel.high,
        mood: SelfLevel.low,
        correcting: feel[1].id,
      ),
      'food': await svc.recordFood(
        profileId: me,
        what: 'meal 1 corrected',
        correcting: food[1].id,
      ),
      'act': await svc.recordActivity(
        profileId: me,
        what: 'walk 1 corrected',
        correcting: act[1].id,
      ),
      'cond': await svc.recordCondition(
        profileId: me,
        name: 'condition 1 corrected',
        nature: ConditionType.symptom,
        time: ConditionTime.past,
        source: ConditionSource.selfReported,
        correcting: cond[1].id,
      ),
      'prev': await svc.recordPreventive(
        profileId: me,
        name: 'preventive 1 corrected',
        nature: PreventiveType.checkup,
        status: PreventiveStatus.unsure,
        source: ConditionSource.selfReported,
        correcting: prev[1].id,
      ),
      'docs': await svc.recordDocument(
        profileId: me,
        title: 'document 1 corrected',
        nature: DocumentType.letter,
        correcting: docs[1].id,
      ),
    };
    for (final list in [sleep, feel, food, act, cond, prev, docs]) {
      await svc.amend(
        profileId: me,
        targetId: list[3].id,
        reason: AmendReason.deleted,
      );
    }

    // Latest observed first: c (day 4), a (day 3), b2 (day 1).
    expect(ids(await svc.sleepNights(me)), [
      sleep[2].id,
      sleep[0].id,
      b2['sleep']!.id,
    ]);
    expect(ids(await svc.feelings(me)), [
      feel[2].id,
      feel[0].id,
      b2['feel']!.id,
    ]);
    expect(ids(await svc.foods(me)), [food[2].id, food[0].id, b2['food']!.id]);
    expect(ids(await svc.activities(me)), [
      act[2].id,
      act[0].id,
      b2['act']!.id,
    ]);
    // Latest recorded first: b2, c, a.
    expect(ids(await svc.conditions(me)), [
      b2['cond']!.id,
      cond[2].id,
      cond[0].id,
    ]);
    expect(ids(await svc.preventives(me)), [
      b2['prev']!.id,
      prev[2].id,
      prev[0].id,
    ]);
    expect(ids(await svc.documents(me)), [
      b2['docs']!.id,
      docs[2].id,
      docs[0].id,
    ]);

    // Weights (current heads) and a medicine's doses, newest observed first.
    final w = [
      for (final day in days)
        await svc.recordWeightKg(
          profileId: me,
          input: '7$day',
          observedAt: DateTime.utc(2026, 11, day, 8),
        ),
    ];
    expect(ids(await svc.currentWeights(me)), [
      w[2].id,
      w[0].id,
      w[3].id,
      w[1].id,
    ]);
    final item = await svc.addMedication(
      profileId: me,
      name: 'Vitamin D',
      category: MedicationCategory.supplement,
    );
    final doses = [
      for (final day in days)
        await svc.recordDose(
          profileId: me,
          itemRootId: item.id,
          status: day.isEven ? IntakeStatus.taken : IntakeStatus.skipped,
          when: at(day),
        ),
    ];
    final meds = await svc.medications(me);
    expect(meds.single.rootId, item.id);
    expect(ids(meds.single.doses), [
      doses[2].id,
      doses[0].id,
      doses[3].id,
      doses[1].id,
    ]);
  });
}
