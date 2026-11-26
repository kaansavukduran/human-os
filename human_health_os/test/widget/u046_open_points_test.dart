// U046: the open points after the Q009 screen matrix
// (reports/runtime/screen-matrix/33af491f7bb0/Q009_REVIEW.md, "Seen, not a
// FAIL"). EN and TR; 320 dp at 1× and 2× text and a 1440x900 desktop where
// the layout matters. Each group fails on the code before U046.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/appearance_scope.dart';
import 'package:human_health_os/src/config/app_config.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/guide/body_guide.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/presentation/theme/spacing.dart';

import 'about_helper.dart';
import 'f007_measurements_test.dart' show settle, tapKey;
import 'u002_guide_test.dart' show reveal;
import 'u029_derived_test.dart' show record;
import 'u034_learn_test.dart' show openLearn, revealOnLearn;

const _langs = [
  (LanguageChoice.en, AppLang.en),
  (LanguageChoice.tr, AppLang.tr),
];

const _sizes = [
  (Size(320, 640), 1.0),
  (Size(320, 640), 2.0),
  (Size(1440, 900), 1.0),
];

String _name(Size size, double scale) =>
    '${size.width.toInt()}x${size.height.toInt()} ${scale}x';

/// Starts the app with [config] (the version facts), in [language], at
/// [size] and [textScale], with [appearance].
Future<AppServices> _launch(
  WidgetTester tester, {
  required LanguageChoice language,
  Size size = const Size(1280, 3200),
  double textScale = 1.0,
  AppConfig config = const AppConfig(
    profile: BuildProfile.development,
    version: 't',
    sourceRevision: 't',
  ),
  AppearanceSettings appearance = const AppearanceSettings(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final s = await tester.runAsync(() async {
    final repo = LogRepository(
      sink: MemoryLogSink(),
      durability: StorageDurability.localFile,
      location: 'test',
    );
    final report = await repo.open();
    return servicesFor(config, HostPlatform.linux, repo, report: report);
  });
  final c = AppearanceController(
    MemoryAppearanceStore(),
    appearance.copyWith(language: language),
  );
  await tester.pumpWidget(HumanOsApp(services: s!, appearance: c));
  await settle(tester);
  return s;
}

/// Every text drawn under [screen] (Text and rich text), scrolling its
/// lazy list from the top to the end so every item is built once.
Future<Set<String>> _texts(WidgetTester tester, String screen) async {
  final list = find
      .descendant(
        of: find.byKey(ValueKey(screen)),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(list).position;
  position.jumpTo(0);
  await tester.pumpAndSettle();
  final seen = <String>{};
  while (true) {
    for (final w in tester.widgetList<RichText>(
      find.descendant(
        of: find.byKey(ValueKey(screen)),
        matching: find.byType(RichText),
      ),
    )) {
      seen.add(w.text.toPlainText());
    }
    if (position.pixels >= position.maxScrollExtent) break;
    position.jumpTo(
      (position.pixels + 200).clamp(0.0, position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
  }
  position.jumpTo(0);
  await tester.pumpAndSettle();
  return seen;
}

Future<void> _openToday(WidgetTester tester, String key) async {
  await reveal(tester, 'screen-today', key);
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tapKey(tester, key);
}

void main() {
  group(
    '1. Derived: plain names, machine IDs only under Technical details',
    () {
      for (final (choice, lang) in _langs) {
        for (final (size, scale) in _sizes) {
          testWidgets('${lang.name}, ${_name(size, scale)}', (tester) async {
            final s = S(lang);
            final services = await _launch(
              tester,
              language: choice,
              size: size,
              textScale: scale,
            );
            await record(tester, services, kg: '80', heightCm: '180');
            await record(tester, services, waistCm: '90');
            await _openToday(tester, 'tool-derived');
            expect(
              find.byKey(const ValueKey('screen-derived')),
              findsOneWidget,
            );
            // Nothing drawn on the page shows a machine ID.
            final shown = await _texts(tester, 'screen-derived');
            for (final t in shown) {
              expect(t, isNot(contains('MP-CORE')), reason: t);
              expect(t, isNot(contains('DERIVED-')), reason: t);
            }
            // The formula set's version is still said, in words.
            expect(shown.where((t) => t.contains('1.0.0')), isNotEmpty);
            // The card titles are the plain names.
            expect(
              shown,
              containsAll([
                s.derivedModelName('DERIVED-BMI-1'),
                s.derivedModelName('DERIVED-WAIST_HEIGHT_RATIO-1'),
              ]),
            );
            // Model output stays marked as worked out, not measured.
            expect(shown, contains(s.derivedNotMeasured));
            // Technical details: the ID on its own line, never broken inside.
            const key = 'derived-DERIVED-WAIST_HEIGHT_RATIO-1';
            final details = find.descendant(
              of: find.byKey(const ValueKey('$key-model')),
              matching: find.text(s.derivedDetailsTitle),
            );
            await tester.scrollUntilVisible(
              details,
              200,
              scrollable: find
                  .descendant(
                    of: find.byKey(const ValueKey('screen-derived')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            await tester.tap(details);
            await tester.pumpAndSettle();
            for (final id in [
              'DERIVED-WAIST_HEIGHT_RATIO-1',
              'MP-CORE-DERIVED-1',
            ]) {
              final f = find.descendant(
                of: find.byKey(const ValueKey('$key-model')),
                matching: find.text(unbrokenId(id)),
              );
              expect(f, findsOneWidget);
              final p = tester.renderObject<RenderParagraph>(
                find.descendant(of: f, matching: find.byType(RichText)),
              );
              final lines = p.getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: unbrokenId(id).length,
                ),
              );
              final tops = {for (final b in lines) b.top.round()};
              expect(tops.length, 1, reason: '$id on one line');
            }
            expect(
              find.bySemanticsLabel(
                '${s.derivedModelIdLabel('1')}: DERIVED-WAIST_HEIGHT_RATIO-1',
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    },
  );

  group('2. Body guide: the parts are plain text, not chips', () {
    for (final (choice, lang) in _langs) {
      testWidgets(lang.name, (tester) async {
        final s = S(lang);
        await _launch(tester, language: choice, size: const Size(320, 640));
        await openLearn(tester);
        await revealOnLearn(tester, 'tool-guide');
        await tapKey(tester, 'tool-guide');
        await tapKey(tester, 'guide-system-heart');
        final screen = find.byKey(const ValueKey('screen-guide-heart'));
        expect(screen, findsOneWidget);
        final heart = bodySystems.firstWhere((b) => b.id == 'heart');
        expect(
          find.descendant(of: screen, matching: find.text(s.guideParts)),
          findsOneWidget,
        );
        final handle = tester.ensureSemantics();
        for (final p in heart.parts) {
          final label = lang == AppLang.tr ? p.$2 : p.$1;
          final f = find.descendant(of: screen, matching: find.text(label));
          await tester.ensureVisible(f.first);
          await tester.pumpAndSettle();
          expect(f, findsOneWidget, reason: label);
          // No ink, outline or button node around it.
          expect(
            find.ancestor(of: f, matching: find.byType(InkWell)),
            findsNothing,
            reason: label,
          );
          expect(
            find.ancestor(of: f, matching: find.byType(GestureDetector)),
            findsNothing,
            reason: label,
          );
          final node = tester.getSemantics(f);
          expect(node.label, contains(label));
          // ignore: deprecated_member_use
          expect(node.hasFlag(SemanticsFlag.isButton), isFalse, reason: label);
        }
        handle.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('3. Genetics and plant compounds sit in the reading column', () {
    for (final (choice, lang) in _langs) {
      for (final size in const [Size(1440, 900), Size(320, 640)]) {
        for (final (tool, screen) in const [
          ('tool-genetics', 'screen-genetics'),
          ('tool-phyto', 'screen-phyto'),
        ]) {
          testWidgets('$screen, ${lang.name}, ${size.width.toInt()} dp', (
            tester,
          ) async {
            final s = S(lang);
            await _launch(tester, language: choice, size: size);
            await _openToday(tester, tool);
            expect(find.byKey(ValueKey(screen)), findsOneWidget);
            final side = size.width > kReadingWidth
                ? (size.width - kReadingWidth) / 2
                : 0.0;
            final intro = find.text(
              screen == 'screen-genetics' ? s.geneticsIntro : s.phytoHow,
            );
            final r = tester.getRect(intro);
            expect(r.left, closeTo(side + 16, 0.5));
            expect(r.right, lessThanOrEqualTo(size.width - side - 16 + 0.5));
            // The list itself spans the window, so it scrolls anywhere.
            expect(
              tester.getRect(find.byKey(ValueKey(screen))).width,
              size.width,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('4. About: a version not passed to the build is said in the '
      'person\'s language', () {
    for (final (choice, lang) in _langs) {
      testWidgets(lang.name, (tester) async {
        await _launch(
          tester,
          language: choice,
          config: const AppConfig(
            profile: BuildProfile.development,
            version: 'unknown',
            sourceRevision: 'unknown',
          ),
        );
        await openAbout(tester);
        final word = lang == AppLang.tr ? 'bilinmiyor' : 'unknown';
        await scrollAboutTo(tester, find.text(word));
        final shown = await _texts(tester, 'screen-about');
        expect(shown, contains(word));
        if (lang == AppLang.tr) expect(shown, isNot(contains('unknown')));
        expect(tester.takeException(), isNull);
      });
    }
    test('a passed version is shown as it is', () {
      for (final lang in AppLang.values) {
        expect(S(lang).buildFact('0.32.0+1'), '0.32.0+1');
      }
    });
  });

  group('5. With a palette chosen, "Light or dark" says what it controls', () {
    for (final (choice, lang) in _langs) {
      for (final palette in PaletteChoice.values) {
        testWidgets('${lang.name}, ${palette.name}', (tester) async {
          final s = S(lang);
          await _launch(
            tester,
            language: choice,
            appearance: AppearanceSettings(
              palette: palette,
              theme: ThemeChoice.dark,
            ),
          );
          await tapKey(tester, 'open-settings');
          final note = find.byKey(const ValueKey('theme-palette-note'));
          if (palette == PaletteChoice.standard) {
            expect(note, findsNothing);
            return;
          }
          expect(note, findsOneWidget);
          final text = tester.widget<Text>(note).data!;
          expect(text, s.themeUnderPalette(s.paletteName(palette)));
          // Read before the chips it explains, under the section's title.
          final chip = tester.getRect(
            find.byKey(const ValueKey('set-theme-dark')),
          );
          expect(tester.getRect(note).bottom, lessThan(chip.top));
          expect(
            tester.getRect(find.text(s.settingsTheme)).bottom,
            lessThan(tester.getRect(note).top),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
