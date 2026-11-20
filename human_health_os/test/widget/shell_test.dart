// F001 acceptance (v0.27 doc 209; v0.31 §17/§39 AC-5): app starts, responsive
// shell renders, Today shown, Today → Timeline → Labs, non-production profile
// and build identity visible.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/config/app_config.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'about_helper.dart';

const devConfig = AppConfig(
  profile: BuildProfile.development,
  version: '0.1.0+1',
  sourceRevision: 'test',
);

Future<void> pumpApp(
  WidgetTester tester, {
  required Size size,
  AppConfig config = devConfig,
  HostPlatform platform = HostPlatform.web,
  Locale? locale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (locale != null) {
    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
  final repo = inMemoryRepository();
  await repo.open();
  final services = await servicesFor(config, platform, repo);
  await tester.pumpWidget(HumanOsApp(services: services));
  await tester.pumpAndSettle();
}

const phone = Size(390, 844);
const tablet = Size(820, 1180);
const desktop = Size(1440, 900);
const laptop = Size(1024, 700);

/// Tall enough for the whole of Today and of About: a lazy list builds only
/// what is on screen.
const desktopTall = Size(1440, 4000);

void main() {
  group('starts on Today', () {
    for (final size in [phone, tablet, laptop, desktop]) {
      testWidgets('at ${size.width.toInt()}×${size.height.toInt()}', (
        tester,
      ) async {
        await pumpApp(tester, size: size);
        expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
        expect(find.text('Human OS'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('phone uses bottom bar, desktop uses rail (responsive)', (
    tester,
  ) async {
    await pumpApp(tester, size: phone);
    expect(find.byKey(const ValueKey('nav-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-rail')), findsNothing);

    await pumpApp(tester, size: desktop);
    expect(find.byKey(const ValueKey('nav-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-bar')), findsNothing);
    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('nav-rail')),
    );
    expect(rail.extended, isTrue);
    // v0.32 F001: exactly Today, Timeline, Labs are primary (C-8).
    expect(rail.destinations, hasLength(kPrimaryDestinations.length));
    expect(
      find.byKey(const ValueKey('rail-planned-group')),
      findsOneWidget,
      reason: 'planned areas are a separate, labelled group',
    );
  });

  testWidgets('phone: navigate Today → Labs', (tester) async {
    await pumpApp(tester, size: phone);
    await tester.tap(find.text('Labs'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-labs')), findsOneWidget);
    expect(find.byKey(const ValueKey('screen-today')), findsNothing);
    expect(
      find.textContaining('A reference range describes a reference group'),
      findsOneWidget,
    );
  });

  // R023: outside reference ≠ critical means "not automatically critical";
  // a critical value is outside the range too, so the promise never says a
  // result outside the range is never an emergency.
  test('the Labs promise says outside the range is not, by itself, an '
      'emergency (EN/TR exact)', () {
    final labs = destinations.firstWhere((d) => d.id == DestinationId.labs);
    expect(
      labs.principleEn,
      'A reference range describes a reference group; it is not necessarily '
      'the best value for you, and not a limit for a medical decision. A '
      'result outside the range is not, by itself, an emergency.',
    );
    expect(
      labs.principleTr,
      'Referans aralığı bir referans grubunu tanımlar; senin için en iyi '
      'değer olmak zorunda değildir, tıbbi bir karar sınırı da değildir. '
      'Aralığın dışında kalan bir sonuç tek başına acil durum demek değildir.',
    );
    expect(labs.principleEn, isNot(contains('is not an emergency')));
    expect(labs.principleTr, contains('tek başına'));
  });

  testWidgets('desktop: navigate Today → Labs via rail', (tester) async {
    await pumpApp(tester, size: desktop);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('nav-rail')),
        matching: find.text('Labs'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-labs')), findsOneWidget);
  });

  // v0.31 F001: Today → Timeline → Labs on both navigation forms.
  Future<void> visit(
    WidgetTester tester,
    String label, {
    Finder? within,
  }) async {
    final target = find.text(label);
    await tester.tap(
      within == null ? target : find.descendant(of: within, matching: target),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone: Today → Timeline → Labs (bottom bar)', (tester) async {
    await pumpApp(tester, size: phone);
    expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-bar')), findsOneWidget);
    await visit(tester, 'Timeline');
    expect(find.byKey(const ValueKey('screen-timeline')), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-empty')), findsOneWidget);
    await visit(tester, 'Labs');
    expect(find.byKey(const ValueKey('screen-labs')), findsOneWidget);
    expect(find.byKey(const ValueKey('screen-timeline')), findsNothing);
    // The header is lazy (U031-S4); on a phone the longer promise (R023)
    // can put the note just past the first build.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('labs-no-interpretation')),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('screen-labs')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const ValueKey('labs-no-interpretation')),
      findsOneWidget,
    );
  });

  testWidgets('desktop: Today → Timeline → Labs (rail)', (tester) async {
    await pumpApp(tester, size: desktop);
    final rail = find.byKey(const ValueKey('nav-rail'));
    await visit(tester, 'Timeline', within: rail);
    expect(find.byKey(const ValueKey('screen-timeline')), findsOneWidget);
    await visit(tester, 'Labs', within: rail);
    expect(find.byKey(const ValueKey('screen-labs')), findsOneWidget);
    await visit(tester, 'Today', within: rail);
    expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
  });

  testWidgets('This build shows the build identity it was given', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: desktopTall,
      config: const AppConfig(
        profile: BuildProfile.development,
        version: '0.1.0+1',
        sourceRevision: 'abc',
        flutterVersion: '3.47.6',
        dartVersion: '3.13.5',
      ),
    );
    // In Settings → About since U032.
    await openAbout(tester);
    expect(find.text('3.47.6'), findsOneWidget);
    expect(find.text('3.13.5'), findsOneWidget);
    expect(find.text('Record schema'), findsOneWidget);
    expect(find.text('v16'), findsOneWidget);
  });

  testWidgets(
    'build identity that was not passed reads "unknown", not a guess',
    (tester) async {
      await pumpApp(tester, size: desktopTall);
      await openAbout(tester);
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      // Flutter and Dart versions were not passed to devConfig.
      expect(find.text('unknown'), findsNWidgets(2));
    },
  );

  testWidgets('phone: "More" reaches every non-primary destination', (
    tester,
  ) async {
    await pumpApp(tester, size: phone);
    for (final d in plannedDestinations) {
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('more-sheet')),
          matching: find.text(d.en),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('screen-${d.id.name}')),
        findsOneWidget,
        reason: d.en,
      );
    }
  });

  testWidgets('every destination is reachable on desktop and none is blank', (
    tester,
  ) async {
    await pumpApp(tester, size: desktopTall);
    for (final d in destinations) {
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('nav-rail')),
          matching: find.text(d.en),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('screen-${d.id.name}')), findsOneWidget);
      if (d.plannedForge != null) {
        if (d.id == DestinationId.today) {
          // Today's built part is the weight card; its empty state is
          // specific. The not-built missions line and its "Planned" chip
          // are gone (U032): Today shows the person's own things.
          expect(find.text('Planned for a later version'), findsNothing);
          expect(find.byKey(const ValueKey('weight-empty')), findsOneWidget);
          continue;
        }
        // Honest empty state: says it is planned (no Forge id), shows no fake data.
        expect(find.text('Planned for a later version'), findsOneWidget);
        if (d.emptyStateEn != null) {
          // Records of this kind can exist elsewhere: never claim "none".
          expect(find.text(d.emptyStateEn!), findsOneWidget);
          expect(find.text('No records yet'), findsNothing);
        } else {
          expect(find.text('No records yet'), findsOneWidget);
        }
      }
    }
  });

  testWidgets('non-production build shows its profile banner', (tester) async {
    await pumpApp(tester, size: phone);
    expect(find.byKey(const ValueKey('build-profile-banner')), findsOneWidget);
    expect(find.textContaining('DEVELOPMENT BUILD'), findsOneWidget);
  });

  testWidgets('staging build shows its banner with the clinical disclaimer', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: phone,
      config: const AppConfig(
        profile: BuildProfile.staging,
        version: '0.1.0+1',
        sourceRevision: 'x',
      ),
    );
    expect(find.textContaining('STAGING BUILD'), findsOneWidget);
    expect(find.textContaining('Not for clinical decisions'), findsOneWidget);
  });

  testWidgets('About: the This build card shows the source revision', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: desktopTall,
      config: const AppConfig(
        profile: BuildProfile.development,
        version: '0.1.0+1',
        sourceRevision: '0123456789abcdef0123',
      ),
    );
    await openAbout(tester);
    expect(find.text('0123456789ab'), findsOneWidget);
  });

  testWidgets('production build hides the banner', (tester) async {
    await pumpApp(
      tester,
      size: phone,
      config: const AppConfig(
        profile: BuildProfile.production,
        version: '1.0.0+1',
        sourceRevision: 'x',
      ),
    );
    expect(find.byKey(const ValueKey('build-profile-banner')), findsNothing);
  });

  testWidgets(
    'Today states no weight yet, memory-only storage, network not required',
    (tester) async {
      await pumpApp(tester, size: desktopTall);
      expect(find.byKey(const ValueKey('weight-empty')), findsOneWidget);
      expect(
        find.textContaining('Not saved: kept only until the app closes'),
        findsOneWidget,
      );
      // The capability list lives in Settings → About (U032).
      await openAbout(tester);
      expect(find.text('Not required'), findsOneWidget);
      // No capability is claimed as available before its adapter exists.
      expect(find.text('Available'), findsNothing);
    },
  );

  testWidgets('web registry never claims HealthKit/Health Connect', (
    tester,
  ) async {
    await pumpApp(tester, size: desktopTall, platform: HostPlatform.web);
    await openAbout(tester);
    expect(find.text('Health Connect'), findsNothing);
    expect(find.text('Apple Health (HealthKit)'), findsNothing);
    expect(find.text('Not on this platform'), findsOneWidget);
  });

  testWidgets('Turkish locale localizes navigation', (tester) async {
    await pumpApp(tester, size: desktop, locale: const Locale('tr'));
    expect(find.text('Bugün'), findsWidgets);
    expect(find.text('Tahliller'), findsWidgets);
  });

  testWidgets(
    'section headings are separate semantics nodes (not merged with body)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, size: desktop);
      final node = tester.getSemantics(find.text('Body weight'));
      expect(node.label, 'Body weight');
      expect(node.flagsCollection.isHeader, isTrue);
      handle.dispose();
    },
  );

  testWidgets('Turkish phone layout renders without overflow', (tester) async {
    await pumpApp(
      tester,
      size: const Size(320, 640),
      locale: const Locale('tr'),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('GELİŞTİRME SÜRÜMÜ'), findsOneWidget);
    await tester.tap(find.text('Tahliller'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('screen-labs')), findsOneWidget);
  });

  // Q001 screen matrix: on a 1180-wide tablet the compact rail made "Learn"
  // a 38 dp wide target (38×50 in Chromium). Every rail item, in both
  // languages, is at least 48×48.
  for (final locale in const [Locale('en'), Locale('tr')]) {
    testWidgets('compact rail items are at least 48×48 '
        '(${locale.languageCode})', (tester) async {
      // The test font draws every glyph as wide as it is tall, wider than
      // a real font; half-size text gives "Learn" its real-world width.
      tester.platformDispatcher.textScaleFactorTestValue = 0.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, size: const Size(1180, 820), locale: locale);
      final rail = tester.widget<NavigationRail>(
        find.byKey(const ValueKey('nav-rail')),
      );
      expect(rail.extended, isFalse);
      final items = [
        for (final d in plannedDestinations)
          find.byKey(ValueKey('rail-planned-${d.id.name}')),
        find.byKey(const ValueKey('rail-settings')),
      ];
      for (final item in items) {
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        final size = tester.getSize(item);
        expect(size.width, greaterThanOrEqualTo(48), reason: '$item $size');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$item $size');
      }
    });
  }
}
