// U035 (A002 audit): Turkish and twice-size text fit; flatter Settings.
// 1. At 320x640 and 2× text, in Turkish and English, no label on Today or
//    Settings is clipped or ellipsized and nothing overflows; the weight
//    field keeps its whole label ("Ağırlık (kg)", not "Ağırlı").
// 2. The build banner is one line whose whole sentence is its spoken label.
// 3. Settings has one heading per section and no heading inside one.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import 'f007_measurements_test.dart' show launch, tapKey;

const en = Locale('en', 'US');
const tr = Locale('tr', 'TR');
const small = Size(320, 640);

/// Texts on screen whose lines did not all fit (cut or ellipsized).
Set<String> cutTexts(WidgetTester tester) => {
  for (final e in find.byType(RichText).evaluate())
    if ((e.renderObject! as RenderParagraph).didExceedMaxLines)
      (e.renderObject! as RenderParagraph).text.toPlainText(),
};

/// Scrolls [scrollable] top to bottom, collecting every cut text seen and
/// failing on any layout overflow.
Future<Set<String>> sweep(WidgetTester tester, Finder scroller) async {
  // Resolved once: the finder may go through a child that scrolls away.
  final element = scroller.evaluate().first;
  final scrollable = find.byElementPredicate((e) => e == element);
  final cut = <String>{...cutTexts(tester)};
  expect(tester.takeException(), isNull);
  for (var i = 0; i < 200; i++) {
    final state = tester.state<ScrollableState>(scrollable);
    final before = state.position.pixels;
    if (before >= state.position.maxScrollExtent) break;
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    cut.addAll(cutTexts(tester));
    expect(tester.takeException(), isNull);
    if (state.position.pixels == before) break;
  }
  // The whole screen was seen.
  final end = tester.state<ScrollableState>(scrollable).position;
  expect(end.maxScrollExtent, greaterThan(0));
  expect(end.pixels, closeTo(end.maxScrollExtent, 1));
  return cut;
}

Finder mainScroll(String screenKey) => find
    .descendant(
      of: find.byKey(ValueKey(screenKey)),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  for (final (locale, lang) in [(tr, AppLang.tr), (en, AppLang.en)]) {
    final s = S(lang);
    final name = locale.languageCode;

    testWidgets('$name, 320x640, 2× text: Today cuts no label and the '
        'weight field keeps its whole label', (tester) async {
      final handle = tester.ensureSemantics();
      await launch(tester, locale: locale, size: small, textScale: 2.0);
      // The field's label is whole (in the field, or above it when it does
      // not fit there) and is the field's spoken name; Save sits below.
      final label = find.descendant(
        of: find.byKey(const ValueKey('weight-card')),
        matching: find.text(s.weightField),
      );
      expect(label, findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('weight-input')))
            .getSemanticsData()
            .label,
        contains(s.weightField),
      );
      final field = tester.getRect(find.byKey(const ValueKey('weight-input')));
      final save = tester.getRect(find.byKey(const ValueKey('weight-save')));
      expect(save.top, greaterThanOrEqualTo(field.bottom - 1));
      expect(cutTexts(tester), isEmpty);
      final cut = await sweep(
        tester,
        find
            .ancestor(
              of: find.byKey(const ValueKey('weight-card')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(cut, isEmpty, reason: '$cut');
      handle.dispose();
    });

    testWidgets('$name, 320x640, 2× text: Settings cuts no label', (
      tester,
    ) async {
      await launch(tester, locale: locale, size: small, textScale: 2.0);
      await tapKey(tester, 'open-settings');
      final cut = await sweep(tester, mainScroll('screen-settings'));
      expect(cut, isEmpty, reason: '$cut');
    });

    testWidgets('$name, 320x640, 2× text: the build banner is one line and '
        'says its whole sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await launch(tester, locale: locale, size: small, textScale: 2.0);
      final banner = find.byKey(const ValueKey('build-profile-banner'));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const ValueKey('banner-text')),
          matching: find.byType(RichText),
        ),
      );
      final lineHeight = paragraph.getFullHeightForCaret(
        const TextPosition(offset: 0),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.height, lessThan(lineHeight * 1.5));
      expect(
        paragraph.text.toPlainText(),
        contains(
          lang == AppLang.tr ? 'GELİŞTİRME SÜRÜMÜ' : 'DEVELOPMENT BUILD',
        ),
      );
      expect(tester.getSemantics(banner).getSemanticsData().label, s.devBanner);
      handle.dispose();
    });

    testWidgets('$name: Settings has exactly one heading per section', (
      tester,
    ) async {
      await launch(tester, locale: locale, size: const Size(390, 844));
      await tapKey(tester, 'open-settings');
      final sections = [
        s.settingsInterfaceScale,
        s.settingsLanguage,
        s.settingsTheme,
        s.settingsPalette,
        s.settingsAccent,
        s.settingsTextSize,
        s.settingsFont,
        s.settingsUnits,
        s.settingsDates,
        s.settingsSpacing,
        s.settingsContrast,
        s.settingsStart,
        s.settingsToday,
        s.discoveryTitle,
        s.lockTitle,
        s.settingsUpdatesTitle,
      ];
      // No section title repeats another ("Appearance" inside "Appearance
      // and accessibility").
      expect(sections.toSet().length, sections.length);
      final screen = find.byKey(const ValueKey('screen-settings'));
      final headings = <String>[];
      final seen = <Element>{};
      void collect() {
        for (final e
            in find
                .descendant(
                  of: screen,
                  matching: find.byWidgetPredicate(
                    (w) => w is Semantics && w.properties.header == true,
                  ),
                )
                .evaluate()) {
          if (!seen.add(e)) continue;
          final text = find
              .descendant(
                of: find.byElementPredicate((x) => x == e),
                matching: find.byType(Text),
              )
              .evaluate()
              .map((t) => (t.widget as Text).data)
              .join(' ');
          headings.add(text);
        }
      }

      final scroll = mainScroll('screen-settings');
      collect();
      for (var i = 0; i < 80; i++) {
        final state = tester.state<ScrollableState>(scroll);
        if (state.position.pixels >= state.position.maxScrollExtent) break;
        await tester.drag(scroll, const Offset(0, -300));
        await tester.pumpAndSettle();
        collect();
      }
      // Each section's title is a heading once, and nothing else is.
      expect(headings.toSet(), sections.toSet());
      for (final t in sections) {
        expect(headings.where((h) => h == t).length, 1, reason: t);
      }
    });
  }
}
