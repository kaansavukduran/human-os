// U031-S2: Lexend, the face of the owner's YKSmania app, as an optional
// reading font, bundled (no runtime fetch), licensed (OFL 1.1, D-042), with a
// Turkish letter preview of every font in Settings. The device font stays the
// default.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import 'f004_labs_test.dart' show interpretive, judged;
import 'f007_measurements_test.dart' show settle, tapKey;
import 'u005_settings_test.dart' show launchWith;

const sample = 'Çok güzel şiir: ğ ı İ ö ş ü';

TextStyle bodyOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byKey(const ValueKey('screen-settings'))))
        .textTheme
        .bodyMedium!;

void main() {
  test('lexend round-trips through the saved JSON', () {
    const s = AppearanceSettings(font: FontChoice.lexend);
    expect(s.toJson()['font'], 'lexend');
    expect(AppearanceSettings.fromJson(s.toJson()), s);
    expect(fontFamilyFor(FontChoice.lexend), 'Lexend');
  });

  test('a font this build does not know reads as the device font', () {
    // What an older build does with 'lexend', and this build with a newer one.
    for (final v in ['someFutureFont', '', 42, null]) {
      final a = AppearanceSettings.fromJson({'font': v, 'wideSpacing': true});
      expect(a.font, FontChoice.system, reason: '$v');
      expect(a.wideSpacing, isTrue, reason: 'other settings kept');
    }
  });

  test('a fresh install keeps the device font', () {
    expect(const AppearanceSettings().font, FontChoice.system);
    expect(AppearanceSettings.fromJson(null).font, FontChoice.system);
    expect(AppearanceSettings.fromJson(const {}).font, FontChoice.system);
    expect(fontFamilyFor(FontChoice.system), isNull);
  });

  testWidgets('a fresh app shows the device font', (tester) async {
    final c = await launchWith(tester);
    await tapKey(tester, 'open-settings');
    expect(c.value.font, FontChoice.system);
    expect(bodyOf(tester).fontFamily, isNot('Lexend'));
  });

  testWidgets('choosing Lexend sets the theme font at once', (tester) async {
    final c = await launchWith(tester);
    await tapKey(tester, 'open-settings');
    await tapKey(tester, 'set-font-lexend');
    expect(c.value.font, FontChoice.lexend);
    expect(bodyOf(tester).fontFamily, 'Lexend');
    final ctx = tester.element(find.byKey(const ValueKey('screen-settings')));
    expect(Theme.of(ctx).textTheme.titleSmall!.fontFamily, 'Lexend');
    await tapKey(tester, 'set-font-system');
    expect(bodyOf(tester).fontFamily, isNot('Lexend'));
  });

  test('Lexend loads from the bundled assets, offline', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final f in ['Lexend-Regular.ttf', 'Lexend-SemiBold.ttf']) {
      final data = await rootBundle.load('assets/fonts/$f');
      expect(data.lengthInBytes, greaterThan(50000), reason: f);
      final loader = FontLoader('LexendCheck-$f')..addFont(Future.value(data));
      await loader.load();
    }
  });

  test('the Lexend files are the reviewed ones (D-042) and the licence sits '
      'beside them', () {
    const expected = {
      'Lexend-Regular.ttf':
          '43d2da91ffd73aafca81056f938184e7d2f3352c1a4c092164e54347fcc9f41f',
      'Lexend-SemiBold.ttf':
          'e8d14c5d3d7a23f39ace22caa00f0e504ac28c71803d8d391fb554703213f816',
      'Lexend-OFL.txt':
          '5da8505887d0fa7fe963445fd58852707fda34adfeb65af25c99d152bab285bd',
    };
    expected.forEach((name, sha) {
      final bytes = File('assets/fonts/$name').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), sha, reason: name);
    });
    expect(
      File('assets/fonts/Lexend-OFL.txt').readAsStringSync(),
      contains('SIL Open Font License'),
    );
  });

  testWidgets('each font previews Turkish letters in itself', (tester) async {
    await launchWith(
      tester,
      initial: const AppearanceSettings(font: FontChoice.dyslexic),
    );
    await tapKey(tester, 'open-settings');
    for (final f in FontChoice.values) {
      final line = find.descendant(
        of: find.byKey(ValueKey('font-preview-${f.name}')),
        matching: find.text(sample),
      );
      expect(line, findsOneWidget, reason: f.name);
      final family = tester.widget<Text>(line).style?.fontFamily;
      if (f == FontChoice.system) {
        expect(family, isNot('OpenDyslexic'), reason: 'device line stays');
      } else {
        expect(family, fontFamilyFor(f), reason: f.name);
      }
    }
  });

  for (final lang in [LanguageChoice.en, LanguageChoice.tr]) {
    testWidgets('font chips and previews at 320 dp and 2x text '
        '(${lang.name}) do not overflow', (tester) async {
      await launchWith(
        tester,
        initial: AppearanceSettings(language: lang, font: FontChoice.lexend),
      );
      tester.view.physicalSize = const Size(320, 6000);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await settle(tester);
      await tapKey(tester, 'open-settings');
      for (final f in FontChoice.values) {
        for (final k in ['set-font-${f.name}', 'font-preview-${f.name}']) {
          final w = find.byKey(ValueKey(k));
          await tester.ensureVisible(w);
          await tester.pumpAndSettle();
          expect(w, findsOneWidget, reason: k);
          expect(tester.getRect(w).right, lessThanOrEqualTo(320), reason: k);
        }
      }
      final s = S(lang == LanguageChoice.tr ? AppLang.tr : AppLang.en);
      expect(find.text(s.fontLexend), findsOneWidget);
      expect(find.text(s.fontPreviewNote), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('the new font words judge nothing', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      for (final w in [s.fontLexend, s.fontPreviewNote]) {
        expect(interpretive.hasMatch(w), isFalse, reason: w);
        expect(judged.hasMatch(w), isFalse, reason: w);
      }
    }
  });
}
