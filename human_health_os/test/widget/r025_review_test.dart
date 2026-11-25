// R025: U038 review fixes.
// 1. The Timeline's day headers follow the app's clock (never
//    DateTime.now()) and are written again just after local midnight and
//    when the app comes back to the foreground. Run in UTC and with
//    TZ=America/New_York.
// 2. A record that is not observed or reported (worked out, modelled,
//    planned …) says so on its Timeline row (model output ≠ observed fact);
//    a device's own estimate keeps its wording and gets no chip.
// 3. The Timeline sheet keeps the lab's printed range under the value.
// 4. Details toggles name what tells rows apart: the sample date on Labs,
//    the laboratory (or value and time) on "Same test over time" when two
//    results share a day.
// 5. The font samples' toggle closes in matching words.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/config/app_config.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/core/ids.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/settings/date_style.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f007_measurements_test.dart' show launch, settle, tapKey;
import 'u035_text_fit_test.dart' show mainScroll;

const dev = AppConfig(
  profile: BuildProfile.development,
  version: 't',
  sourceRevision: 't',
);

/// A clock the test moves by hand (local wall time).
class _HandClock implements Clock {
  _HandClock(this.now);

  DateTime now;

  @override
  DateTime nowUtc() => now.toUtc();
}

String _iso(DateTime d) => formatDay(d.year, d.month, d.day, DateOrder.iso);

Finder _in(Finder of, Finder what) => find.descendant(of: of, matching: what);

Future<AppServices> _start(
  WidgetTester tester, {
  required Clock clock,
  Locale? locale,
}) async {
  tester.view.physicalSize = const Size(1280, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (locale != null) {
    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
  final services = await tester.runAsync(() async {
    final repo = inMemoryRepository();
    await repo.open();
    return servicesFor(dev, HostPlatform.linux, repo, clock: clock);
  });
  return services!;
}

Future<void> _go(WidgetTester tester, DestinationId id) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('nav-rail')),
      matching: find.byIcon(destinationById(id).icon),
    ),
  );
  await settle(tester);
}

/// The text of the day header for [day], or null when none is built.
String? _header(WidgetTester tester, DateTime day) {
  final f = find.byKey(ValueKey('timeline-day-${_iso(day)}'));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(_in(f, find.byType(Text))).data;
}

/// A copy of [r] as a separate fact in [state] (as a development import
/// can bring in), appended to the repository.
Future<HealthRecord> _asState(
  AppServices s,
  HealthRecord r,
  RecordState state,
  int n,
) async {
  final j = r.toJson();
  j['id'] = '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
  j['state'] = state.name;
  final copy = HealthRecord.fromJson(j);
  await s.heartbeat.repository.appendRecord(copy);
  return copy;
}

/// Opens the one "Same test over time" group on Labs.
Future<void> _openGroup(WidgetTester tester) async {
  final group = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        k.value.startsWith('lab-group-') &&
        !k.value.startsWith('lab-group-row-');
  });
  expect(group, findsOneWidget);
  await tester.ensureVisible(group);
  await tester.pumpAndSettle();
  await tester.tap(group);
  await settle(tester);
}

void main() {
  testWidgets('day headers follow the app clock and move on just after '
      'local midnight', (tester) async {
    final clock = _HandClock(DateTime(2026, 11, 19, 23, 59, 30));
    final s = await _start(tester, clock: clock);
    await tester.runAsync(
      () => s.heartbeat.recordWeightKg(profileId: s.self.id, input: '78'),
    );
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    await _go(tester, DestinationId.timeline);
    final day = DateTime(2026, 11, 19);
    // The app clock's day, not the machine's (DateTime.now() is 2026 or
    // later, never 19 November at 23:59 for the whole run).
    expect(_header(tester, day), 'Today');

    // Midnight passes; the timer (due 30 s after it was set, plus a
    // second) writes the headers again.
    clock.now = DateTime(2026, 11, 20, 0, 0, 1);
    await tester.pump(const Duration(seconds: 29));
    expect(_header(tester, day), 'Today');
    await tester.pump(const Duration(seconds: 2));
    expect(_header(tester, day), 'Yesterday');

    // And again the next night: now a date.
    clock.now = DateTime(2026, 11, 21, 0, 0, 2);
    await tester.pump(const Duration(hours: 24));
    expect(_header(tester, day), _iso(day));
  });

  testWidgets('back from sleep past midnight, the headers move on at once, '
      'without their timer', (tester) async {
    final clock = _HandClock(DateTime(2026, 11, 19, 22));
    final s = await _start(tester, clock: clock, locale: const Locale('tr'));
    await tester.runAsync(
      () => s.heartbeat.recordWeightKg(profileId: s.self.id, input: '78'),
    );
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    await _go(tester, DestinationId.timeline);
    final day = DateTime(2026, 11, 19);
    expect(_header(tester, day), 'Bugün');
    void lifecycle(List<AppLifecycleState> states) {
      for (final st in states) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
    }

    lifecycle(const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    clock.now = DateTime(2026, 11, 20, 7, 15);
    await tester.pump();
    expect(_header(tester, day), 'Bugün');
    lifecycle(const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
    expect(_header(tester, day), 'Dün');
  });

  for (final (lang, locale, derived, modelled) in [
    ('en', const Locale('en', 'US'), 'Worked out', 'Model estimate'),
    ('tr', const Locale('tr', 'TR'), 'Hesaplandı', 'Model tahmini'),
  ]) {
    testWidgets('$lang: a record that is not observed or reported says so on '
        'its row; observed, reported and device estimates get no chip', (
      tester,
    ) async {
      final s = await launch(tester, locale: locale);
      final t = S(lang == 'tr' ? AppLang.tr : AppLang.en);
      final r = (await tester.runAsync(() async {
        final me = s.self.id;
        final base = await s.heartbeat.recordWeightKg(
          profileId: me,
          input: '78',
        );
        final fat = await s.heartbeat.recordMeasurement(
          profileId: me,
          kind: RecordKind.bodyFatPercentage,
          input: const MeasurementInput(value: '24.5'),
        );
        return {
          'observed': base,
          'fat': fat,
          for (final (i, st) in RecordState.values.indexed)
            if (st != RecordState.observed)
              st.name: await _asState(s, base, st, i + 1),
        };
      }))!;
      await _go(tester, DestinationId.timeline);
      Finder row(HealthRecord x) =>
          find.byKey(ValueKey('timeline-entry-${x.id}'));
      Finder chip(HealthRecord x) =>
          find.byKey(ValueKey('timeline-state-${x.id}'));
      Future<void> bring(HealthRecord x) => tester.scrollUntilVisible(
        row(x),
        200,
        scrollable: mainScroll('screen-timeline'),
      );

      expect(r['fat']!.state, RecordState.reported);
      for (final key in ['observed', 'reported', 'fat']) {
        await bring(r[key]!);
        expect(chip(r[key]!), findsNothing, reason: key);
      }
      // The device's estimate keeps its own wording in its name.
      expect(
        _in(
          row(r['fat']!),
          find.text(t.recordKind(RecordKind.bodyFatPercentage)),
        ),
        findsOneWidget,
      );
      await bring(r['derived']!);
      expect(_in(chip(r['derived']!), find.text(derived)), findsOneWidget);
      await bring(r['modelled']!);
      expect(_in(chip(r['modelled']!), find.text(modelled)), findsOneWidget);
      for (final st in [
        RecordState.planned,
        RecordState.completed,
        RecordState.assumed,
        RecordState.unknown,
      ]) {
        await bring(r[st.name]!);
        expect(
          _in(chip(r[st.name]!), find.text(t.recordState(st))),
          findsOneWidget,
          reason: st.name,
        );
      }
    });
  }

  testWidgets('the Timeline sheet keeps the lab\'s printed range under the '
      'value, without opening Details', (tester) async {
    final s = await launch(tester);
    const t = S(AppLang.en);
    final r = (await tester.runAsync(() async {
      final me = s.self.id;
      return (
        await s.heartbeat.recordLab(
          profileId: me,
          input: const LabInput(
            analyte: 'HbA1c',
            value: '5,4',
            notReported: false,
            unit: '%',
            sampleDate: '2026-10-01',
            referenceText: '4,0 - 6,0',
            refLow: '4,0',
            refHigh: '6,0',
            refUnit: '%',
          ),
        ),
        await s.heartbeat.recordLab(
          profileId: me,
          input: const LabInput(
            analyte: 'Ferritin',
            value: '40',
            notReported: false,
            unit: 'ng/mL',
            sampleDate: '2026-09-01',
            referenceText: '30-400',
          ),
        ),
      );
    }))!;
    await _go(tester, DestinationId.timeline);
    for (final (rec, expected) in [
      (r.$1, t.labIntervalLine(r.$1.lab!.referenceInterval!)),
      (r.$2, t.labPrintedRange('30-400')),
    ]) {
      final row = find.byKey(ValueKey('timeline-entry-${rec.id}'));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: mainScroll('screen-timeline'),
      );
      await tester.tap(row);
      await settle(tester);
      final range = find.byKey(ValueKey('timeline-lab-range-${rec.id}'));
      expect(tester.widget<Text>(range).data, expected);
      expect(find.byKey(ValueKey('version-details-${rec.id}')), findsNothing);
      // Opening Details does not say it a second time.
      await tapKey(tester, 'details-timeline-${rec.id}');
      expect(find.text(expected), findsOneWidget);
      Navigator.of(
        tester.element(find.byKey(const ValueKey('timeline-detail'))),
      ).pop();
      await settle(tester);
    }
  });

  testWidgets('Details names tell rows apart: the sample date on Labs, the '
      'laboratory when two results share a day', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await launch(tester);
    LabInput lab(String v, String date, String laboratory) => LabInput(
      analyte: 'HbA1c',
      value: v,
      notReported: false,
      unit: '%',
      sampleDate: date,
      laboratory: laboratory,
    );
    final r = (await tester.runAsync(() async {
      final me = s.self.id;
      return [
        await s.heartbeat.recordLab(
          profileId: me,
          input: lab('5,4', '2026-10-01', 'Lab A'),
        ),
        await s.heartbeat.recordLab(
          profileId: me,
          input: lab('5,6', '2026-10-01', 'Lab B'),
        ),
        await s.heartbeat.recordLab(
          profileId: me,
          input: lab('5,9', '2026-05-12', 'Lab A'),
        ),
      ];
    }))!;
    await _go(tester, DestinationId.labs);
    String label(String key) =>
        tester.getSemantics(find.byKey(ValueKey(key))).label;
    final labs = [for (final x in r) label('details-lab-${x.id}')];
    expect(labs.toSet().length, 3, reason: '$labs');
    expect(labs[2], contains(formatDay(2026, 5, 12, displayDateOrder)));

    await _openGroup(tester);
    final group = [for (final x in r) label('details-lab-group-${x.id}')];
    expect(group.toSet().length, 3, reason: '$group');
    expect(group[0], contains('Lab A'));
    expect(group[1], contains('Lab B'));
    // A day of its own needs no more than the date.
    expect(group[2], 'Details: ${formatDay(2026, 5, 12, displayDateOrder)}');
    handle.dispose();
  });

  testWidgets('two results on one day at one laboratory are told apart by '
      'their value', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await launch(tester);
    final r = (await tester.runAsync(() async {
      final me = s.self.id;
      return [
        for (final v in ['5,4', '5,6'])
          await s.heartbeat.recordLab(
            profileId: me,
            input: LabInput(
              analyte: 'HbA1c',
              value: v,
              notReported: false,
              unit: '%',
              sampleDate: '2026-10-01',
              laboratory: 'Lab A',
            ),
          ),
      ];
    }))!;
    await _go(tester, DestinationId.labs);
    await _openGroup(tester);
    final group = [
      for (final x in r)
        tester
            .getSemantics(find.byKey(ValueKey('details-lab-group-${x.id}')))
            .label,
    ];
    expect(group[0], contains('5,4'));
    expect(group[1], contains('5,6'));
    handle.dispose();
  });

  for (final (lang, locale) in [
    ('en', const Locale('en', 'US')),
    ('tr', const Locale('tr', 'TR')),
  ]) {
    testWidgets('$lang: the font samples close in words that match how they '
        'opened', (tester) async {
      final handle = tester.ensureSemantics();
      await launch(tester, locale: locale);
      final t = S(lang == 'tr' ? AppLang.tr : AppLang.en);
      await tapKey(tester, 'open-settings');
      final toggle = find.byKey(const ValueKey('details-font-previews'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(_in(toggle, find.text(t.fontPreviewShow)), findsOneWidget);
      expect(
        tester.getSemantics(toggle).label,
        t.fieldDetailsFor(t.fontPreviewShow, t.settingsFont),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(_in(toggle, find.text(t.fontPreviewHide)), findsOneWidget);
      expect(_in(toggle, find.text(t.detailsHide)), findsNothing);
      expect(
        tester.getSemantics(toggle).label,
        t.fieldDetailsFor(t.fontPreviewHide, t.settingsFont),
      );
      handle.dispose();
    });
  }
}
