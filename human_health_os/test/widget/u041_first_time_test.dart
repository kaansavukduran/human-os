// U041: understandable on the first visit, for someone with no prior
// knowledge. Each test is one friction point of the U041 audit
// (docs/DESIGN.md):
// 1. An empty record area, the summary and the weight card name the first
//    step, not only "Nothing recorded yet".
// 2. Instructions name no device: no "click" or "mouse" on a phone, no
//    "tap" on a desktop.
// 3. The how-to's tasks carry no decorative numbers.
// 4. Turkish follows the L001 words: "sözcük", "ağırlık", and no suffix on
//    the product name.
// 5. The Timeline's "Show deleted and withdrawn" says what the two words
//    mean.
// 6. First run, the summary and "Worked out from your records" keep one
//    centred reading column on a wide window.
// Each changed screen is checked in EN and TR at 320 dp with 2× text.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart'
    show MemoryAppearanceStore;
import 'package:human_health_os/src/domain/records/health_record.dart'
    show AmendReason;
import 'package:human_health_os/src/features/help/how_to_screen.dart';
import 'package:human_health_os/src/features/timeline/timeline_screen.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';
import 'package:human_health_os/src/presentation/theme/spacing.dart';
import 'package:human_health_os/src/presentation/widgets/first_step.dart';

import 'f004_labs_test.dart' show interpretive, judged;
import 'f007_measurements_test.dart' show launch, settle, tapKey;
import 'u014_first_run_test.dart' show launchReal;
import 'u030_read_failed_test.dart' show boot;
import 'u033_record_area_test.dart' show areas, host, reveal;
import 'u035_text_fit_test.dart' show cutTexts, mainScroll, small, sweep;
import 'u042_headings_titles_test.dart'
    show expectFittingScale, expectWholeWords;

const _en = Locale('en', 'US');
const _tr = Locale('tr', 'TR');

/// "click", "tap", "mouse" and their Turkish forms, as whole words.
final RegExp _deviceBound = RegExp(
  r'(?<!\p{L})(click\p{L}*|tap|taps|tapping|mouse|tıkla\p{L}*|dokun|'
  r'dokunarak|fare\p{L}*)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

/// The left edge and width of the centred reading column on a window
/// [window] wide, with [pad] inside the column.
(double, double) _column(double window, double pad) {
  final outer = window >= kReadingWidth ? kReadingWidth : window;
  return ((window - outer) / 2 + pad, outer - 2 * pad);
}

/// Scrolls the lazy list of [screen] until [key] is built and in view.
Future<void> _scrollTo(WidgetTester tester, String screen, String key) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200, scrollable: mainScroll(screen));
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

/// [title] in the app bar: not cut, at the person's text size unless one
/// word alone is wider than the bar (then just small enough for it, U042),
/// wrapped only between words, and inside the bar.
void _expectWholeTitle(WidgetTester tester, String title) {
  final text = find.descendant(
    of: find.byType(AppBar),
    matching: find.text(title),
  );
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse);
  expectFittingScale(tester, paragraph, 2.0);
  expectWholeWords(paragraph);
  final bar = tester.getRect(find.byType(AppBar));
  final r = tester.getRect(text);
  expect(r.top, greaterThanOrEqualTo(bar.top - 0.5));
  expect(r.bottom, lessThanOrEqualTo(bar.bottom + 0.5));
  // Drawn at its laid-out size: nothing shrinks it again on screen.
  expect(r.height, closeTo(paragraph.size.height, 0.5));
  expect(r.width, closeTo(paragraph.size.width, 0.5));
}

/// Opens a tool listed on Today.
Future<void> _openTool(WidgetTester tester, String key) async {
  await _scrollTo(tester, 'screen-today', key);
  await tapKey(tester, key);
}

void main() {
  group('1. empty states name the first step', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      final none = lang == AppLang.en
          ? 'Nothing recorded yet. '
          : 'Henüz kayıt yok. ';
      test('${lang.name}: five record areas and the summary', () {
        for (final t in [
          s.docNone,
          s.prevNone,
          s.condNone,
          s.actNone,
          s.foodNone,
          s.summaryEmpty,
        ]) {
          // Still says that nothing is recorded (missing is not zero),
          // then one sentence that says what to do.
          expect(t, startsWith(none));
          expect(t.length, greaterThan(none.length + 10), reason: t);
          expect(interpretive.hasMatch(t), isFalse, reason: t);
          expect(judged.hasMatch(t), isFalse, reason: t);
        }
        // Each area's sentence names what its own Add action adds.
        for (final (t, word)
            in lang == AppLang.en
                ? [
                    (s.docNone, 'document'),
                    (s.prevNone, 'vaccination'),
                    (s.condNone, 'symptom'),
                    (s.actNone, 'walk'),
                    (s.foodNone, 'meal'),
                  ]
                : [
                    (s.docNone, 'belge'),
                    (s.prevNone, 'aşı'),
                    (s.condNone, 'belirti'),
                    (s.actNone, 'yürüyüş'),
                    (s.foodNone, 'öğün'),
                  ]) {
          expect(t, contains(word));
        }
        // The summary promises only what it collects: weights, Today's
        // measurements and lab results (doctor_summary.dart).
        expect(
          s.summaryEmpty,
          lang == AppLang.en
              ? contains('Weights, measurements and lab results')
              : contains('ağırlık, ölçüm ve tahlil sonuçları'),
        );
        expect(s.summaryEmpty, isNot(contains('Today')));
        expect(s.summaryEmpty, isNot(contains('diğer alan')));
      });

      test('${lang.name}: the weight card says where to type and which '
          'button saves', () {
        expect(s.noWeightYet, contains(s.save));
        if (lang == AppLang.tr) {
          // One word per concept: the card's title and field say ağırlık.
          expect(s.weightTitle, contains('ağırlığı'));
          expect(s.noWeightYet, contains('ağırlık'));
          expect(s.noWeightYet, isNot(contains('kilo')));
          // The step says what to type: the value.
          expect(s.noWeightYet, contains('Değeri alana yaz'));
          expect(s.firstThen, contains('ağırlığını yaz'));
          expect(s.firstThen, isNot(contains('kilo')));
        }
      });
    }

    for (final a in areas.where((a) => a.id != 'meds')) {
      for (final locale in const [Locale('en'), Locale('tr')]) {
        testWidgets('${a.id}, ${locale.languageCode}, 320 dp, 2× text: the '
            'whole sentence and Add sit in the first step', (tester) async {
          final (s, _) = await boot(tester);
          tester.view.physicalSize = const Size(320, 700);
          await tester.pumpWidget(host(a.build(s), locale: locale, text: 2));
          await settle(tester);
          final empty = find.byKey(ValueKey('${a.id}-empty'));
          await reveal(tester, empty);
          final words = S(
            locale.languageCode == 'tr' ? AppLang.tr : AppLang.en,
          );
          expect(
            tester.widget<Text>(find.byKey(ValueKey('${a.id}-none'))).data,
            a.none(words),
          );
          expect(
            find.descendant(
              of: find.byType(FirstStep),
              matching: find.byKey(ValueKey('${a.id}-add')),
            ),
            findsOneWidget,
          );
          expect(cutTexts(tester), isEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final (locale, lang) in [(_en, AppLang.en), (_tr, AppLang.tr)]) {
      testWidgets('summary, ${lang.name}, 320 dp, 2× text: the empty '
          'sentence is whole', (tester) async {
        await launch(tester, locale: locale, size: small, textScale: 2.0);
        await _openTool(tester, 'tool-summary');
        final empty = find.byKey(const ValueKey('summary-empty'));
        await tester.ensureVisible(empty);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(empty).data, S(lang).summaryEmpty);
        // The title too: whole, at the chosen text size.
        expect(cutTexts(tester), isEmpty);
        expect(tester.takeException(), isNull);
        _expectWholeTitle(tester, S(lang).summaryTitle);
        Navigator.of(
          tester.element(find.byKey(const ValueKey('screen-summary'))),
        ).pop();
        await settle(tester);
        await _openTool(tester, 'tool-derived');
        _expectWholeTitle(tester, S(lang).derivedTitle);
        expect(cutTexts(tester), isNot(contains(S(lang).derivedTitle)));
        expect(tester.takeException(), isNull);
      });

      testWidgets('weight card, ${lang.name}, 320 dp, 2× text: the empty '
          'sentence is whole', (tester) async {
        await launch(tester, locale: locale, size: small, textScale: 2.0);
        expect(find.text(S(lang).noWeightYet), findsOneWidget);
        expect(cutTexts(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('2. instructions name no device', () {
    for (final lang in AppLang.values) {
      test(lang.name, () {
        final s = S(lang);
        for (final t in [
          s.howToTitle,
          s.howToTileHint,
          for (final step in s.howToSteps) ...[step.$1, step.$2],
          s.measurementsNote,
          s.trendLegend,
          s.trendLegendBp,
          s.guideIntro,
          s.yourNotes,
        ]) {
          expect(_deviceBound.hasMatch(t), isFalse, reason: t);
        }
        // The how-to still names the real buttons.
        final all = s.howToSteps.map((e) => e.$2).join(' ');
        for (final label in [
          s.numberPadShow,
          s.saveMeasurement,
          s.moreDetails,
          s.presetHourAgo,
          s.createBackup,
          s.amendAction(AmendReason.correction),
        ]) {
          expect(all, contains(label), reason: label);
        }
      });
    }
  });

  group('3. the how-to has no decorative numbers', () {
    for (final (locale, lang) in [(_en, AppLang.en), (_tr, AppLang.tr)]) {
      testWidgets('${lang.name}, 320 dp, 2× text', (tester) async {
        tester.view.physicalSize = small;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          host(const HowToScreen(), locale: locale, text: 2),
        );
        await tester.pumpAndSettle();
        final s = S(lang);
        for (var i = 1; i <= s.howToSteps.length; i++) {
          final step = find.byKey(ValueKey('howto-step-$i'));
          await _scrollTo(tester, 'screen-howto', 'howto-step-$i');
          final texts = tester
              .widgetList<Text>(
                find.descendant(of: step, matching: find.byType(Text)),
              )
              .map((t) => t.data)
              .toList();
          expect(texts, [s.howToSteps[i - 1].$1, s.howToSteps[i - 1].$2]);
        }
        final cut = await sweep(tester, mainScroll('screen-howto'));
        expect(cut, isEmpty, reason: '$cut');
      });
    }
  });

  test('4. Turkish follows the L001 words in Learn and the passphrase '
      'hint', () {
    final learn = destinationById(DestinationId.learn);
    for (final t in [
      learn.purpose(AppLang.tr),
      learn.canDo(AppLang.tr),
      learn.principle(AppLang.tr),
      S(AppLang.tr).passphraseHint(12),
    ]) {
      expect(t, isNot(contains('kelime')), reason: t);
      // The product name takes no suffix.
      expect(t, isNot(contains("Human OS'")), reason: t);
    }
    for (final d in destinations) {
      for (final t in [
        d.purpose(AppLang.tr),
        d.canDo(AppLang.tr),
        d.principle(AppLang.tr),
      ]) {
        expect(
          RegExp(r"Human OS['’]\p{L}", unicode: true).hasMatch(t),
          isFalse,
        );
      }
    }
  });

  group('5. the Timeline says what deleted and withdrawn mean', () {
    for (final (locale, lang) in [
      (const Locale('en'), AppLang.en),
      (const Locale('tr'), AppLang.tr),
    ]) {
      testWidgets('${lang.name}, 320 dp, 2× text', (tester) async {
        final (s, _) = await boot(tester);
        tester.view.physicalSize = const Size(320, 700);
        await tester.pumpWidget(
          host(TimelineScreen(services: s), locale: locale, text: 2),
        );
        await settle(tester);
        final help = find.byKey(const ValueKey('timeline-show-hidden-help'));
        await reveal(tester, help);
        final words = S(lang);
        expect(tester.widget<Text>(help).data, words.showHiddenHelp);
        // It ends by saying what the switch does.
        expect(
          words.showHiddenHelp,
          endsWith(
            lang == AppLang.en
                ? 'switch this on to see them.'
                : 'görmek için bunu aç.',
          ),
        );
        // It belongs to the switch: read out with it.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('timeline-show-hidden')),
            matching: help,
          ),
          findsOneWidget,
        );
        expect(interpretive.hasMatch(words.showHiddenHelp), isFalse);
        expect(cutTexts(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('6. one centred reading column on a wide window', () {
    testWidgets('first run: the text and Start stay in the column', (
      tester,
    ) async {
      await launchReal(tester, MemoryAppearanceStore());
      final (left, width) = _column(1280, 24);
      for (final key in ['first-step', 'first-next']) {
        final r = tester.getRect(find.byKey(ValueKey(key)));
        expect(r.left, closeTo(left, 0.5), reason: key);
        expect(r.right, lessThanOrEqualTo(left + width + 0.5), reason: key);
      }
      // The button is as wide as the column, not the window.
      expect(
        tester.getSize(find.byKey(const ValueKey('first-next'))).width,
        closeTo(width, 0.5),
      );
      await tapKey(tester, 'first-next');
      final r = tester.getRect(find.byKey(const ValueKey('first-then')));
      expect(r.left, closeTo(left, 0.5));
      expect(r.right, lessThanOrEqualTo(left + width + 0.5));
    });

    for (final (locale, lang) in [(_en, AppLang.en), (_tr, AppLang.tr)]) {
      testWidgets('first run, ${lang.name}, 320 dp, 2× text: both steps fit '
          'and cut nothing', (tester) async {
        await launchReal(tester, MemoryAppearanceStore());
        tester.view.physicalSize = small;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.localesTestValue = [locale];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await tester.pumpAndSettle();
        var cut = await sweep(tester, mainScroll('screen-first-run'));
        expect(cut, isEmpty, reason: '$cut');
        final (left, _) = _column(320, 24);
        expect(
          tester.getRect(find.byKey(const ValueKey('first-next'))).left,
          closeTo(left, 0.5),
        );
        await tapKey(tester, 'first-next');
        tester
            .state<ScrollableState>(mainScroll('screen-first-run'))
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        cut = await sweep(tester, mainScroll('screen-first-run'));
        expect(cut, isEmpty, reason: '$cut');
      });
    }

    testWidgets('summary and "Worked out from your records"', (tester) async {
      await launch(tester, size: const Size(1440, 900));
      final (left, width) = _column(1440, Space.l);
      await _openTool(tester, 'tool-summary');
      var r = tester.getRect(find.byKey(const ValueKey('summary-empty')));
      expect(r.left, closeTo(left, 0.5));
      expect(r.right, lessThanOrEqualTo(left + width + 0.5));
      // The scroll view keeps the whole width: the wheel works in the margin.
      expect(
        tester.getRect(mainScroll('screen-summary')).width,
        closeTo(1440, 0.5),
      );
      await tester.pageBack();
      await settle(tester);
      await _openTool(tester, 'tool-derived');
      r = tester.getRect(find.text(S(AppLang.en).derivedIntro));
      expect(r.left, closeTo(left, 0.5));
      expect(r.right, lessThanOrEqualTo(left + width + 0.5));
    });
  });
}
