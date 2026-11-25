// U044 (docs/DESIGN.md "U044"), findings 3 and 4 of the Q007 review:
// 3. WholeChip follows the theme's density: "Compact" draws a one-line
//    chip 24 dp tall instead of 32, as Material's chips did, while its
//    target stays at least 48 × 48 dp.
// 4. The compact (80 dp) navigation rail does not grow without bound at
//    large text: each label is at most Material's 1.3× for navigation
//    labels, drawn smaller only as much as needed for its longest word to
//    fit on a line and for the label to fit in three lines; never cut,
//    never broken inside a word; the rail stays 80 dp wide. Checked with
//    the test font and the bundled Lexend (real glyph widths).
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
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/navigation/app_shell.dart';
import 'package:human_health_os/src/presentation/widgets/whole_chip.dart';

import 'f007_measurements_test.dart' show dev, settle, tapKey;
import 'u042_headings_titles_test.dart' show expectWholeWords;

const _locales = [Locale('en', 'US'), Locale('tr', 'TR')];

Future<void> _launch(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
  required double textScale,
  Density density = Density.comfortable,
  FontChoice font = FontChoice.system,
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
    AppearanceSettings(density: density, font: font),
  );
  await tester.pumpWidget(HumanOsApp(services: s!, appearance: c));
  await settle(tester);
}

Future<void> _loadLexend() async {
  final loader = FontLoader('Lexend');
  for (final f in ['Lexend-Regular.ttf', 'Lexend-SemiBold.ttf']) {
    loader.addFont(rootBundle.load('assets/fonts/$f'));
  }
  await loader.load();
}

/// The chip as drawn (its outline), inside its 48 dp target.
Rect _drawn(WidgetTester tester, Finder chip) => tester.getRect(
  find.descendant(of: chip, matching: find.byType(Material)).first,
);

/// Whether [p]'s text at [scale]× has every word on one line of its width
/// and takes at most [kRailLabelMaxLines] lines.
bool _fits(RenderParagraph p, double scale) {
  final width = p.constraints.maxWidth;
  final style = p.text.style;
  for (final word in p.text.toPlainText().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: p.textDirection,
      locale: p.locale,
      textScaler: TextScaler.linear(scale),
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    if (w > width) return false;
  }
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    locale: p.locale,
    textScaler: TextScaler.linear(scale),
  )..layout(maxWidth: width);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines <= kRailLabelMaxLines;
}

/// The number of lines [p] is laid out on.
int _lines(RenderParagraph p) {
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    locale: p.locale,
    textScaler: p.textScaler,
    textAlign: p.textAlign,
  )..layout(maxWidth: p.size.width + 0.01);
  final n = painter.computeLineMetrics().length;
  painter.dispose();
  return n;
}

void main() {
  group('WholeChip follows the theme density', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('compact draws the chip smaller, the target stays 48 dp, '
          '$scale× text', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final drawn = <VisualDensity, double>{};
        for (final density in [VisualDensity.standard, VisualDensity.compact]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(visualDensity: density),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 640),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final (k, on) in [('a', true), ('b', false)])
                          WholeChip.choice(
                            key: ValueKey(k),
                            label: 'Rested',
                            selected: on,
                            onSelected: (_) {},
                          ),
                        WholeChip.action(
                          key: const ValueKey('c'),
                          label: 'Now',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          // MaterialApp animates a theme change.
          await tester.pumpAndSettle();
          for (final k in ['a', 'b', 'c']) {
            final chip = find.byKey(ValueKey(k));
            final target = tester.getRect(chip);
            expect(target.height, greaterThanOrEqualTo(48), reason: k);
            expect(target.width, greaterThanOrEqualTo(48), reason: k);
            // The drawn chip is centred in its target.
            final d = _drawn(tester, chip);
            expect(d.center.dy, closeTo(target.center.dy, 0.5));
            drawn[density] = d.height;
          }
        }
        expect(
          drawn[VisualDensity.compact],
          closeTo(drawn[VisualDensity.standard]! - 8, 0.5),
          reason: 'compact takes 4 dp off the padding above and below',
        );
        if (scale == 1.0) {
          expect(drawn[VisualDensity.standard], closeTo(32, 0.5));
          expect(drawn[VisualDensity.compact], closeTo(24, 0.5));
        }
      });
    }

    for (final locale in _locales) {
      testWidgets('Settings in Compact: every chip a 48 dp target, drawn '
          'shorter, ${locale.languageCode}', (tester) async {
        await _launch(
          tester,
          locale: locale,
          size: const Size(390, 2400),
          textScale: 1,
          density: Density.compact,
        );
        await tapKey(tester, 'open-settings');
        final chips = find.byType(WholeChip);
        expect(chips, findsWidgets);
        for (final e in chips.evaluate()) {
          final chip = find.byElementPredicate((x) => x == e);
          final r = tester.getRect(chip);
          expect(r.height, greaterThanOrEqualTo(48));
          expect(r.width, greaterThanOrEqualTo(48));
          // One-line chips are drawn 24 dp tall.
          final d = _drawn(tester, chip);
          if (d.height < 40) expect(d.height, closeTo(24, 0.5));
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the compact rail at large text', () {
    for (final font in [FontChoice.system, FontChoice.lexend]) {
      for (final locale in _locales) {
        for (final scale in [1.0, 2.0, 3.0]) {
          testWidgets('labels: ≤ 1.3×, ≤ 3 lines, whole, rail 80 dp, '
              '${font.name}, ${locale.languageCode}, $scale× text', (
            tester,
          ) async {
            if (font == FontChoice.lexend) await tester.runAsync(_loadLexend);
            await _launch(
              tester,
              locale: locale,
              size: const Size(1000, 900),
              textScale: scale,
              font: font,
            );
            final rail = find.byKey(const ValueKey('nav-rail'));
            expect(rail, findsOneWidget);
            final railBox = tester.getRect(rail);
            expect(railBox.width, lessThanOrEqualTo(kRailMinWidth + 0.5));
            final chosen = scale < kNavLabelMaxScale
                ? scale
                : kNavLabelMaxScale;
            var n = 0;
            for (final e
                in find
                    .descendant(of: rail, matching: find.byType(RichText))
                    .evaluate()) {
              final w = e.widget as RichText;
              if (w.text.style?.fontFamily == 'MaterialIcons') continue;
              final p = e.renderObject! as RenderParagraph;
              final text = p.text.toPlainText();
              if (text.trim().isEmpty) continue;
              n++;
              final at = p.textScaler.scale(10) / 10;
              // The person's size up to 1.3×; smaller only as the rule
              // needs (about 3 % larger it would no longer fit).
              expect(at, lessThanOrEqualTo(chosen + 0.001), reason: text);
              if (_fits(p, chosen)) {
                expect(at, closeTo(chosen, 0.001), reason: '"$text" shrunk');
              } else {
                expect(_fits(p, at), isTrue, reason: text);
                expect(_fits(p, at * 1.03), isFalse, reason: text);
              }
              expect(
                _lines(p),
                lessThanOrEqualTo(kRailLabelMaxLines),
                reason: '"$text" lines',
              );
              expectWholeWords(p);
              expect(p.textSize.width, lessThanOrEqualTo(p.size.width + 0.5));
              final box = MatrixUtils.transformRect(
                p.getTransformTo(null),
                Offset.zero & p.size,
              );
              expect(box.right, lessThanOrEqualTo(railBox.right + 0.5));
              expect(box.left, greaterThanOrEqualTo(railBox.left - 0.5));
            }
            // Today, Timeline, Labs, the seven other areas, their heading
            // and Settings.
            expect(n, greaterThanOrEqualTo(12));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
