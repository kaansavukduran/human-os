// U043: findings of the Q006 screen matrix (docs/DESIGN.md "U043").
// Labels and chips wrap between words: never cut, faded or ellipsized,
// never broken inside a word, and at the person's text size whenever the
// longest word fits on a line.
// 1. Settings, Today's measurement order: each label has the row's width
//    when the buttons beside it would leave too little ("Waist circu /
//    mference", "Oksijen sat / ürasyonu").
// 2. Settings, palette cards: the name of the chosen palette is whole
//    ("Stand / ard", "Stand / art").
// 3. Chips (first run, Settings and the sheets): the label wraps onto
//    more lines ("Same as this de…").
// Each is checked in EN and TR at 320 dp with 1× and 2× text and on a
// desktop window, with the test font and with the bundled Lexend.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/appearance_scope.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/presentation/widgets/whole_chip.dart';

import 'f007_measurements_test.dart' show dev, settle, tapKey;
import 'u042_headings_titles_test.dart'
    show expectFittingScale, expectWholeWords;

const _en = Locale('en', 'US');
const _tr = Locale('tr', 'TR');

const _windows = [
  ('320 dp, 1×', Size(320, 640), 1.0),
  ('320 dp, 2×', Size(320, 640), 2.0),
  ('desktop', Size(1440, 900), 1.0),
];

Future<void> _launch(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
  required double textScale,
  FontChoice font = FontChoice.system,
  bool firstRun = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final s = await tester.runAsync(() async {
    final repo = LogRepository(
      sink: MemoryLogSink(),
      durability: StorageDurability.localFile,
      location: 'test',
    );
    final report = await repo.open();
    return servicesFor(dev, HostPlatform.linux, repo, report: report);
  });
  final c = AppearanceController(
    MemoryAppearanceStore(),
    AppearanceSettings(font: font),
  );
  await tester.pumpWidget(
    HumanOsApp(services: s!, appearance: c, offerFirstRun: firstRun),
  );
  await settle(tester);
}

Future<void> _loadLexend() async {
  final loader = FontLoader('Lexend');
  for (final f in ['Lexend-Regular.ttf', 'Lexend-SemiBold.ttf']) {
    loader.addFont(rootBundle.load('assets/fonts/$f'));
  }
  await loader.load();
}

/// The chips of any kind (Material's or the app's own).
bool _isChip(Widget w) => const {
  'ChoiceChip',
  'FilterChip',
  'ActionChip',
  'Chip',
  'WholeChip',
}.contains(w.runtimeType.toString());

String? _keyOf(Widget w) =>
    w.key is ValueKey<String> ? (w.key! as ValueKey<String>).value : null;

/// The parts checked on a screen: chips, Today's order rows (their keys
/// are `set-tile-<code>`) and palette cards.
bool _checked(Widget w) {
  if (_isChip(w)) return true;
  final k = _keyOf(w);
  if (k == null) return false;
  if (k.startsWith('set-palette-')) return true;
  return k.startsWith('set-tile-') &&
      !k.startsWith('set-tile-show-') &&
      !k.startsWith('set-tile-up-') &&
      !k.startsWith('set-tile-down-');
}

/// [p] is drawn whole: no line ends inside a word, nothing is cut, faded
/// or ellipsized, its text lies inside its box, and it is at the chosen
/// size unless one word alone is wider than its line.
void _expectWhole(WidgetTester tester, RenderParagraph p, double scale) {
  final text = p.text.toPlainText();
  expectWholeWords(p);
  expect(
    p.textSize.width,
    lessThanOrEqualTo(p.size.width + 0.5),
    reason: '"$text" is wider than its box (cut or faded)',
  );
  expect(
    p.textSize.height,
    lessThanOrEqualTo(p.size.height + 0.5),
    reason: '"$text" is taller than its box',
  );
  expectFittingScale(tester, p, scale);
}

/// Checks every built part [_checked] inside [root]; returns the labels
/// it saw.
Set<String> _checkParts(WidgetTester tester, Finder root, double scale) {
  final seen = <String>{};
  for (final e
      in find
          .descendant(of: root, matching: find.byWidgetPredicate(_checked))
          .evaluate()) {
    final part = find.byElementPredicate((x) => x == e);
    final partRect = tester.getRect(part);
    for (final r
        in find
            .descendant(of: part, matching: find.byType(RichText))
            .evaluate()) {
      final p = r.renderObject! as RenderParagraph;
      if (!p.attached || p.text.toPlainText().trim().isEmpty) continue;
      // Icons are drawn as text too.
      if (r.widget is RichText &&
          (r.widget as RichText).text.style?.fontFamily == 'MaterialIcons') {
        continue;
      }
      _expectWhole(tester, p, scale);
      final box = MatrixUtils.transformRect(
        p.getTransformTo(null),
        Offset.zero & p.size,
      );
      expect(
        box.right,
        lessThanOrEqualTo(partRect.right + 0.5),
        reason: '"${p.text.toPlainText()}" runs past its part',
      );
      seen.add(p.text.toPlainText());
    }
  }
  return seen;
}

/// Scrolls [screen] from top to bottom, checking at each step.
Future<Set<String>> _sweep(
  WidgetTester tester,
  String screen,
  double scale,
) async {
  final root = find.byKey(ValueKey(screen));
  final scroller = find
      .descendant(of: root, matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(scroller).position.jumpTo(0);
  await tester.pumpAndSettle();
  final seen = _checkParts(tester, root, scale);
  for (var i = 0; i < 300; i++) {
    final state = tester.state<ScrollableState>(scroller);
    final before = state.position.pixels;
    if (before >= state.position.maxScrollExtent) break;
    state.position.jumpTo(
      (before + 200).clamp(0, state.position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
    seen.addAll(_checkParts(tester, root, scale));
  }
  return seen;
}

/// The paragraph of [text] inside the widget keyed [key].
RenderParagraph _paragraph(WidgetTester tester, String key, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.text(text),
        ),
        matching: find.byType(RichText),
      ),
    );

Future<void> _scrollTo(WidgetTester tester, String screen, String key) async {
  final f = find.byKey(ValueKey(key));
  final scroller = find
      .descendant(
        of: find.byKey(ValueKey(screen)),
        matching: find.byType(Scrollable),
      )
      .first;
  if (f.evaluate().isEmpty) {
    tester.state<ScrollableState>(scroller).position.jumpTo(0);
    await tester.pumpAndSettle();
  }
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200, scrollable: scroller);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  for (final font in [FontChoice.system, FontChoice.lexend]) {
    for (final (locale, lang) in [(_en, AppLang.en), (_tr, AppLang.tr)]) {
      final s = S(lang);
      for (final (name, size, scale) in _windows) {
        final label = '${font.name}, ${lang.name}, $name';

        testWidgets('Settings: chips, measurement order and palette '
            'cards are whole, $label', (tester) async {
          if (font == FontChoice.lexend) await tester.runAsync(_loadLexend);
          await _launch(
            tester,
            locale: locale,
            size: size,
            textScale: scale,
            font: font,
          );
          await tapKey(tester, 'open-settings');
          final seen = await _sweep(tester, 'screen-settings', scale);
          expect(
            seen,
            containsAll([
              s.settingsSystem,
              s.paletteName(PaletteChoice.standard),
              s.recordKind(RecordKind.waistCircumference),
              s.recordKind(RecordKind.oxygenSaturation),
              s.lockOff,
            ]),
          );
          // The Q006 cases by name.
          await _scrollTo(tester, 'screen-settings', 'set-palette-standard');
          _expectWhole(
            tester,
            _paragraph(
              tester,
              'set-palette-standard',
              s.paletteName(PaletteChoice.standard),
            ),
            scale,
          );
          await _scrollTo(tester, 'screen-settings', 'set-language-system');
          _expectWhole(
            tester,
            _paragraph(tester, 'set-language-system', s.settingsSystem),
            scale,
          );
          for (final code in [
            'body.waist_circumference',
            'vital.oxygen_saturation',
          ]) {
            final key = 'set-tile-$code';
            if (find.byKey(ValueKey(key)).evaluate().isEmpty) continue;
            await _scrollTo(tester, 'screen-settings', key);
            // The up and down buttons stay 48 dp targets.
            for (final b in ['set-tile-up-$code', 'set-tile-down-$code']) {
              final r = tester.getRect(find.byKey(ValueKey(b)));
              expect(r.width, greaterThanOrEqualTo(48));
              expect(r.height, greaterThanOrEqualTo(48));
            }
          }
          expect(tester.takeException(), isNull);
        });

        testWidgets('first run: the chips are whole, $label', (tester) async {
          if (font == FontChoice.lexend) await tester.runAsync(_loadLexend);
          await _launch(
            tester,
            locale: locale,
            size: size,
            textScale: scale,
            font: font,
            firstRun: true,
          );
          await _scrollTo(tester, 'screen-first-run', 'first-next');
          await tapKey(tester, 'first-next');
          final seen = await _sweep(tester, 'screen-first-run', scale);
          expect(
            seen,
            containsAll([
              'Türkçe',
              'English',
              s.settingsSystem,
              s.settingsLight,
              s.settingsDark,
              s.fontLegible,
              s.fontDyslexic,
            ]),
          );
          await _scrollTo(tester, 'screen-first-run', 'first-language-system');
          final chip = find.byKey(const ValueKey('first-language-system'));
          _expectWhole(
            tester,
            _paragraph(tester, 'first-language-system', s.settingsSystem),
            scale,
          );
          // A 48 dp target, read as one whole name.
          final r = tester.getRect(chip);
          expect(r.height, greaterThanOrEqualTo(48));
          final semantics = tester.ensureSemantics();
          expect(
            tester.getSemantics(chip),
            matchesSemantics(
              label: s.settingsSystem,
              isButton: true,
              hasSelectedState: true,
              isSelected: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
          );
          semantics.dispose();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  group('the chip every screen uses', () {
    // Labels of chips on the sheets and screens (glucose timing, lab kinds,
    // the language chip), at 320 dp in a padded column.
    const labels = [
      'Same as this device',
      'Bu cihazla aynı',
      'After a meal',
      'Yemekten sonra',
      'Başka bir zaman',
      'Kolay okunur (Atkinson Hyperlegible)',
    ];
    for (final (name, scale) in [('1×', 1.0), ('2×', 2.0), ('3×', 3.0)]) {
      testWidgets('wraps between words, stays a 48 dp target, $name', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        String? picked;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 640),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final l in labels)
                          WholeChip.choice(
                            key: ValueKey(l),
                            label: l,
                            selected: l == labels.first,
                            onSelected: (_) => picked = l,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        for (final l in labels) {
          final chip = find.byKey(ValueKey(l));
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          _expectWhole(tester, _paragraph(tester, l, l), scale);
          final r = tester.getRect(chip);
          expect(r.height, greaterThanOrEqualTo(48));
          expect(r.width, greaterThanOrEqualTo(48));
          expect(r.right, lessThanOrEqualTo(304.5), reason: l);
          await tester.tap(chip);
          expect(picked, l);
        }
        expect(tester.takeException(), isNull);
      });
    }

    test('no screen uses a Material chip, whose label is one faded line', () {
      final material = RegExp(
        r'(?<![A-Za-z.])(ChoiceChip|FilterChip|ActionChip|InputChip|'
        r'RawChip|Chip)\(',
      );
      final found = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('//')) continue;
          if (material.hasMatch(lines[i])) found.add('${f.path}:${i + 1}');
        }
      }
      expect(found, isEmpty);
    });
  });
}
