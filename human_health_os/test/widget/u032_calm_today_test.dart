// U032 (A002 audit): Today ends with the person's own things. The build
// facts (version, source revision, Flutter and Dart, record schema, build
// profile, platform) and the capability list live in Settings → About
// Human OS; the not-built "Daily missions" line is gone.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/config/app_config.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import 'about_helper.dart';
import 'shell_test.dart' show pumpApp, desktopTall;

const _config = AppConfig(
  profile: BuildProfile.development,
  version: '9.8.7+6',
  sourceRevision: 'abcdef0123456789abcdef0123456789abcdef01',
  flutterVersion: '3.47.6',
  dartVersion: '3.13.5',
);

Finder _todayScroll() => find
    .descendant(
      of: find.byKey(const ValueKey('screen-today')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _toEndOfToday(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.drag(_todayScroll(), const Offset(0, -500));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Every fact About must show, in [s]'s language.
List<String> _facts(S s) {
  final reg = CapabilityRegistry.forPlatform(HostPlatform.web);
  return [
    s.thisBuild,
    s.profile,
    s.profileName(BuildProfile.development),
    s.version,
    _config.version,
    s.platform,
    'web',
    s.sourceRevision,
    _config.shortRevision,
    s.flutterVersion,
    _config.flutterVersion,
    s.dartVersion,
    _config.dartVersion,
    s.recordSchema,
    'v${HealthRecord.currentSchemaVersion}',
    s.capabilities,
    for (final c in reg.capabilities) s.capText(c.label),
  ];
}

void main() {
  for (final (lang, locale) in [
    (AppLang.en, const Locale('en')),
    (AppLang.tr, const Locale('tr')),
  ]) {
    final s = S(lang);

    testWidgets('$lang: Today shows no version, schema, capability or '
        'missions text, and ends with the person\'s own things', (
      tester,
    ) async {
      await pumpApp(tester, size: desktopTall, config: _config, locale: locale);
      await _toEndOfToday(tester);
      for (final t in [
        s.thisBuild,
        s.version,
        s.sourceRevision,
        s.flutterVersion,
        s.dartVersion,
        s.recordSchema,
        s.capabilities,
        s.notImplemented,
        _config.version,
        _config.shortRevision,
        'v${HealthRecord.currentSchemaVersion}',
      ]) {
        expect(find.text(t), findsNothing, reason: '$lang Today: "$t"');
      }
      expect(
        find.textContaining(RegExp('mission|görev', caseSensitive: false)),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('today-planned')), findsNothing);
      // The development banner stays: it is a safety label.
      expect(find.byKey(const ValueKey('build-profile-banner')), findsOne);
      // Today's last section is Your data or the discovery card.
      final yourData = find.byKey(const ValueKey('today-card-your-data'));
      expect(yourData, findsOneWidget);
      expect(find.byKey(const ValueKey('tool-genetics')), findsOneWidget);
      expect(
        tester.getTopLeft(yourData).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('tool-genetics'))).dy,
        ),
        reason: 'order unchanged: tools, then Your data',
      );
    });

    testWidgets('$lang: Settings → About shows every build fact and the '
        'capability list', (tester) async {
      await pumpApp(tester, size: desktopTall, config: _config, locale: locale);
      await openAbout(tester);
      expect(find.text(s.aboutTitle), findsWidgets);
      for (final t in _facts(s)) {
        await scrollAboutTo(tester, find.text(t));
        expect(find.text(t), findsWidgets, reason: '$lang About: "$t"');
      }
      expect(find.text(s.notImplemented), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$lang: About at 320 dp with 2x text: nothing overflows', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        tester,
        size: const Size(320, 640),
        config: _config,
        locale: locale,
      );
      await openAbout(tester);
      for (final t in _facts(s)) {
        await scrollAboutTo(tester, find.text(t));
        expect(tester.takeException(), isNull, reason: '$lang 320/2x: "$t"');
      }
    });
  }

  test('About strings (EN, TR)', () {
    expect(S(AppLang.en).aboutTitle, 'About Human OS');
    expect(S(AppLang.tr).aboutTitle, 'Human OS hakkında');
  });

  testWidgets('About opens from Settings with the mouse', (tester) async {
    await pumpApp(tester, size: desktopTall, config: _config);
    await tester.tap(
      find.byKey(const ValueKey('open-settings')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-about'));
    await tester.scrollUntilVisible(
      row,
      400,
      maxScrolls: 200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('screen-settings')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(row, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-about')), findsOneWidget);
    expect(find.text(_config.flutterVersion), findsOneWidget);
  });

  testWidgets('About opens from Settings with the keyboard (Tab, Enter)', (
    tester,
  ) async {
    await pumpApp(tester, size: desktopTall, config: _config);
    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-about'));
    bool rowFocused() {
      final ctx = FocusManager.instance.primaryFocus?.context;
      // The list builds the row once Tab has scrolled near it.
      if (ctx == null || row.evaluate().isEmpty) return false;
      final rowElement = row.evaluate().single;
      var found = false;
      ctx.visitAncestorElements((e) {
        if (e == rowElement) found = true;
        return !found;
      });
      return found || ctx == rowElement;
    }

    var tabs = 0;
    while (!rowFocused() && tabs < 400) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      tabs++;
    }
    expect(rowFocused(), isTrue, reason: 'the About row is reached by Tab');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-about')), findsOneWidget);
    expect(find.text(_config.flutterVersion), findsOneWidget);
  });
}
