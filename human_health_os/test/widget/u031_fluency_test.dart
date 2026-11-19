// U031-S4: fluency. Long Timeline and Labs histories build only the rows in
// view; a sheet's own changes never rebuild the list; a setting Today does
// not show never rebuilds a Today card; the date line moves on at local
// midnight. Plus a regression for each slop-audit fix.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/appearance_scope.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/config/app_config.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/core/ids.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/features/common/planned_destination_screen.dart';
import 'package:human_health_os/src/features/today/feeling_card.dart';
import 'package:human_health_os/src/features/today/measurements_card.dart';
import 'package:human_health_os/src/features/today/sleep_card.dart';
import 'package:human_health_os/src/features/today/weight_card.dart';
import 'package:human_health_os/src/features/today/your_data_card.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';
import 'package:human_health_os/src/presentation/theme/human_os_theme.dart';

const dev = AppConfig(
  profile: BuildProfile.development,
  version: 't',
  sourceRevision: 't',
);

/// A clock the test moves by hand.
class _HandClock implements Clock {
  _HandClock(this.now);

  DateTime now;

  @override
  DateTime nowUtc() => now.toUtc();
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

Future<AppServices> start(
  WidgetTester tester, {
  Clock clock = const SystemClock(),
  Size size = const Size(1280, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final services = await tester.runAsync(() async {
    final repo = inMemoryRepository();
    await repo.open();
    return servicesFor(dev, HostPlatform.linux, repo, clock: clock);
  });
  return services!;
}

Future<void> openArea(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('nav-rail')),
      matching: find.text(label),
    ),
  );
  await settle(tester);
}

/// Every built widget whose key starts with [prefix], on screen or in the
/// list's cache area.
int builtWithKey(String prefix) => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(prefix),
      skipOffstage: false,
    )
    .evaluate()
    .length;

Finder scrollableOf(String screenKey) => find
    .descendant(
      of: find.byKey(ValueKey(screenKey)),
      matching: find.byType(Scrollable),
    )
    .first;

/// Counts the builds of widgets whose type name is in [types] until the
/// test ends.
Map<String, int> countBuilds(Set<String> types) {
  final counts = <String, int>{};
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    final name = element.widget.runtimeType.toString();
    if (types.contains(name)) counts[name] = (counts[name] ?? 0) + 1;
  };
  addTearDown(() => debugOnRebuildDirtyWidget = null);
  return counts;
}

void main() {
  testWidgets('Timeline with 500 entries builds only the rows in view, and '
      'scrolling reaches the last one', (tester) async {
    final s = await start(tester);
    final ids = <String>[];
    await tester.runAsync(() async {
      for (var i = 0; i < 500; i++) {
        final r = await s.heartbeat.recordWeightKg(
          profileId: s.self.id,
          input: '${60 + i % 30}',
          observedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: i)),
        );
        ids.add(r.id);
      }
    });
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    await openArea(tester, 'Timeline');
    final built = builtWithKey('timeline-entry-');
    expect(built, greaterThan(0));
    expect(built, lessThan(40));
    // Newest first: the oldest entry is the last row.
    final last = find.byKey(ValueKey('timeline-entry-${ids.first}'));
    expect(last, findsNothing);
    await tester.scrollUntilVisible(
      last,
      2000,
      scrollable: scrollableOf('screen-timeline'),
      maxScrolls: 200,
    );
    expect(last, findsOneWidget);
    expect(builtWithKey('timeline-entry-'), lessThan(40));
  });

  testWidgets('Labs with 300 results builds only the rows in view; scrolling '
      'reaches the last; the sheet\'s own changes never rebuild a row', (
    tester,
  ) async {
    final s = await start(tester);
    final ids = <String>[];
    await tester.runAsync(() async {
      for (var i = 0; i < 300; i++) {
        final r = await s.heartbeat.recordLab(
          profileId: s.self.id,
          input: LabInput(
            analyte: 'Analyte $i',
            value: '${i + 1}',
            notReported: false,
            unit: 'mg/dL',
            sampleDate:
                '2025-${(i % 12 + 1).toString().padLeft(2, '0')}-'
                '${(i % 28 + 1).toString().padLeft(2, '0')}',
          ),
        );
        ids.add(r.id);
      }
    });
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    await openArea(tester, 'Labs');
    final built = builtWithKey('lab-row-');
    expect(built, greaterThan(0));
    expect(built, lessThan(40));

    // Open the add sheet, then change a field in it: no row builds again.
    await tester.tap(find.byKey(const ValueKey('lab-add')));
    await tester.pumpAndSettle();
    final counts = countBuilds({'_LabTile'});
    await tester.tap(find.byKey(const ValueKey('lab-not-reported')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('lab-analyte')), 'X');
    await tester.pumpAndSettle();
    expect(counts['_LabTile'] ?? 0, 0);
    await tester.tap(find.byKey(const ValueKey('lab-cancel')));
    await tester.pumpAndSettle();
    expect(counts['_LabTile'] ?? 0, 0, reason: 'closing the sheet');

    final rows = [
      for (final e
          in find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith('lab-row-'),
              )
              .evaluate())
        e.widget.key,
    ];
    expect(rows, isNotEmpty);
    // The last row of the list is one of the 300 results.
    final lastId = await tester.runAsync(
      () async => (await s.heartbeat.labTimeline(s.self.id)).last.heads.last.id,
    );
    expect(ids, contains(lastId));
    final last = find.byKey(ValueKey('lab-row-$lastId'));
    await tester.scrollUntilVisible(
      last,
      2000,
      scrollable: scrollableOf('screen-labs'),
      maxScrolls: 200,
    );
    expect(last, findsOneWidget);
    expect(builtWithKey('lab-row-'), lessThan(40));
  });

  testWidgets('a setting Today does not show never rebuilds a Today card; '
      'one it does show still does', (tester) async {
    final s = await start(tester, size: const Size(1280, 3200));
    final c = AppearanceController(MemoryAppearanceStore());
    await tester.pumpWidget(HumanOsApp(services: s, appearance: c));
    await settle(tester);
    expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
    const cards = {
      'WeightCard',
      'MeasurementsCard',
      'SleepCard',
      'FeelingCard',
      'YourDataCard',
    };
    // Make sure each name is the real type (a rename would pass silently).
    expect(
      {
        WeightCard,
        MeasurementsCard,
        SleepCard,
        FeelingCard,
        YourDataCard,
      }.map((t) => t.toString()).toSet(),
      cards,
    );
    final counts = countBuilds(cards);

    // The start screen is read once, when the app opens; Today never shows it.
    await tester.runAsync(
      () => c.update(c.value.copyWith(startScreen: StartScreen.labs)),
    );
    await tester.pumpAndSettle();
    expect(counts, isEmpty);

    // Showing Aion or not is not a Today setting either.
    await tester.runAsync(() => c.update(c.value.copyWith(showAion: false)));
    await tester.pumpAndSettle();
    expect(counts, isEmpty);

    // Moving measurements first reorders Today, yet each card is the same
    // widget and is not built again.
    await tester.runAsync(
      () => c.update(c.value.copyWith(measurementsFirst: true)),
    );
    await tester.pumpAndSettle();
    expect(counts, isEmpty);

    // The number pad setting is shown by the weight card: it builds again.
    await tester.runAsync(() => c.update(c.value.copyWith(padOpen: true)));
    await tester.pumpAndSettle();
    expect(counts['WeightCard'], greaterThan(0));
  });

  testWidgets('the date line moves on just after local midnight', (
    tester,
  ) async {
    final clock = _HandClock(DateTime(2026, 11, 19, 23, 59, 30));
    final s = await start(tester, clock: clock);
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    String line() =>
        tester.widget<Text>(find.byKey(const ValueKey('today-date'))).data!;
    const en = S(AppLang.en);
    expect(line(), en.dateLine(DateTime(2026, 11, 19)));

    // Midnight passes; the timer (due 30 s after it was set, plus a second)
    // writes the new day.
    clock.now = DateTime(2026, 11, 20, 0, 0, 1);
    await tester.pump(const Duration(seconds: 29));
    expect(line(), en.dateLine(DateTime(2026, 11, 19)));
    await tester.pump(const Duration(seconds: 2));
    expect(line(), en.dateLine(DateTime(2026, 11, 20)));

    // And again the next night.
    clock.now = DateTime(2026, 11, 21, 0, 0, 2);
    await tester.pump(const Duration(hours: 24));
    expect(line(), en.dateLine(DateTime(2026, 11, 21)));
  });

  testWidgets('an area heading is its own heading node, not one banner with '
      'the lines under it (web smoke finding)', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await start(tester);
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    await openArea(tester, 'Labs');
    final title = find.descendant(
      of: find.byKey(const ValueKey('area-intro-labs')),
      matching: find.text('Labs'),
    );
    expect(
      tester.getSemantics(title),
      isSemantics(isHeader: true, label: 'Labs'),
    );
    handle.dispose();
  });

  group('slop audit', () {
    testWidgets('Today\'s tools and the trend buttons use the outlined icon '
        'family', (tester) async {
      final s = await start(tester, size: const Size(1280, 3200));
      await tester.pumpWidget(HumanOsApp(services: s));
      await settle(tester);
      expect(find.byIcon(Icons.accessibility_new), findsNothing);
      expect(find.byIcon(Icons.accessibility_new_outlined), findsOneWidget);
      await tester.runAsync(
        () => s.heartbeat.recordWeightKg(profileId: s.self.id, input: '70'),
      );
      await tester.pumpWidget(HumanOsApp(services: s, key: UniqueKey()));
      await settle(tester);
      expect(find.byIcon(Icons.show_chart), findsNothing);
    });

    testWidgets('a planned area states its principle without a decorative '
        'icon', (tester) async {
      final d = destinationById(DestinationId.compare);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlannedDestinationScreen(destination: d)),
        ),
      );
      expect(find.byIcon(Icons.rule), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('planned-principle')))
            .data,
        d.principle(AppLang.en),
      );
    });

    test('fields and buttons use the theme radius token (12 dp)', () {
      for (final b in [Brightness.light, Brightness.dark]) {
        final t = buildHumanOsTheme(b);
        final r = BorderRadius.circular(12);
        expect(
          (t.inputDecorationTheme.border! as OutlineInputBorder).borderRadius,
          r,
        );
        expect(
          (t.inputDecorationTheme.focusedBorder! as OutlineInputBorder)
              .borderRadius,
          r,
        );
        final filled = t.filledButtonTheme.style!.shape!.resolve({})!;
        expect((filled as RoundedRectangleBorder).borderRadius, r);
        final outlined = t.outlinedButtonTheme.style!.shape!.resolve({})!;
        expect((outlined as RoundedRectangleBorder).borderRadius, r);
      }
    });
  });
}
