// U045 (docs/DESIGN.md "U045"), open points after the Q008 matrix:
// 1. The selected label of the compact (80 dp) navigation rail is drawn in
//    the person's chosen font at the same size and spacing as the
//    unselected labels (it carried only a colour and a weight, so it fell
//    back to the default font at 14 instead of labelMedium), still within
//    U044's 1.3× and three lines.
// 3. A typed-date pattern in a help line ("YYYY-AA-GG SS:DD") never breaks
//    inside the date: at 320 dp with 2× text the Turkish Activity help
//    broke after "YYYY-AA-".
// EN and TR; the bundled Lexend and Atkinson Hyperlegible fonts.
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
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/app_shell.dart';
import 'package:human_health_os/src/navigation/destination_switch.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f007_measurements_test.dart' show dev, settle, tapKey;
import 'u035_text_fit_test.dart' show mainScroll;

const _locales = [Locale('en', 'US'), Locale('tr', 'TR')];

Future<void> _launch(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
  required double textScale,
  FontChoice font = FontChoice.system,
  bool wideSpacing = false,
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
    AppearanceSettings(font: font, wideSpacing: wideSpacing),
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

/// The paragraph inside [of] whose whole text is [text].
RenderParagraph _paragraph(Finder of, String text) {
  final f = find.descendant(
    of: of,
    matching: find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText() == text,
    ),
  );
  expect(f, findsOneWidget, reason: text);
  return f.evaluate().single.renderObject! as RenderParagraph;
}

/// The top of the line that holds character [i] of [p].
double _top(RenderParagraph p, int i) => p
    .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
    .first
    .top;

void main() {
  group('the compact rail: selected and unselected labels alike', () {
    for (final (font, family, wide) in [
      (FontChoice.lexend, 'Lexend', false),
      (FontChoice.legible, 'AtkinsonHyperlegibleNext', true),
    ]) {
      for (final locale in _locales) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('${font.name}${wide ? ', wide spacing' : ''}, '
              '${locale.languageCode}, $scale× text', (tester) async {
            if (font == FontChoice.lexend) await tester.runAsync(_loadLexend);
            await _launch(
              tester,
              locale: locale,
              size: const Size(1000, 900),
              textScale: scale,
              font: font,
              wideSpacing: wide,
            );
            final lang = locale.languageCode == 'tr' ? AppLang.tr : AppLang.en;
            final rail = find.byKey(const ValueKey('nav-rail'));
            expect(rail, findsOneWidget);
            final theme = Theme.of(tester.element(rail));
            final want = theme.textTheme.labelMedium!;
            // Today is open (selected); Timeline and Labs are not.
            final selected = _paragraph(
              rail,
              destinationById(DestinationId.today).label(lang),
            );
            for (final id in [DestinationId.timeline, DestinationId.labs]) {
              final other = _paragraph(rail, destinationById(id).label(lang));
              final a = selected.text.style!;
              final b = other.text.style!;
              expect(a.fontFamily, family, reason: 'selected label font');
              expect(b.fontFamily, family, reason: 'unselected label font');
              expect(a.fontSize, want.fontSize, reason: 'selected label size');
              expect(b.fontSize, want.fontSize);
              expect(a.letterSpacing, b.letterSpacing);
              expect(a.wordSpacing, b.wordSpacing);
              expect(a.height, b.height);
              expect(a.fontWeight, FontWeight.w700);
            }
            // Still at most 1.3× and three lines (U044).
            final at = selected.textScaler.scale(10) / 10;
            expect(at, lessThanOrEqualTo(kNavLabelMaxScale + 0.001));
            expect(selected.didExceedMaxLines, isFalse);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('a typed-date pattern stays whole', () {
    // Lexend: real glyph widths. (In the test font every glyph is a
    // square, so the help line is far longer than in any real font.)
    for (final locale in _locales) {
      testWidgets('Activity add sheet, Lexend, '
          '${locale.languageCode}, 320 dp, 2× text', (tester) async {
        await tester.runAsync(_loadLexend);
        await _launch(
          tester,
          locale: locale,
          size: const Size(320, 640),
          textScale: 2.0,
          font: FontChoice.lexend,
        );
        tester
            .widget<DestinationSwitch>(find.byType(DestinationSwitch).first)
            .go(DestinationId.activity);
        await settle(tester);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('act-add')),
          200,
          scrollable: mainScroll('screen-activity'),
        );
        await tapKey(tester, 'act-add');
        final tr = locale.languageCode == 'tr';
        final date = tr ? ymdTr : ymdEn;
        final time = tr ? 'SS:DD' : 'HH:MM';
        final help = tr ? 'SS:DD ya da $ymdHmTr; boş = şimdi' : null;
        final sheet = find.byType(BottomSheet).last;
        var seen = 0;
        for (final e
            in find
                .descendant(of: sheet, matching: find.byType(RichText))
                .evaluate()) {
          final p = e.renderObject! as RenderParagraph;
          final text = p.text.toPlainText();
          final at = text.indexOf(date);
          if (at < 0) continue;
          if (help != null) expect(text, help);
          seen++;
          // The date on one line, the time on one line.
          final end = at + date.length - 1;
          expect(
            _top(p, end),
            closeTo(_top(p, at), 0.5),
            reason: '"$text" breaks inside $date',
          );
          final t = text.indexOf(time, end);
          expect(
            _top(p, t + time.length - 1),
            closeTo(_top(p, t), 0.5),
            reason: '"$text" breaks inside $time',
          );
          expect(p.didExceedMaxLines, isFalse, reason: text);
        }
        expect(seen, greaterThanOrEqualTo(1));
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('the patterns read as before, with only word joiners added', () {
    String plain(String s) => s.replaceAll('⁠', '');
    expect(plain(ymdHmEn), 'YYYY-MM-DD HH:MM');
    expect(plain(ymdHmTr), 'YYYY-AA-GG SS:DD');
    expect(plain(const S(AppLang.tr).foodWhenHelp), contains('YYYY-AA-GG'));
    expect(plain(const S(AppLang.en).foodWhenHelp), contains('YYYY-MM-DD'));
  });
}
