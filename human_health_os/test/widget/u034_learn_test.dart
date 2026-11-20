// U034 (A002 audit): Learn is a real area that hosts the glossary, the body
// guide and the how-to; Compare is not listed until it compares something;
// no navigation entry leads to a "Nothing yet" page; Today is calmer.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f007_measurements_test.dart' show launch, settle, tapKey;

/// Opens Learn the way a person does: the "More areas" item on the rail, or
/// the "More" sheet on the compact bar.
Future<void> openLearn(WidgetTester tester) async {
  final onRail = find.byKey(const ValueKey('rail-planned-learn'));
  if (onRail.evaluate().isNotEmpty) {
    await tester.ensureVisible(onRail);
    await tester.pumpAndSettle();
    await tester.tap(onRail);
  } else {
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('nav-bar')),
        matching: find.byIcon(Icons.more_horiz),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.descendant(
      of: find.byKey(const ValueKey('more-sheet')),
      matching: find.byIcon(Icons.school_outlined),
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
  }
  await settle(tester);
  expect(find.byKey(const ValueKey('screen-learn')), findsOneWidget);
}

/// Scrolls Learn (a lazy list) until the row [key] is built and on screen:
/// from the top, so a row scrolled past is found again.
Future<void> revealOnLearn(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isEmpty) {
    final list = find
        .descendant(
          of: find.byKey(const ValueKey('screen-learn')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(f, 300, scrollable: list);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

const _entries = [
  ('tool-glossary', 'screen-glossary'),
  ('tool-guide', 'screen-guide'),
  ('tool-howto', 'screen-howto'),
];

void main() {
  test('Compare is not listed; Learn is, with nothing "planned" about it', () {
    expect(DestinationId.values.map((d) => d.name), isNot(contains('compare')));
    final learn = destinationById(DestinationId.learn);
    expect(plannedDestinations, contains(learn));
    expect(learn.plannedForge, isNull);
    for (final d in destinations) {
      for (final lang in AppLang.values) {
        expect(d.canDo(lang), isNot(contains('Nothing yet')), reason: d.en);
        expect(d.canDo(lang), isNot(contains('Henüz bir şey yok')));
        expect(d.label(lang), isNot(anyOf('Compare', 'Karşılaştır')));
      }
    }
  });

  for (final (locale, size, textScale) in const [
    (Locale('en'), Size(1280, 3200), 1.0),
    (Locale('tr'), Size(1280, 3200), 1.0),
    (Locale('en'), Size(390, 1400), 1.0),
    (Locale('tr'), Size(320, 1400), 2.0),
  ]) {
    final tag =
        '${locale.languageCode} ${size.width.toInt()} dp, text ×$textScale';
    testWidgets('$tag: Learn shows its introduction and three entries, '
        'each opening its page', (tester) async {
      await launch(tester, locale: locale, size: size, textScale: textScale);
      final s = S(locale.languageCode == 'tr' ? AppLang.tr : AppLang.en);
      final d = destinationById(DestinationId.learn);
      await openLearn(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(d.label(s.lang)), findsWidgets);
      expect(find.text(d.purpose(s.lang)), findsOneWidget);
      expect(find.text(d.canDo(s.lang)), findsOneWidget);
      expect(find.text(d.principle(s.lang)), findsOneWidget);
      for (final (key, t) in [
        ('tool-glossary', s.glossaryTitle),
        ('tool-guide', s.guideTitle),
        ('tool-howto', s.howToTitle),
      ]) {
        await revealOnLearn(tester, key);
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.textContaining('Nothing yet'), findsNothing);
      expect(find.textContaining('Henüz bir şey yok'), findsNothing);
      for (final (entry, screen) in _entries) {
        await revealOnLearn(tester, entry);
        await tapKey(tester, entry);
        expect(find.byKey(ValueKey(screen)), findsOneWidget, reason: entry);
        expect(tester.takeException(), isNull, reason: entry);
        await tester.tap(find.byType(BackButton).first);
        await settle(tester);
        expect(find.byKey(const ValueKey('screen-learn')), findsOneWidget);
      }
    });
  }

  testWidgets('keyboard: Tab reaches each Learn entry and Enter opens it', (
    tester,
  ) async {
    await launch(tester);
    await openLearn(tester);
    for (final (entry, screen) in _entries) {
      final row = find.descendant(
        of: find.byKey(ValueKey(entry)),
        matching: find.byType(InkWell),
      );
      var reached = false;
      for (var i = 0; i < 60 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        reached = _focusedInkWell(tester) == tester.widget<InkWell>(row);
      }
      expect(reached, isTrue, reason: '$entry reached by Tab');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byKey(ValueKey(screen)), findsOneWidget, reason: entry);
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }
  });

  testWidgets('navigation never reaches a "Nothing yet" page', (tester) async {
    await launch(tester, size: const Size(1280, 3200));
    for (final d in destinations) {
      final item = find.descendant(
        of: find.byKey(const ValueKey('nav-rail')),
        matching: find.text(d.en),
      );
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await settle(tester);
      expect(find.byKey(ValueKey('screen-${d.id.name}')), findsOneWidget);
      expect(find.textContaining('Nothing yet'), findsNothing, reason: d.en);
      expect(
        find.text('Planned for a later version'),
        findsNothing,
        reason: d.en,
      );
    }
    expect(find.text('Compare'), findsNothing);
  });

  testWidgets('the More sheet lists Learn and not Compare', (tester) async {
    await launch(tester, size: const Size(390, 1400));
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('more-sheet'));
    expect(
      find.descendant(of: sheet, matching: find.text('Learn')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Compare')),
      findsNothing,
    );
  });

  testWidgets('Today is calmer: no glossary, guide or how-to rows; the '
      'discovery card still opens the glossary and the how-to', (tester) async {
    await launch(tester);
    for (final (entry, _) in _entries) {
      expect(find.byKey(ValueKey(entry)), findsNothing, reason: entry);
    }
    expect(find.text('Words and the body'), findsNothing);
    for (final (step, screen) in const [
      ('discovery-glossary', 'screen-glossary'),
      ('discovery-howTo', 'screen-howto'),
    ]) {
      await tapKey(tester, step);
      expect(find.byKey(ValueKey(screen)), findsOneWidget, reason: step);
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }
  });
}

/// The InkWell whose focus node holds primary focus, if any.
InkWell? _focusedInkWell(WidgetTester tester) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return null;
  return focused.findAncestorWidgetOfExactType<InkWell>();
}
