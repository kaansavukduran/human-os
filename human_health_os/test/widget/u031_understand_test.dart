// U031-S3: understandable with no prior knowledge. Every area says what it
// is, what you can do there and what the app never does (closed once, it
// stays closed); words open the glossary; empty Labs and Timeline name the
// first step with Aion; reading is said in words; a saved measurement
// offers "Show on Timeline". Nothing praises, scores or judges.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/appearance_scope.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/guide/glossary.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/profile/profile.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/features/labs/labs_screen.dart';
import 'package:human_health_os/src/features/timeline/timeline_screen.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f004_labs_test.dart' show interpretive, judged;
import 'f007_measurements_test.dart' show dev, launch, saveBp, settle, tapKey;

/// Words that would turn health into a game or a verdict (EN and TR).
final RegExp gamified = RegExp(
  r'(?<!\p{L})(score\p{L}*|streak\p{L}*|xp|points?|level up|badge\p{L}*|'
  r'great job|well done|good job|awesome|amazing|congrat\p{L}*|bravo|'
  r'healthy|unhealthy|normal|abnormal|risk\p{L}*|puan\p{L}*|seri|rozet\p{L}*|'
  r'harika|aferin|tebrik\p{L}*|sağlıklı|sağlıksız|anormal)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

const areas = [
  DestinationId.timeline,
  DestinationId.labs,
  DestinationId.medications,
  DestinationId.nutrition,
  DestinationId.activity,
  DestinationId.conditions,
  DestinationId.preventive,
  DestinationId.documents,
];

/// A store whose reads wait for [gate]: the first read is still running.
class GatedRepository implements HealthRepository {
  GatedRepository(this.inner);

  final HealthRepository inner;
  final gate = Completer<void>();

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
  Future<List<HealthRecord>> records(
    String profileId, {
    RecordKind? kind,
  }) async {
    await gate.future;
    return inner.records(profileId, kind: kind);
  }
}

Future<AppServices> services(WidgetTester tester) async {
  final s = await tester.runAsync(() async {
    final repo = LogRepository(
      sink: MemoryLogSink(),
      durability: StorageDurability.localFile,
      location: 'test',
    );
    final report = await repo.open();
    return servicesFor(dev, HostPlatform.linux, repo, report: report);
  });
  return s!;
}

void view(
  WidgetTester tester, {
  Size size = const Size(1280, 3200),
  double textScale = 1.0,
  Locale? locale,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (locale != null) {
    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
}

/// Opens [id] from the rail (wide) or the bottom bar and its More sheet.
Future<void> openArea(WidgetTester tester, DestinationId id, AppLang l) async {
  final d = destinationById(id);
  final rail = find.byKey(const ValueKey('nav-rail'));
  if (rail.evaluate().isNotEmpty) {
    if (d.isPrimary) {
      await tester.tap(
        find.descendant(of: rail, matching: find.text(d.label(l))),
      );
      await settle(tester);
    } else {
      await tapKey(tester, 'rail-planned-${id.name}');
    }
    return;
  }
  final bar = find.byKey(const ValueKey('nav-bar'));
  await tester.tap(find.descendant(of: bar, matching: find.text(d.label(l))));
  await settle(tester);
}

void expectIntroOpen(DestinationId id) {
  for (final part in ['what', 'can', 'never']) {
    expect(
      find.byKey(ValueKey('area-$part-${id.name}')),
      findsOneWidget,
      reason: '${id.name}: $part',
    );
  }
}

void main() {
  testWidgets('every area shows what it is, what you can do and what the '
      'app never does; closed once, it stays closed after a reload', (
    tester,
  ) async {
    view(tester);
    final s = await services(tester);
    final store = MemoryAppearanceStore();
    await tester.pumpWidget(
      HumanOsApp(services: s, appearance: AppearanceController(store)),
    );
    await settle(tester);
    for (final id in areas) {
      await openArea(tester, id, AppLang.en);
      expect(find.byKey(ValueKey('screen-${id.name}')), findsOneWidget);
      expectIntroOpen(id);
      final d = destinationById(id);
      expect(find.text(d.canDoEn), findsOneWidget, reason: id.name);
      expect(find.text(d.principleEn), findsOneWidget, reason: id.name);
      expect(find.text('What this is'), findsOneWidget);
      expect(find.text('What you can do here'), findsOneWidget);
      expect(find.text('What the app never does'), findsOneWidget);
    }

    await openArea(tester, DestinationId.timeline, AppLang.en);
    // The screen title stays the heading.
    final handle = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(
            find.descendant(
              of: find.byKey(const ValueKey('area-intro-timeline')),
              matching: find.text('Timeline'),
            ),
          )
          .flagsCollection
          .isHeader,
      isTrue,
    );
    handle.dispose();
    await tapKey(tester, 'area-intro-close-timeline');
    expect(find.byKey(const ValueKey('area-what-timeline')), findsNothing);
    expect(
      find.byKey(const ValueKey('area-intro-show-timeline')),
      findsOneWidget,
    );
    expect(store.saved?.explainedAreas, {'timeline'});

    // A new start reads the saved settings: still closed there, open on Labs.
    final again = await tester.runAsync(store.load);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      HumanOsApp(
        services: await services(tester),
        appearance: AppearanceController(store, again!),
      ),
    );
    await settle(tester);
    await openArea(tester, DestinationId.timeline, AppLang.en);
    expect(find.byKey(const ValueKey('area-what-timeline')), findsNothing);
    await openArea(tester, DestinationId.labs, AppLang.en);
    expectIntroOpen(DestinationId.labs);

    // It opens again with one tap.
    await openArea(tester, DestinationId.timeline, AppLang.en);
    await tapKey(tester, 'area-intro-show-timeline');
    expectIntroOpen(DestinationId.timeline);
    expect(store.saved?.explainedAreas, isEmpty);
  });

  test('explainedAreas: old JSON loads empty; saved, compared, kept by '
      'Reset Today', () {
    final old = AppearanceSettings.fromJson({
      'format': 'hhos.appearance',
      'version': 1,
      'language': 'tr',
    });
    expect(old.explainedAreas, isEmpty);
    expect(old.language, LanguageChoice.tr);
    final closed = old.explain('labs', closed: true);
    expect(closed.explainedAreas, {'labs'});
    expect(closed == old, isFalse);
    expect(closed.toJson()['explainedAreas'], ['labs']);
    final back = AppearanceSettings.fromJson(closed.toJson());
    expect(back, closed);
    expect(back.hashCode, closed.hashCode);
    expect(closed.resetToday().explainedAreas, {'labs'});
    expect(closed.copyWith(padOpen: true).explainedAreas, {'labs'});
    expect(closed.explain('labs', closed: false).explainedAreas, isEmpty);
    expect(identical(closed.explain('labs', closed: true), closed), isTrue);
    expect(
      AppearanceSettings.fromJson({
        'explainedAreas': ['labs', 3, null],
      }).explainedAreas,
      {'labs'},
    );
  });

  testWidgets('a term opens its glossary entry in a short sheet, and "Open '
      'in glossary" opens the whole entry', (tester) async {
    view(tester);
    await services(tester)
        .then((s) => tester.pumpWidget(HumanOsApp(services: s)));
    await settle(tester);
    await openArea(tester, DestinationId.labs, AppLang.en);
    for (final id in ['reference_interval', 'flag', 'unit']) {
      expect(find.byKey(ValueKey('term-$id')), findsOneWidget, reason: id);
    }
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('term-reference_interval')),
      ),
      matchesSemantics(
        label: 'What is Reference interval?',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
    // The link is not told by underline alone: a help icon goes with it.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('term-reference_interval')),
        matching: find.byIcon(Icons.help_outline),
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'term-reference_interval');
    final entry = glossaryById('reference_interval')!;
    expect(
      find.byKey(const ValueKey('term-sheet-reference_interval')),
      findsOneWidget,
    );
    expect(find.text(entry.what.$1), findsOneWidget);
    await tapKey(tester, 'term-open-reference_interval');
    expect(
      find.byKey(const ValueKey('screen-glossary-reference_interval')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('term-sheet-reference_interval')),
      findsNothing,
    );
    await tester.pageBack();
    await settle(tester);

    // The unit entry shows its explanation; Timeline explains "correction".
    await openArea(tester, DestinationId.timeline, AppLang.en);
    await tapKey(tester, 'term-correction');
    expect(find.text(glossaryById('correction')!.what.$1), findsOneWidget);
    await tapKey(tester, 'term-open-correction');
    expect(
      find.byKey(const ValueKey('screen-glossary-correction')),
      findsOneWidget,
    );
    expect(glossaryById('no-such-term'), isNull);
  });

  testWidgets('empty Labs and Timeline show Aion, one sentence and one action '
      'that works', (tester) async {
    view(tester);
    final s = await services(tester);
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    await openArea(tester, DestinationId.labs, AppLang.en);
    final labsEmpty = find.byKey(const ValueKey('labs-empty'));
    expect(
      find.descendant(
        of: labsEmpty,
        matching: find.byKey(const ValueKey('aion')),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Type one result exactly as your report prints it.'),
      findsOneWidget,
    );
    await tapKey(tester, 'labs-empty-add');
    expect(find.byKey(const ValueKey('lab-form')), findsOneWidget);
    await tapKey(tester, 'lab-cancel');

    await openArea(tester, DestinationId.timeline, AppLang.en);
    final timelineEmpty = find.byKey(const ValueKey('timeline-empty'));
    expect(
      find.descendant(
        of: timelineEmpty,
        matching: find.byKey(const ValueKey('aion')),
      ),
      findsOneWidget,
    );
    expect(
      find.text('What you save on Today appears here, newest first.'),
      findsOneWidget,
    );
    await tapKey(tester, 'timeline-go-today');
    expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
    expect(find.byKey(const ValueKey('screen-timeline')), findsNothing);
  });

  for (final (id, build) in <(String, Widget Function(AppServices))>[
    ('labs', (s) => LabsScreen(services: s)),
    ('timeline', (s) => TimelineScreen(services: s)),
  ]) {
    testWidgets('$id: while the first read runs, "Opening your records…" '
        'shows, never the empty state', (tester) async {
      view(tester);
      final out = await tester.runAsync(() async {
        final repo = GatedRepository(inMemoryRepository());
        await repo.open();
        return (await servicesFor(dev, HostPlatform.linux, repo), repo);
      });
      final (s, repo) = out!;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: build(s))));
      await tester.pump();
      final line = find.byKey(const ValueKey('loading-line'));
      expect(line, findsOneWidget);
      expect(tester.widget<Text>(line).data, 'Opening your records…');
      expect(find.byKey(ValueKey('$id-empty')), findsNothing);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(
          find.ancestor(of: line, matching: find.byType(Semantics)).first,
        ),
        matchesSemantics(label: 'Opening your records…', isLiveRegion: true),
      );
      handle.dispose();
      repo.gate.complete();
      await settle(tester);
      expect(line, findsNothing);
      expect(find.byKey(ValueKey('$id-empty')), findsOneWidget);
    });
  }

  test('loading words, EN and TR', () {
    expect(S(AppLang.en).loadingRecords, 'Opening your records…');
    expect(S(AppLang.tr).loadingRecords, 'Kayıtların açılıyor…');
    expect(S(AppLang.en).showOnTimeline, 'Show on Timeline');
    expect(S(AppLang.tr).showOnTimeline, 'Zaman çizelgesinde göster');
    expect(S(AppLang.tr).areaWhatThis, 'Bu ne?');
    expect(S(AppLang.tr).areaCanDo, 'Burada ne yapabilirsin?');
    expect(S(AppLang.tr).areaNever, 'Uygulama asla ne yapmaz?');
  });

  testWidgets('after a saved measurement, "Show on Timeline" opens the '
      'Timeline', (tester) async {
    await launch(tester);
    await saveBp(tester, '118', '76');
    expect(find.byKey(const ValueKey('measure-saved')), findsOneWidget);
    await tapKey(tester, 'measure-show-timeline');
    expect(find.byKey(const ValueKey('screen-timeline')), findsOneWidget);
    expect(find.byKey(const ValueKey('measure-saved')), findsNothing);
    expect(find.textContaining('118/76'), findsWidgets);
  });

  testWidgets('Aion\'s line is one of six, the same all day, and hidden with '
      'Aion', (tester) async {
    for (final lang in AppLang.values) {
      final lines = S(lang).aionLines;
      expect(lines, hasLength(6));
      expect(lines.toSet(), hasLength(6));
      final day = DateTime(2026, 3, 1, 8);
      expect(
        S(lang).aionLine(day),
        S(lang).aionLine(DateTime(2026, 3, 1, 23, 59)),
      );
      expect({
        for (var d = 0; d < 6; d++)
          S(lang).aionLine(DateTime(2026).add(Duration(days: d))),
      }, lines.toSet());
    }
    view(tester, size: const Size(1280, 2400));
    final s = await services(tester);
    final c = AppearanceController(MemoryAppearanceStore());
    await tester.pumpWidget(
      HumanOsApp(services: s, appearance: c, offerFirstRun: true),
    );
    await settle(tester);
    final line = find.byKey(const ValueKey('aion-line'));
    expect(line, findsOneWidget);
    expect(S(AppLang.en).aionLines, contains(tester.widget<Text>(line).data));
    await tester.runAsync(() => c.update(c.value.copyWith(showAion: false)));
    await tester.pumpAndSettle();
    expect(line, findsNothing);
  });

  test('every new word is plain: no score, streak, praise or verdict '
      '(EN and TR)', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      for (final w in [
        ...s.aionLines,
        s.areaWhatThis,
        s.areaCanDo,
        s.areaNever,
        s.areaClose,
        s.areaShow,
        s.termsHere,
        s.termWhat('x'),
        s.termOpenGlossary,
        s.loadingRecords,
        s.labsFirstStep,
        s.timelineFirstStep,
        s.goToToday,
        s.showOnTimeline,
        for (final d in destinations) d.canDo(lang),
      ]) {
        expect(gamified.hasMatch(w), isFalse, reason: w);
        expect(interpretive.hasMatch(w), isFalse, reason: w);
        expect(judged.hasMatch(w), isFalse, reason: w);
        expect(RegExp(r'\d').hasMatch(w), isFalse, reason: 'no number: $w');
      }
    }
  });

  for (final locale in [const Locale('en'), const Locale('tr')]) {
    testWidgets('320 dp, text ×2, ${locale.languageCode}: the Labs and '
        'Timeline introductions lay out without overflow', (tester) async {
      view(tester, size: const Size(320, 2400), textScale: 2.0, locale: locale);
      final s = await services(tester);
      await tester.pumpWidget(HumanOsApp(services: s));
      await settle(tester);
      final lang = locale.languageCode == 'tr' ? AppLang.tr : AppLang.en;
      for (final id in [DestinationId.labs, DestinationId.timeline]) {
        await openArea(tester, id, lang);
        expectIntroOpen(id);
        expect(tester.takeException(), isNull, reason: id.name);
        await tapKey(tester, 'area-intro-close-${id.name}');
        expect(tester.takeException(), isNull, reason: '${id.name} closed');
        await tapKey(tester, 'area-intro-show-${id.name}');
        expect(tester.takeException(), isNull, reason: '${id.name} open');
      }
      await tapKey(tester, 'term-correction');
      expect(tester.takeException(), isNull, reason: 'term sheet');
    });
  }
}
