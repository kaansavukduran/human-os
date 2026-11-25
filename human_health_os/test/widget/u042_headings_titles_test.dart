// U042: findings of the Q005 screen matrix (docs/DESIGN.md "U042").
// 1. Today has no heading directly above another heading: the tools sit
//    under two headings that say what they are for, with no "Tools" /
//    "Araçlar" heading on top of them.
// 2. Long titles (first run, the visit summary, "Worked out from your
//    records") wrap only between words: a line never ends inside a word.
//    When one word alone is wider than the space, only that title is drawn
//    just small enough for the word to fit; otherwise it keeps the
//    person's text size.
// Each is checked in EN and TR at 320 dp with 1× and 2× text and on a
// desktop window.
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
import 'package:human_health_os/src/presentation/widgets/whole_words.dart';

import 'f007_measurements_test.dart' show dev, settle, tapKey;

const _en = Locale('en', 'US');
const _tr = Locale('tr', 'TR');

/// The windows each check runs on: 320 dp at 1× and 2× text, a desktop.
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

/// Loads the bundled Lexend under its theme name, so titles are measured
/// with real glyph widths (the test font draws every letter as a square
/// as wide as the text is high).
Future<void> _loadLexend() async {
  final loader = FontLoader('Lexend');
  for (final f in ['Lexend-Regular.ttf', 'Lexend-SemiBold.ttf']) {
    loader.addFont(rootBundle.load('assets/fonts/$f'));
  }
  await loader.load();
}

/// The headings on screen inside [root]: their texts' paragraphs.
Set<RenderParagraph> _headings(Finder root) => {
  for (final e
      in find
          .descendant(
            of: root,
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.header == true,
            ),
          )
          .evaluate())
    for (final p
        in find
            .descendant(
              of: find.byElementPredicate((x) => x == e),
              matching: find.byType(RichText),
            )
            .evaluate())
      p.renderObject! as RenderParagraph,
};

Rect _rect(RenderParagraph p) =>
    MatrixUtils.transformRect(p.getTransformTo(null), Offset.zero & p.size);

/// Each heading whose next text below, in the same column and less than
/// 32 px away, is another heading (the screen matrix's
/// `no_stacked_headings`).
List<String> _stacked(WidgetTester tester, Finder root) {
  final headings = _headings(root);
  final view = Offset.zero & tester.view.physicalSize;
  final texts = [
    for (final e
        in find
            .descendant(of: root, matching: find.byType(RichText))
            .evaluate())
      if ((e.renderObject! as RenderParagraph).attached &&
          (e.renderObject! as RenderParagraph).text.toPlainText().isNotEmpty)
        e.renderObject! as RenderParagraph,
  ].where((p) => _rect(p).overlaps(view)).toList();
  final found = <String>[];
  for (final h in headings) {
    if (!h.attached) continue;
    final a = _rect(h);
    if (!a.overlaps(view)) continue;
    RenderParagraph? next;
    var best = double.infinity;
    for (final t in texts) {
      if (identical(t, h)) continue;
      final b = _rect(t);
      final sameColumn = b.left < a.right && a.left < b.right;
      if (!sameColumn || b.top < a.bottom - 1) continue;
      if (b.top < best) {
        best = b.top;
        next = t;
      }
    }
    if (next != null && headings.contains(next) && best - a.bottom < 32) {
      found.add('${h.text.toPlainText()} > ${next.text.toPlainText()}');
    }
  }
  return found;
}

/// Scrolls Today from top to bottom and collects every stacked heading.
Future<Set<String>> _sweepToday(WidgetTester tester) async {
  final root = find.byKey(const ValueKey('screen-today'));
  final scrollable = find
      .descendant(of: root, matching: find.byType(Scrollable))
      .first;
  final element = scrollable.evaluate().first;
  final scroller = find.byElementPredicate((e) => e == element);
  final seen = <String>{..._stacked(tester, root)};
  for (var i = 0; i < 200; i++) {
    final state = tester.state<ScrollableState>(scroller);
    final before = state.position.pixels;
    if (before >= state.position.maxScrollExtent) break;
    await tester.drag(scroller, const Offset(0, -200));
    await tester.pumpAndSettle();
    seen.addAll(_stacked(tester, root));
    if (state.position.pixels == before) break;
  }
  final end = tester.state<ScrollableState>(scroller).position;
  expect(end.pixels, closeTo(end.maxScrollExtent, 1));
  return seen;
}

/// The line each character of [p] is drawn on, by the top of its box.
/// Characters without a box (a space at a line's end) are null.
List<double?> _lineTops(RenderParagraph p) {
  final text = p.text.toPlainText();
  return [
    for (var i = 0; i < text.length; i++)
      p
          .getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          )
          .map((b) => b.top)
          .firstOrNull,
  ];
}

/// The paragraph of [text] inside [of].
RenderParagraph paragraphOf(WidgetTester tester, Finder of, String text) {
  final t = find.descendant(of: of, matching: find.text(text));
  expect(t, findsOneWidget, reason: text);
  return tester.renderObject<RenderParagraph>(
    find.descendant(of: t, matching: find.byType(RichText)),
  );
}

/// [p] breaks only between words: two letters of one word are always on
/// the same line, and the longest word is drawn on one line.
void expectWholeWords(RenderParagraph p) {
  final text = p.text.toPlainText();
  final tops = _lineTops(p);
  for (var i = 0; i + 1 < text.length; i++) {
    if (text[i].trim().isEmpty || text[i + 1].trim().isEmpty) continue;
    expect(
      (tops[i]! - tops[i + 1]!).abs(),
      lessThan(0.5),
      reason:
          '"$text" breaks inside a word, between "${text[i]}" and '
          '"${text[i + 1]}"',
    );
  }
  expect(p.didExceedMaxLines, isFalse, reason: text);
}

/// The text size [p] is drawn at, as a multiple of its font size.
double _scaleOf(RenderParagraph p) => p.textScaler.scale(10) / 10;

/// [p]'s text size: the person's [chosen] size when its longest word fits
/// on a line of [p]'s width at that size, else just enough smaller for the
/// longest word to fit (within 3 %).
void expectFittingScale(WidgetTester tester, RenderParagraph p, double chosen) {
  final style = p.text.style;
  final width = p.constraints.maxWidth;
  double widest(double scale) {
    var most = 0.0;
    for (final w in p.text.toPlainText().split(RegExp(r'\s+'))) {
      final painter = TextPainter(
        text: TextSpan(text: w, style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(scale),
      )..layout();
      if (painter.width > most) most = painter.width;
      painter.dispose();
    }
    return most;
  }

  final scale = _scaleOf(p);
  if (widest(chosen) <= width) {
    expect(scale, closeTo(chosen, 0.001), reason: p.text.toPlainText());
  } else {
    expect(scale, lessThan(chosen));
    expect(widest(scale), lessThanOrEqualTo(width + 0.01));
    expect(widest(scale * 1.03), greaterThan(width));
  }
}

Finder _scrollableOf(String screen) => find
    .descendant(
      of: find.byKey(ValueKey(screen)),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls [screen]'s list back to its top.
Future<void> _top(WidgetTester tester, String screen) async {
  tester.state<ScrollableState>(_scrollableOf(screen)).position.jumpTo(0);
  await tester.pumpAndSettle();
}

/// Scrolls [screen]'s lazy list until [key] is built.
Future<void> _scrollTo(WidgetTester tester, String screen, String key) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200, scrollable: _scrollableOf(screen));
  }
}

/// Opens a tool listed on Today.
Future<void> _openTool(WidgetTester tester, String key) async {
  await _scrollTo(tester, 'screen-today', key);
  await tapKey(tester, key);
}

void _pop(WidgetTester tester, String screen) =>
    Navigator.of(tester.element(find.byKey(ValueKey(screen)))).pop();

void main() {
  group('1. Today: no heading stacked on a heading', () {
    for (final (locale, lang) in [(_en, AppLang.en), (_tr, AppLang.tr)]) {
      final s = S(lang);
      for (final (name, size, scale) in _windows) {
        testWidgets('${lang.name}, $name', (tester) async {
          await _launch(tester, locale: locale, size: size, textScale: scale);
          expect(await _sweepToday(tester), isEmpty);
          await _top(tester, 'screen-today');
          await _scrollTo(tester, 'screen-today', 'tool-phyto');
          // The tools are under the two headings that say what they are
          // for; the old "Tools" heading is gone.
          expect(
            find.text(lang == AppLang.en ? 'Tools' : 'Araçlar'),
            findsNothing,
          );
          final semantics = tester.ensureSemantics();
          for (final (h, first) in [(s.toolsGroupFiles, 'tool-phyto')]) {
            final t = find.text(h);
            expect(t, findsOneWidget, reason: h);
            expect(
              tester.getSemantics(t),
              matchesSemantics(label: h, isHeader: true),
            );
            expect(
              tester.getTopLeft(t).dy,
              lessThan(tester.getTopLeft(find.byKey(ValueKey(first))).dy),
            );
          }
          semantics.dispose();
        });
      }
    }

    testWidgets('the first group is a heading of its own, read before its '
        'tools', (tester) async {
      await _launch(
        tester,
        locale: _tr,
        size: const Size(1440, 3200),
        textScale: 1.0,
      );
      final s = S(AppLang.tr);
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text(s.toolsGroupApp)),
        matchesSemantics(label: s.toolsGroupApp, isHeader: true),
      );
      semantics.dispose();
      expect(
        tester.getTopLeft(find.text(s.toolsGroupApp)).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('tool-summary'))).dy,
        ),
      );
    });
  });

  group('2. titles break only between words', () {
    for (final font in [FontChoice.system, FontChoice.lexend]) {
      for (final (locale, lang) in [(_en, AppLang.en), (_tr, AppLang.tr)]) {
        final s = S(lang);
        for (final (name, size, scale) in _windows) {
          testWidgets('summary and derived, ${font.name}, ${lang.name}, '
              '$name', (tester) async {
            if (font == FontChoice.lexend) {
              await tester.runAsync(_loadLexend);
            }
            await _launch(
              tester,
              locale: locale,
              size: size,
              textScale: scale,
              font: font,
            );
            for (final (key, screen, title) in [
              ('tool-summary', 'screen-summary', s.summaryTitle),
              ('tool-derived', 'screen-derived', s.derivedTitle),
            ]) {
              await _openTool(tester, key);
              final p = paragraphOf(tester, find.byType(AppBar), title);
              expectWholeWords(p);
              expectFittingScale(tester, p, scale);
              // Inside the bar, drawn at its laid-out size.
              final bar = tester.getRect(find.byType(AppBar));
              final r = _rect(p);
              expect(r.top, greaterThanOrEqualTo(bar.top - 0.5));
              expect(r.bottom, lessThanOrEqualTo(bar.bottom + 0.5));
              expect(tester.takeException(), isNull);
              _pop(tester, screen);
              await settle(tester);
            }
          });

          testWidgets('first run, ${font.name}, ${lang.name}, $name', (
            tester,
          ) async {
            if (font == FontChoice.lexend) {
              await tester.runAsync(_loadLexend);
            }
            await _launch(
              tester,
              locale: locale,
              size: size,
              textScale: scale,
              font: font,
              firstRun: true,
            );
            final root = find.byKey(const ValueKey('screen-first-run'));
            for (final title in [s.firstWelcomeTitle, s.firstLookTitle]) {
              final p = paragraphOf(tester, root, title);
              expectWholeWords(p);
              expectFittingScale(tester, p, scale);
              if (title == s.firstWelcomeTitle) {
                await _scrollTo(tester, 'screen-first-run', 'first-next');
                await tapKey(tester, 'first-next');
                await _top(tester, 'screen-first-run');
              }
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('with real glyph widths, EN keeps the chosen 2× size and '
        'wraps between words; only the TR derived title is drawn smaller', (
      tester,
    ) async {
      await tester.runAsync(_loadLexend);
      for (final (locale, lang) in [(_en, AppLang.en), (_tr, AppLang.tr)]) {
        final s = S(lang);
        await _launch(
          tester,
          locale: locale,
          size: const Size(320, 640),
          textScale: 2.0,
          font: FontChoice.lexend,
        );
        for (final (key, screen, title) in [
          ('tool-summary', 'screen-summary', s.summaryTitle),
          ('tool-derived', 'screen-derived', s.derivedTitle),
        ]) {
          await _openTool(tester, key);
          final p = paragraphOf(tester, find.byType(AppBar), title);
          expect(p.text.style?.fontFamily, 'Lexend');
          final shrunk = lang == AppLang.tr && key == 'tool-derived';
          if (shrunk) {
            expect(_scaleOf(p), lessThan(2.0));
            // Still larger than the 1× size: only as small as the longest
            // word needs.
            expect(_scaleOf(p), greaterThan(1.0));
          } else {
            expect(_scaleOf(p), closeTo(2.0, 0.001), reason: title);
          }
          // More than one line: the words wrap.
          final lines = _lineTops(p).whereType<double>().toSet();
          expect(lines.length, greaterThan(1), reason: title);
          _pop(tester, screen);
          await settle(tester);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    test('a scaler is the chosen one when the longest word fits', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      const style = TextStyle(fontSize: 10);
      const base = TextScaler.linear(2);
      // The test font: each letter is as wide as the font size.
      expect(
        wholeWordScaler(
          text: 'ab cd',
          style: style,
          base: base,
          maxWidth: 40,
          textDirection: TextDirection.ltr,
        ),
        base,
      );
      final fit = wholeWordScaler(
        text: 'ab abcdefgh',
        style: style,
        base: base,
        maxWidth: 40,
        textDirection: TextDirection.ltr,
      );
      expect(fit.scale(10), lessThanOrEqualTo(5));
      expect(fit.scale(10), greaterThan(4.5));
    });
  });
}
