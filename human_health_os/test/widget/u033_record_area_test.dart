// U033: one scaffold and one empty state for the record areas. Every area
// on RecordAreaScreen says it is reading first; with nothing yet its only
// empty state is the first step (Aion, one sentence and the one Add action
// inside it); Add opens the sheet; a saved entry shows with its action and
// Add moves above the list; a failed read is said in words with Try again;
// a 320 dp window at twice the text size fits, EN and TR.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/features/activity/activity_screen.dart';
import 'package:human_health_os/src/features/conditions/conditions_screen.dart';
import 'package:human_health_os/src/features/documents/documents_screen.dart';
import 'package:human_health_os/src/features/medications/medications_screen.dart';
import 'package:human_health_os/src/features/nutrition/nutrition_screen.dart';
import 'package:human_health_os/src/features/preventive/preventive_screen.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/presentation/widgets/aion.dart';
import 'package:human_health_os/src/presentation/widgets/first_step.dart';

import 'f007_measurements_test.dart' show tapKey;
import 'u030_read_failed_test.dart' show boot, settle;

/// One record area on the scaffold: its key prefix, its screen, its empty
/// sentence, the field and save key of its add sheet, and the prefix of the
/// action each saved entry carries.
typedef Area = ({
  String id,
  Widget Function(AppServices) build,
  String Function(S) none,
  String field,
  String save,
  String rowAction,
});

final areas = <Area>[
  (
    id: 'doc',
    build: (s) => DocumentsScreen(services: s),
    none: (s) => s.docNone,
    field: 'doc-title',
    save: 'doc-save',
    rowAction: 'doc-correct-',
  ),
  (
    id: 'cond',
    build: (s) => ConditionsScreen(services: s),
    none: (s) => s.condNone,
    field: 'cond-name',
    save: 'cond-save',
    rowAction: 'cond-correct-',
  ),
  (
    id: 'prev',
    build: (s) => PreventiveScreen(services: s),
    none: (s) => s.prevNone,
    field: 'prev-name',
    save: 'prev-save',
    rowAction: 'prev-correct-',
  ),
  (
    id: 'food',
    build: (s) => NutritionScreen(services: s),
    none: (s) => s.foodNone,
    field: 'food-what',
    save: 'food-save',
    rowAction: 'food-correct-',
  ),
  (
    id: 'act',
    build: (s) => ActivityScreen(services: s),
    none: (s) => s.actNone,
    field: 'act-what',
    save: 'act-save',
    rowAction: 'act-correct-',
  ),
  (
    id: 'meds',
    build: (s) => MedicationsScreen(services: s),
    none: (s) => s.medsNone,
    field: 'meds-name',
    save: 'meds-item-save',
    rowAction: 'meds-plan-add-',
  ),
];

Widget host(Widget child, {Locale locale = const Locale('en'), double? text}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: text == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(text)),
              child: child!,
            ),
      home: Scaffold(body: child),
    );

Finder keyStarting(String prefix) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(prefix),
);

/// Scrolls the area until [f] is built and in view (its slivers are lazy).
Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Opens the add sheet, types one entry and saves it.
Future<void> addOne(WidgetTester tester, Area a, String what) async {
  await reveal(tester, find.byKey(ValueKey('${a.id}-add')));
  await tapKey(tester, '${a.id}-add');
  await tester.enterText(find.byKey(ValueKey(a.field)), what);
  await tester.pump();
  await tapKey(tester, a.save);
  await settle(tester);
}

void main() {
  for (final a in areas) {
    group(a.id, () {
      testWidgets('reading first, then the first step as the only empty '
          'state; Add opens the sheet; a saved entry shows with its action '
          'and Add moves above the list', (tester) async {
        final (s, _) = await boot(tester);
        await tester.pumpWidget(host(a.build(s)));
        expect(find.byKey(const ValueKey('loading-line')), findsOneWidget);
        expect(find.byKey(ValueKey('${a.id}-none')), findsNothing);
        await settle(tester);

        final empty = find.byKey(ValueKey('${a.id}-empty'));
        expect(empty, findsOneWidget);
        expect(find.byKey(const ValueKey('loading-line')), findsNothing);
        expect(
          find.descendant(of: empty, matching: find.byType(AionFigure)),
          findsOneWidget,
        );
        expect(find.byType(AionFigure), findsOneWidget, reason: 'one Aion');
        expect(
          tester.widget<Text>(find.byKey(ValueKey('${a.id}-none'))).data,
          a.none(S(AppLang.en)),
        );
        expect(
          find.descendant(
            of: empty,
            matching: find.byKey(ValueKey('${a.id}-none')),
          ),
          findsOneWidget,
        );
        // Exactly one Add action on the screen, and it is in the first step.
        expect(find.byKey(ValueKey('${a.id}-add')), findsOneWidget);
        expect(
          find.descendant(
            of: empty,
            matching: find.byKey(ValueKey('${a.id}-add')),
          ),
          findsOneWidget,
        );
        expect(find.byType(FilledButton), findsOneWidget);

        await tapKey(tester, '${a.id}-add');
        expect(find.byKey(ValueKey(a.save)), findsOneWidget, reason: 'sheet');
        await tester.enterText(find.byKey(ValueKey(a.field)), 'First entry');
        await tester.pump();
        await tapKey(tester, a.save);
        await settle(tester);

        expect(find.byKey(ValueKey(a.save)), findsNothing, reason: 'closed');
        expect(find.textContaining('First entry'), findsOneWidget);
        expect(keyStarting(a.rowAction), findsOneWidget);
        expect(empty, findsNothing);
        expect(find.byType(FirstStep), findsNothing);
        expect(find.byType(AionFigure), findsNothing);
        // Add stays the one action, now above the list.
        expect(find.byKey(ValueKey('${a.id}-add')), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(ValueKey('${a.id}-add'))).dy,
          lessThan(tester.getTopLeft(find.textContaining('First entry')).dy),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('no Add action above the list during the first read, so '
          'it never jumps into the first step (R023)', (tester) async {
        final (s, _) = await boot(tester);
        await tester.pumpWidget(host(a.build(s)));
        expect(find.byKey(const ValueKey('loading-line')), findsOneWidget);
        expect(find.byKey(ValueKey('${a.id}-add')), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        await settle(tester);
        expect(
          find.descendant(
            of: find.byKey(ValueKey('${a.id}-empty')),
            matching: find.byKey(ValueKey('${a.id}-add')),
          ),
          findsOneWidget,
        );
      });

      testWidgets('Add focused by keyboard in the empty state keeps focus '
          'after the first save moves it above the list (R023)', (
        tester,
      ) async {
        final (s, _) = await boot(tester);
        await tester.pumpWidget(host(a.build(s)));
        await settle(tester);
        final add = find.byKey(ValueKey('${a.id}-add'));
        bool addFocused() {
          final ctx = FocusManager.instance.primaryFocus?.context;
          if (ctx == null) return false;
          return find
              .descendant(
                of: add,
                matching: find.byElementPredicate((e) => e == ctx),
              )
              .evaluate()
              .isNotEmpty;
        }

        for (var i = 0; i < 30 && !addFocused(); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(addFocused(), isTrue, reason: 'Tab reaches Add');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(a.save)), findsOneWidget, reason: 'sheet');
        await tester.enterText(find.byKey(ValueKey(a.field)), 'Kept focus');
        await tester.pump();
        await tapKey(tester, a.save);
        await settle(tester);

        expect(find.byKey(ValueKey(a.save)), findsNothing, reason: 'closed');
        expect(find.byKey(ValueKey('${a.id}-empty')), findsNothing);
        expect(add, findsOneWidget);
        expect(addFocused(), isTrue, reason: 'Add keeps keyboard focus');
      });

      testWidgets('a failed read is said in words with Try again; nothing '
          'else is shown as empty', (tester) async {
        final (s, repo) = await boot(tester);
        repo.failReads = true;
        await tester.pumpWidget(host(a.build(s)));
        await settle(tester);
        expect(find.byKey(ValueKey('${a.id}-read-failed')), findsOneWidget);
        expect(find.byKey(ValueKey('${a.id}-empty')), findsNothing);
        expect(find.byKey(const ValueKey('loading-line')), findsNothing);
        repo.failReads = false;
        await tester.tap(find.byKey(ValueKey('${a.id}-try-again')));
        await settle(tester);
        expect(find.byKey(ValueKey('${a.id}-read-failed')), findsNothing);
        expect(find.byKey(ValueKey('${a.id}-empty')), findsOneWidget);
      });

      for (final lang in const [Locale('en'), Locale('tr')]) {
        testWidgets('320 dp at twice the text size fits '
            '(${lang.languageCode})', (tester) async {
          final (s, _) = await boot(tester);
          tester.view.physicalSize = const Size(320, 700);
          await tester.pumpWidget(host(a.build(s), locale: lang, text: 2));
          await settle(tester);
          expect(tester.takeException(), isNull);
          await reveal(tester, find.byKey(ValueKey('${a.id}-empty')));
          expect(find.byKey(ValueKey('${a.id}-empty')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await addOne(tester, a, 'Second');
          expect(tester.takeException(), isNull);
          await reveal(tester, keyStarting(a.rowAction));
          expect(keyStarting(a.rowAction), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
