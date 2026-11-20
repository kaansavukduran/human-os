// R016: defects the Q001 screen matrix and the U031-S4 slop audit noticed.
// 1. A bottom-bar label never breaks inside a word (320 dp, 2× text, EN/TR).
// 2. The back button's screen-reader name is said once ("Back" / "Geri").
// 3. Empty Labs has one add action; with results the main one stays.
// 4. The Labs "as printed" sentence is said once (by the area intro).
// 5. Today's tools are plain rows: no decorative leading icons.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/navigation/app_shell.dart';
import 'package:human_health_os/src/navigation/destinations.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import 'f004_labs_test.dart' as labs;
import 'f007_measurements_test.dart' show launch, settle, tapKey;
import 'u034_learn_test.dart' show openLearn;

const en = Locale('en', 'US');
const tr = Locale('tr', 'TR');

/// Indices where a new visual line starts in [p]'s text.
List<int> lineStarts(RenderParagraph p) {
  final text = p.text.toPlainText();
  final starts = <int>[];
  double? lastY;
  for (var i = 0; i < text.length; i++) {
    final y = p.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dy;
    if (lastY != null && y > lastY + 0.5) starts.add(i);
    lastY = y;
  }
  return starts;
}

Iterable<RenderParagraph> barParagraphs(WidgetTester tester) => find
    .descendant(
      of: find.byKey(const ValueKey('nav-bar')),
      matching: find.byType(RichText),
    )
    .evaluate()
    .map((e) => e.renderObject! as RenderParagraph);

void main() {
  group('bottom-bar labels never break inside a word', () {
    for (final (locale, lang) in [(en, AppLang.en), (tr, AppLang.tr)]) {
      for (final (width, scale) in [(320.0, 2.0), (320.0, 1.0), (390.0, 2.0)]) {
        testWidgets('${locale.languageCode} at ${width.toInt()} dp, '
            '$scale× text', (tester) async {
          await launch(
            tester,
            locale: locale,
            size: Size(width, 700),
            textScale: scale,
          );
          final expected = [
            for (final id in kPrimaryDestinations)
              destinationById(id).label(lang),
            lang == AppLang.tr ? 'Diğer' : 'More',
          ];
          final paragraphs = barParagraphs(tester).toList();
          final shown = [for (final p in paragraphs) p.text.toPlainText()];
          // Every label is there, whole (no ellipsis, nothing hidden).
          expect(shown, containsAll(expected));
          for (final p in paragraphs) {
            final text = p.text.toPlainText();
            expect(p.didExceedMaxLines, isFalse, reason: text);
            for (final i in lineStarts(p)) {
              expect(
                text[i - 1],
                matches(RegExp(r'\s')),
                reason:
                    '"$text" breaks inside a word before '
                    '"${text.substring(i)}"',
              );
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('labels are scaled down only when a word does not fit, and '
        'only as far as needed', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );
      const words = ['Today', 'Medications', 'Zaman çizelgesi'];
      expect(navLabelScaler(ctx, labels: words, share: 1000), isNull);
      final scaler = navLabelScaler(ctx, labels: words, share: 60)!;
      final style = Theme.of(ctx).textTheme.bodyMedium!.merge(
        Theme.of(ctx).navigationBarTheme.labelTextStyle
                ?.resolve({WidgetState.selected}) ??
            Theme.of(ctx).textTheme.labelMedium,
      );
      final painter = TextPainter(
        text: TextSpan(text: 'Medications', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      expect(painter.width, lessThanOrEqualTo(58));
      expect(painter.width, greaterThan(58 * 0.9));
      painter.dispose();
    });
  });

  group('the back button is named once', () {
    for (final (locale, name) in [(en, 'Back'), (tr, 'Geri')]) {
      testWidgets(name, (tester) async {
        final handle = tester.ensureSemantics();
        await launch(tester, locale: locale, size: const Size(390, 844));
        await tapKey(tester, 'open-settings');
        final back = find.byType(BackButton);
        expect(back, findsOneWidget);
        final node = tester.getSemantics(back);
        final data = node.getSemanticsData();
        // Everything a screen reader reads as the name: label and tooltip.
        final words = [
          data.label,
          data.tooltip,
        ].where((w) => w.trim().isNotEmpty).join(' ');
        expect(words, name);
        expect(
          RegExp(RegExp.escape(name)).allMatches(words).length,
          1,
          reason: words,
        );
        handle.dispose();
      });
    }
  });

  group('Labs', () {
    testWidgets('empty: one "Add a result"; with a result: the main add '
        'button stays', (tester) async {
      final s = await labs.start(tester);
      await labs.go(tester, s, 'Labs');
      expect(find.byKey(const ValueKey('labs-empty')), findsOneWidget);
      expect(find.text('Add a result'), findsOneWidget);
      expect(find.byKey(const ValueKey('lab-add')), findsOneWidget);
      expect(find.byKey(const ValueKey('labs-empty-add')), findsNothing);

      await labs.tapKey(tester, 'lab-add');
      await labs.fill(tester, 'lab-analyte', 'HbA1c');
      await labs.fill(tester, 'lab-value', '5,4');
      await labs.fill(tester, 'lab-unit', '%');
      await labs.fill(tester, 'lab-date', '2026-10-03');
      await labs.tapKey(tester, 'lab-save');

      expect(find.byKey(const ValueKey('labs-empty')), findsNothing);
      expect(find.text('Add a result'), findsOneWidget);
      expect(find.byKey(const ValueKey('lab-add')), findsOneWidget);
    });

    for (final (locale, printed) in [
      (en, 'as the report printed them'),
      (tr, 'raporda yazdığı gibi'),
    ]) {
      testWidgets('the "as printed" sentence appears once '
          '(${locale.languageCode})', (tester) async {
        final s = await labs.start(tester, locale: locale);
        await labs.go(tester, s, locale == tr ? 'Tahliller' : 'Labs');
        final texts = find
            .descendant(
              of: find.byKey(const ValueKey('screen-labs')),
              matching: find.byType(Text),
            )
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .toList();
        final all = texts.join('\n');
        expect(
          RegExp(RegExp.escape(printed)).allMatches(all).length,
          1,
          reason: all,
        );
        // "printed them" / "yazdığı gibi" is not repeated by the note.
        final note = tester
            .widget<Text>(find.byKey(const ValueKey('labs-no-interpretation')))
            .data!;
        expect(note, isNot(contains(locale == tr ? 'yazdığı' : 'printed')));
        expect(note, contains(locale == tr ? 'yorumlamaz' : 'not interpret'));
      });
    }
  });

  testWidgets('Today\'s tools and Learn\'s entries are plain rows: title '
      'and hint, no leading icon, keys kept', (tester) async {
    final s = await launch(tester, size: const Size(1280, 4000));
    await tester.pumpWidget(HumanOsApp(services: s));
    await settle(tester);
    void plainRows(List<(String, IconData)> rows) {
      for (final (key, icon) in rows) {
        final tile = find.byKey(ValueKey(key));
        expect(tile, findsOneWidget, reason: key);
        expect(
          find.descendant(of: tile, matching: find.byIcon(icon)),
          findsNothing,
          reason: key,
        );
        // Only the chevron, which says "opens a page".
        expect(
          find.descendant(of: tile, matching: find.byType(Icon)),
          findsOneWidget,
          reason: key,
        );
        expect(
          find.descendant(of: tile, matching: find.byIcon(Icons.chevron_right)),
          findsOneWidget,
          reason: key,
        );
        expect(
          find.descendant(of: tile, matching: find.byType(Text)),
          findsNWidgets(2),
          reason: key,
        );
      }
    }

    plainRows([
      ('tool-summary', Icons.assignment_outlined),
      ('tool-derived', Icons.calculate_outlined),
      ('tool-phyto', Icons.eco_outlined),
      ('tool-genetics', Icons.biotech_outlined),
    ]);
    // U034: the glossary, the body guide and the how-to moved to Learn.
    await openLearn(tester);
    plainRows([
      ('tool-howto', Icons.help_outline),
      ('tool-glossary', Icons.menu_book_outlined),
      ('tool-guide', Icons.accessibility_new_outlined),
    ]);
    await tapKey(tester, 'tool-glossary');
    expect(find.byType(BackButton), findsOneWidget);
  });
}
