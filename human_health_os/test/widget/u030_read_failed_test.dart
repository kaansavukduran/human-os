// U030 (AIONIA v1.2/v1.7): a failed read is said in words with Try again on
// every area, never a spinner forever or a blank card; Sleep and Feeling are
// never blank while reading; Today's build facts say only what is true;
// Labs shows results first with the form in a sheet; section titles are
// headings; Settings is not repeated on Today.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/config/app_config.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/backup/data_files.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/profile/profile.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/features/activity/activity_screen.dart';
import 'package:human_health_os/src/features/conditions/conditions_screen.dart';
import 'package:human_health_os/src/features/derived/derived_screen.dart';
import 'package:human_health_os/src/features/documents/documents_screen.dart';
import 'package:human_health_os/src/features/labs/labs_screen.dart';
import 'package:human_health_os/src/features/medications/medications_screen.dart';
import 'package:human_health_os/src/features/nutrition/nutrition_screen.dart';
import 'package:human_health_os/src/features/preventive/preventive_screen.dart';
import 'package:human_health_os/src/features/timeline/timeline_screen.dart';
import 'package:human_health_os/src/features/today/feeling_card.dart';
import 'package:human_health_os/src/features/today/sleep_card.dart';
import 'package:human_health_os/src/features/today/weight_card.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import 'f005_your_data_test.dart' as f005;

const dev = AppConfig(
  profile: BuildProfile.development,
  version: 't',
  sourceRevision: 't',
);

/// A store whose reads fail while [failReads] is set (a disk error, a lock);
/// writes and profiles go through.
class FlakyRepository implements HealthRepository {
  FlakyRepository(this.inner);

  final HealthRepository inner;
  bool failReads = false;
  int reads = 0;

  @override
  StorageDescription get description => inner.description;
  @override
  Future<LoadReport> open() => inner.open();
  @override
  bool get writable => inner.writable;
  @override
  Future<List<Profile>> profiles() => inner.profiles();
  @override
  Future<void> putProfile(Profile profile) => inner.putProfile(profile);
  @override
  Future<void> appendRecord(HealthRecord record) => inner.appendRecord(record);
  @override
  Future<List<HealthRecord>> records(String profileId, {RecordKind? kind}) {
    reads++;
    if (failReads) {
      return Future.error(StateError('the disk could not be read'));
    }
    return inner.records(profileId, kind: kind);
  }
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

Future<(AppServices, FlakyRepository)> boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final out = await tester.runAsync(() async {
    final repo = FlakyRepository(inMemoryRepository());
    await repo.open();
    return (await servicesFor(dev, HostPlatform.linux, repo), repo);
  });
  return out!;
}

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final areas = <(String, Widget Function(AppServices))>[
    ('cond', (s) => ConditionsScreen(services: s)),
    ('prev', (s) => PreventiveScreen(services: s)),
    ('doc', (s) => DocumentsScreen(services: s)),
    ('food', (s) => NutritionScreen(services: s)),
    ('act', (s) => ActivityScreen(services: s)),
    ('meds', (s) => MedicationsScreen(services: s)),
    ('timeline', (s) => TimelineScreen(services: s)),
    ('labs', (s) => LabsScreen(services: s)),
    ('derived', (s) => DerivedScreen(services: s)),
    ('weight', (s) => ListView(children: [WeightCard(services: s)])),
    ('sleep', (s) => ListView(children: [SleepCard(services: s)])),
    ('feel', (s) => ListView(children: [FeelingCard(services: s)])),
  ];

  for (final (id, build) in areas) {
    testWidgets('$id: a failed read is said in words, and Try again reads '
        'again', (tester) async {
      final (s, repo) = await boot(tester);
      repo.failReads = true;
      await tester.pumpWidget(host(build(s)));
      await settle(tester);
      final note = find.byKey(ValueKey('$id-read-failed'));
      expect(note, findsOneWidget);
      expect(
        tester.widget<Text>(note).data,
        'Your records could not be read just now. Nothing was changed.',
      );
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'never a spinner forever',
      );
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(note),
        matchesSemantics(
          label:
              'Your records could not be read just now. Nothing was changed.',
          isLiveRegion: true,
        ),
      );
      semantics.dispose();

      repo.failReads = false;
      final before = repo.reads;
      await tester.tap(find.byKey(ValueKey('$id-try-again')));
      await settle(tester);
      expect(repo.reads, greaterThan(before), reason: 'read again');
      expect(find.byKey(ValueKey('$id-read-failed')), findsNothing);
      expect(find.byKey(ValueKey('$id-try-again')), findsNothing);
    });
  }

  test('the shared words, EN and TR', () {
    expect(
      S(AppLang.en).readFailed,
      'Your records could not be read just now. Nothing was changed.',
    );
    expect(
      S(AppLang.tr).readFailed,
      'Kayıtların şu an okunamadı. Hiçbir şey değiştirilmedi.',
    );
    expect(S(AppLang.en).tryAgain, 'Try again');
    expect(S(AppLang.tr).tryAgain, 'Tekrar dene');
  });

  for (final (id, card) in <(String, Widget Function(AppServices))>[
    ('sleep', (s) => SleepCard(services: s)),
    ('feel', (s) => FeelingCard(services: s)),
  ]) {
    testWidgets('$id: never blank while reading, and no jump after', (
      tester,
    ) async {
      final (s, _) = await boot(tester);
      await tester.pumpWidget(host(ListView(children: [card(s)])));
      final cardKey = find.byKey(
        ValueKey(id == 'sleep' ? 'sleep-card' : 'feel-card'),
      );
      expect(
        find.descendant(
          of: cardKey,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'reading is shown, not a blank',
      );
      final reading = tester.getSize(cardKey).height;
      await settle(tester);
      expect(find.byKey(ValueKey('$id-none')), findsOneWidget);
      expect(tester.getSize(cardKey).height, reading, reason: 'no jump');
    });
  }

  test('Today build facts: only daily missions are not built (EN, TR)', () {
    expect(S(AppLang.en).dailyMissions, 'Daily missions: not built yet.');
    expect(S(AppLang.tr).dailyMissions, 'Günlük görevler: henüz yok.');
    for (final lang in AppLang.values) {
      final w = S(lang).dailyMissions.toLowerCase();
      expect(w.contains('check-in'), isFalse, reason: w);
      expect(w.contains('yoklama'), isFalse, reason: w);
    }
  });

  testWidgets('Today: the build fact is the true one, and Settings has no '
      'tile there (app bar and rail still open it)', (tester) async {
    final (s, _) = await boot(tester);
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    expect(
      find.text('Check-ins and daily missions: not built yet.'),
      findsNothing,
    );
    final fact = find.text('Daily missions: not built yet.');
    await tester.scrollUntilVisible(
      fact,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('screen-today')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(fact, findsOneWidget);
    expect(find.byKey(const ValueKey('tool-settings')), findsNothing);
    expect(find.byKey(const ValueKey('open-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('rail-settings')), findsOneWidget);
  });

  testWidgets('Labs: results come first; the form opens in a sheet from '
      '"Add a result" and its error is announced', (tester) async {
    final (s, _) = await boot(tester);
    await tester.runAsync(
      () => s.heartbeat.recordLab(
        profileId: s.self.id,
        input: const LabInput(
          analyte: 'TSH',
          value: '2',
          notReported: false,
          unit: 'mIU/L',
          sampleDate: '2026-10-01',
        ),
      ),
    );
    await tester.pumpWidget(host(LabsScreen(services: s)));
    await settle(tester);
    expect(find.byKey(const ValueKey('lab-form')), findsNothing);
    expect(find.byKey(const ValueKey('lab-analyte')), findsNothing);
    expect(find.text('TSH'), findsOneWidget);
    final add = find.byKey(const ValueKey('lab-add'));
    expect(
      find.descendant(of: add, matching: find.text('Add a result')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(add).dy,
      lessThan(tester.getTopLeft(find.text('TSH')).dy),
    );
    await tester.tap(add);
    await settle(tester);
    expect(find.byKey(const ValueKey('lab-form')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lab-save')));
    await settle(tester);
    final err = find.byKey(const ValueKey('lab-error'));
    expect(err, findsOneWidget, reason: 'an empty test name is refused');
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(err),
      matchesSemantics(
        label: tester.widget<Text>(err).data,
        isLiveRegion: true,
      ),
    );
    semantics.dispose();
    expect(S(AppLang.tr).labAdd, 'Sonuç ekle');
  });

  testWidgets('section titles are headings: weight History, Medications '
      'item, Timeline Versions', (tester) async {
    final (s, _) = await boot(tester);
    late HealthRecord w;
    await tester.runAsync(() async {
      w = await s.heartbeat.recordWeightKg(profileId: s.self.id, input: '80');
      await s.heartbeat.addMedication(
        profileId: s.self.id,
        name: 'Vitamin D',
        category: MedicationCategory.supplement,
      );
    });
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(ListView(children: [WeightCard(services: s)])),
    );
    await settle(tester);
    expect(
      tester.getSemantics(find.text('History')),
      matchesSemantics(label: 'History', isHeader: true),
    );

    await tester.pumpWidget(host(MedicationsScreen(services: s)));
    await settle(tester);
    final title =
        'Vitamin D · ${S(AppLang.en).medsCategoryLabel(MedicationCategory.supplement)}';
    expect(
      tester.getSemantics(find.text(title)),
      matchesSemantics(label: title, isHeader: true),
    );

    await tester.pumpWidget(host(TimelineScreen(services: s)));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('timeline-entry-${w.id}')));
    await settle(tester);
    expect(
      tester.getSemantics(find.text('Versions')),
      matchesSemantics(label: 'Versions', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('Your data: "Backups on this device" is a heading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await f005.start(tester, sink: MemoryLogSink(), files: MemoryDataFiles());
    final title = find.text(S(AppLang.en).backupsTitle);
    await tester.scrollUntilVisible(
      title,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('screen-today')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester.getSemantics(title),
      matchesSemantics(label: S(AppLang.en).backupsTitle, isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('phone: the More sheet shows every entry without scrolling '
      'inside it (AIONIA v1.7 §22)', (tester) async {
    final (s, _) = await boot(tester);
    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    await tester.tap(find.text('More'));
    await settle(tester);
    final sheet = find.byKey(const ValueKey('more-sheet'));
    final list = tester.state<ScrollableState>(
      find.descendant(of: sheet, matching: find.byType(Scrollable)).first,
    );
    expect(list.position.maxScrollExtent, 0, reason: 'no inner scroll');
    final entry = find.byKey(const ValueKey('more-settings'));
    expect(tester.getBottomLeft(entry).dy, lessThanOrEqualTo(900));
  });
}
